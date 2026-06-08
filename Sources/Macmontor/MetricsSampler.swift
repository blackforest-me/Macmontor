import Foundation
import Darwin

struct SystemSnapshot {
    let timestamp: Date
    let cpuPercent: Double
    let memoryUsedGB: Double
    let memoryTotalGB: Double
    let memoryCacheGB: Double
    let memoryPressure: String
    let downloadBytesPerSecond: UInt64
    let uploadBytesPerSecond: UInt64
    let diskFreeGB: Double
    let topProcesses: [ProcessInfoItem]
}

struct ProcessInfoItem {
    let name: String
    let cpu: Double
}

final class MetricsSampler {
    private let pageSize: Double
    private let memoryTotal = Double(ProcessInfo.processInfo.physicalMemory)
    private var previousCPU: host_cpu_load_info_data_t?
    private var previousNetwork: NetworkCounters?
    private var previousNetworkTime: Date?

    init() {
        var size: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &size)
        pageSize = result == KERN_SUCCESS ? Double(size) : 16_384
    }

    func sample() -> SystemSnapshot {
        let now = Date()
        let cpu = sampleCPU()
        let memory = sampleMemory()
        let network = sampleNetwork(now: now)
        let diskFree = sampleDiskFree()
        let processes = sampleTopProcesses()

        return SystemSnapshot(
            timestamp: now,
            cpuPercent: cpu,
            memoryUsedGB: memory.usedGB,
            memoryTotalGB: memoryTotal / 1_073_741_824,
            memoryCacheGB: memory.cacheGB,
            memoryPressure: memory.pressure,
            downloadBytesPerSecond: network.down,
            uploadBytesPerSecond: network.up,
            diskFreeGB: diskFree,
            topProcesses: processes
        )
    }

    private func sampleCPU() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        defer { previousCPU = info }
        guard let previous = previousCPU else { return 0 }

        let user = Double(info.cpu_ticks.0 - previous.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 - previous.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 - previous.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 - previous.cpu_ticks.3)
        let total = user + system + idle + nice

        guard total > 0 else { return 0 }
        return max(0, min(100, ((total - idle) / total) * 100))
    }

    private func sampleMemory() -> (usedGB: Double, cacheGB: Double, pressure: String) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, "Unknown")
        }

        let appMemory = Double(stats.internal_page_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let used = appMemory + wired + compressed
        let cache = Double(stats.external_page_count + stats.speculative_count) * pageSize
        let ratio = used / memoryTotal

        let pressure: String
        if ratio >= 0.86 {
            pressure = "High"
        } else if ratio >= 0.70 {
            pressure = "Med"
        } else {
            pressure = "Low"
        }

        return (used / 1_073_741_824, cache / 1_073_741_824, pressure)
    }

    private func sampleDiskFree() -> Double {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]
        let values = try? url.resourceValues(forKeys: keys)
        let bytes = Double(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return bytes / 1_073_741_824
    }

    private func sampleTopProcesses() -> [ProcessInfoItem] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-arcwwwxo", "comm,%cpu"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> ProcessInfoItem? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let split = trimmed.lastIndex(of: " ") else { return nil }

                let name = trimmed[..<split].trimmingCharacters(in: .whitespaces)
                let cpuText = trimmed[split...].trimmingCharacters(in: .whitespaces)
                guard let cpu = Double(cpuText), cpu > 0 else { return nil }

                return ProcessInfoItem(name: shortProcessName(String(name)), cpu: cpu)
            }
            .prefix(3)
            .map { $0 }
    }

    private func shortProcessName(_ name: String) -> String {
        let lastPathComponent = URL(fileURLWithPath: name).lastPathComponent
        if lastPathComponent.count <= 18 {
            return lastPathComponent
        }
        return String(lastPathComponent.prefix(17)) + "…"
    }

    private func sampleNetwork(now: Date) -> (down: UInt64, up: UInt64) {
        let current = readNetworkCounters()
        defer {
            previousNetwork = current
            previousNetworkTime = now
        }

        guard
            let previous = previousNetwork,
            let previousTime = previousNetworkTime
        else {
            return (0, 0)
        }

        let interval = max(0.25, now.timeIntervalSince(previousTime))
        let down = current.received >= previous.received ? current.received - previous.received : 0
        let up = current.sent >= previous.sent ? current.sent - previous.sent : 0

        return (UInt64(Double(down) / interval), UInt64(Double(up) / interval))
    }

    private func readNetworkCounters() -> NetworkCounters {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return NetworkCounters(received: 0, sent: 0)
        }
        defer { freeifaddrs(addressPointer) }

        var received: UInt64 = 0
        var sent: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = cursor {
            let interface = current.pointee
            cursor = interface.ifa_next

            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("lo") else { continue }
            guard let data = interface.ifa_data else { continue }

            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(networkData.ifi_ibytes)
            sent += UInt64(networkData.ifi_obytes)
        }

        return NetworkCounters(received: received, sent: sent)
    }
}

private struct NetworkCounters {
    let received: UInt64
    let sent: UInt64
}
