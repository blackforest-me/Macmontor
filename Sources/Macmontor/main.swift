import AppKit
import Foundation
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: WidgetWindow!
    private var viewController: WidgetViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyApplicationIcon()

        viewController = WidgetViewController()
        window = WidgetWindow(contentViewController: viewController)
        window.delegate = viewController
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    private func applyApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "Macmontor", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }
}

final class WidgetWindow: NSWindow {
    private static let frameKey = "widgetFrame"

    init(contentViewController: NSViewController) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 380, height: 350)
        let origin = NSPoint(
            x: screenFrame.midX + 80,
            y: screenFrame.midY - size.height / 2
        )
        let defaultFrame = NSRect(origin: origin, size: size)
        let savedFrame = UserDefaults.standard.string(forKey: Self.frameKey).flatMap(NSRectFromString)
        let initialFrame = savedFrame.map { NSIntersectionRect(screenFrame, $0).isEmpty ? defaultFrame : $0 } ?? defaultFrame

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.frameKey)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

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

enum WidgetMode: String {
    case compact
    case detail
}

final class WidgetViewController: NSViewController, NSWindowDelegate {
    private let sampler = MetricsSampler()
    private var timer: Timer?
    private var mode: WidgetMode = UserDefaults.standard.string(forKey: "widgetMode").flatMap(WidgetMode.init(rawValue:)) ?? .detail
    private var cpuHistory: [Double] = []

    private let rootStack = NSStackView()
    private let detailStack = NSStackView()
    private let cpuTile = MetricTileView(title: "CPU")
    private let memoryTile = MetricTileView(title: "Memory")
    private let networkTile = MetricTileView(title: "Network")
    private let cpuChart = SparklineView()
    private let cacheValue = NSTextField(labelWithString: "--")
    private let diskValue = NSTextField(labelWithString: "--")
    private let updatedValue = NSTextField(labelWithString: "--")
    private let modeButton = NSButton()
    private let quitButton = NSButton()
    private var topRows: [ProcessRowView] = []

    override func loadView() {
        view = WidgetView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    private func buildUI() {
        let title = NSTextField(labelWithString: "Macmontor")
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = Palette.primaryText

        let titleGroup = NSStackView(views: [StatusDotView(), title])
        titleGroup.orientation = .horizontal
        titleGroup.alignment = .centerY
        titleGroup.spacing = 8

        updatedValue.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        updatedValue.textColor = Palette.secondaryText
        updatedValue.alignment = .right

        configureIconButton(modeButton, symbol: "rectangle.compress.vertical", tooltip: "Toggle layout")
        modeButton.target = self
        modeButton.action = #selector(toggleMode)

        configureIconButton(quitButton, symbol: "xmark", tooltip: "Quit")
        quitButton.target = self
        quitButton.action = #selector(quit)

        let controls = NSStackView(views: [updatedValue, modeButton, quitButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6

        let header = NSStackView(views: [titleGroup, controls])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        titleGroup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        controls.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let tiles = NSStackView(views: [cpuTile, memoryTile, networkTile])
        tiles.orientation = .horizontal
        tiles.alignment = .top
        tiles.distribution = .fillEqually
        tiles.spacing = 8

        cpuChart.translatesAutoresizingMaskIntoConstraints = false
        cpuChart.heightAnchor.constraint(equalToConstant: 48).isActive = true

        detailStack.orientation = .vertical
        detailStack.spacing = 10

        let detailRows = NSStackView(views: [
            makeMetricRow(label: "Cache", value: cacheValue),
            makeMetricRow(label: "Disk", value: diskValue)
        ])
        detailRows.orientation = .vertical
        detailRows.spacing = 7

        let topHeader = NSTextField(labelWithString: "TOP CPU")
        topHeader.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        topHeader.textColor = Palette.mutedText

        let topStack = NSStackView()
        topStack.orientation = .vertical
        topStack.spacing = 5
        for _ in 0..<3 {
            let row = ProcessRowView()
            topRows.append(row)
            topStack.addArrangedSubview(row)
        }

        detailStack.addArrangedSubview(detailRows)
        detailStack.addArrangedSubview(topHeader)
        detailStack.addArrangedSubview(topStack)

        rootStack.orientation = .vertical
        rootStack.spacing = 12
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(header)
        rootStack.addArrangedSubview(tiles)
        rootStack.addArrangedSubview(cpuChart)
        rootStack.addArrangedSubview(detailStack)
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 17),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -17)
        ])

        applyMode(animated: false)
    }

    private func configureIconButton(_ button: NSButton, symbol: String, tooltip: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = Palette.secondaryText
        button.toolTip = tooltip
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    private func makeMetricRow(label: String, value: NSTextField) -> NSView {
        let labelView = NSTextField(labelWithString: label.uppercased())
        labelView.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        labelView.textColor = Palette.mutedText
        labelView.widthAnchor.constraint(equalToConstant: 58).isActive = true

        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        value.textColor = Palette.primaryText
        value.alignment = .right
        value.lineBreakMode = .byTruncatingMiddle

        let row = NSStackView(views: [labelView, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    @objc private func toggleMode() {
        mode = mode == .detail ? .compact : .detail
        UserDefaults.standard.set(mode.rawValue, forKey: "widgetMode")
        applyMode(animated: true)
    }

    private func applyMode(animated: Bool) {
        detailStack.isHidden = mode == .compact
        modeButton.image = NSImage(
            systemSymbolName: mode == .detail ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
            accessibilityDescription: "Toggle layout"
        )

        let newSize = NSSize(width: 380, height: mode == .detail ? 350 : 220)
        guard let window = view.window else { return }
        var frame = window.frame
        frame.origin.y += frame.height - newSize.height
        frame.size = newSize
        if animated {
            window.animator().setFrame(frame, display: true)
        } else {
            window.setFrame(frame, display: true)
        }
        (window as? WidgetWindow)?.saveFrame()
    }

    @objc private func quit() {
        (view.window as? WidgetWindow)?.saveFrame()
        NSApp.terminate(nil)
    }

    func windowDidMove(_ notification: Notification) {
        (view.window as? WidgetWindow)?.saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        (view.window as? WidgetWindow)?.saveFrame()
    }

    private func refresh() {
        let snapshot = sampler.sample()

        cpuHistory.append(snapshot.cpuPercent)
        if cpuHistory.count > 60 {
            cpuHistory.removeFirst(cpuHistory.count - 60)
        }

        let cpuAccent = accentForCPU(snapshot.cpuPercent)
        cpuTile.update(
            value: String(format: "%.0f%%", snapshot.cpuPercent),
            detail: "load",
            accent: cpuAccent
        )
        memoryTile.update(
            value: String(format: "%.1f GB", snapshot.memoryUsedGB),
            detail: "\(snapshot.memoryPressure) / \(String(format: "%.0f", snapshot.memoryTotalGB)) GB",
            accent: accentForMemory(snapshot.memoryPressure)
        )
        networkTile.update(
            value: "↓ \(formatBytes(snapshot.downloadBytesPerSecond))/s",
            detail: "↑ \(formatBytes(snapshot.uploadBytesPerSecond))/s",
            accent: Palette.cyan
        )

        cpuChart.values = cpuHistory
        cpuChart.strokeColor = cpuAccent
        cacheValue.stringValue = String(format: "%.1f GB reclaimable", snapshot.memoryCacheGB)
        diskValue.stringValue = String(format: "%.0f GB free", snapshot.diskFreeGB)
        updatedValue.stringValue = DateFormatter.widgetTime.string(from: snapshot.timestamp)

        for index in topRows.indices {
            if index < snapshot.topProcesses.count {
                topRows[index].update(snapshot.topProcesses[index])
            } else {
                topRows[index].clear()
            }
        }
    }

    private func accentForCPU(_ value: Double) -> NSColor {
        if value >= 80 { return Palette.red }
        if value >= 55 { return Palette.orange }
        return Palette.green
    }

    private func accentForMemory(_ pressure: String) -> NSColor {
        switch pressure {
        case "High": return Palette.red
        case "Med": return Palette.orange
        default: return Palette.green
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= 1_048_576 {
            return String(format: "%.1f MB", value / 1_048_576)
        }
        if value >= 1024 {
            return String(format: "%.0f KB", value / 1024)
        }
        return "\(bytes) B"
    }
}

final class WidgetView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        isEmphasized = true
        wantsLayer = true
        layer?.cornerRadius = 28
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = Palette.panelTint.cgColor
        layer?.borderColor = Palette.border.cgColor
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MetricTileView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let valueField = NSTextField(labelWithString: "--")
    private let detailField = NSTextField(labelWithString: "--")
    private let accentBar = NSView()

    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = Palette.tileBackground.cgColor
        layer?.borderColor = Palette.tileBorder.cgColor
        layer?.borderWidth = 0.8

        titleField.stringValue = title.uppercased()
        titleField.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        titleField.textColor = Palette.mutedText

        valueField.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        valueField.textColor = Palette.primaryText
        valueField.lineBreakMode = .byTruncatingMiddle
        valueField.maximumNumberOfLines = 1

        detailField.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        detailField.textColor = Palette.secondaryText
        detailField.lineBreakMode = .byTruncatingTail
        detailField.maximumNumberOfLines = 1

        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleField, valueField, detailField])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(accentBar)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 88),
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            textStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 9),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        update(value: "--", detail: "--", accent: Palette.green)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(value: String, detail: String, accent: NSColor) {
        valueField.stringValue = value
        detailField.stringValue = detail
        accentBar.layer?.backgroundColor = accent.cgColor
    }
}

final class ProcessRowView: NSView {
    private let nameField = NSTextField(labelWithString: "--")
    private let valueField = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameField.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        nameField.textColor = Palette.primaryText
        nameField.lineBreakMode = .byTruncatingMiddle

        valueField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        valueField.textColor = Palette.secondaryText
        valueField.alignment = .right
        valueField.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let stack = NSStackView(views: [nameField, valueField])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ item: ProcessInfoItem) {
        nameField.stringValue = item.name
        valueField.stringValue = String(format: "%.1f%%", item.cpu)
    }

    func clear() {
        nameField.stringValue = "--"
        valueField.stringValue = "--"
    }
}

final class SparklineView: NSView {
    var values: [Double] = [] {
        didSet { needsDisplay = true }
    }
    var strokeColor: NSColor = Palette.green {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = Palette.tileBackground.cgColor
        layer?.borderColor = Palette.tileBorder.cgColor
        layer?.borderWidth = 0.8
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard values.count > 1 else { return }

        let chartRect = bounds.insetBy(dx: 12, dy: 10)
        drawGrid(in: chartRect)

        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        for (index, value) in values.enumerated() {
            let x = chartRect.minX + chartRect.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let clamped = max(0, min(100, value))
            let y = chartRect.minY + chartRect.height * CGFloat(clamped / 100)
            let point = NSPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }

        strokeColor.setStroke()
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: Palette.mutedText
        ]
        "CPU 60s".draw(at: NSPoint(x: 12, y: bounds.height - 20), withAttributes: attrs)
    }

    private func drawGrid(in rect: NSRect) {
        let grid = NSBezierPath()
        grid.lineWidth = 1
        for fraction in [0.25, 0.5, 0.75] {
            let y = rect.minY + rect.height * CGFloat(fraction)
            grid.move(to: NSPoint(x: rect.minX, y: y))
            grid.line(to: NSPoint(x: rect.maxX, y: y))
        }
        Palette.grid.setStroke()
        grid.stroke()
    }
}

final class StatusDotView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 9, height: 9))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 9).isActive = true
        heightAnchor.constraint(equalToConstant: 9).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 4.5
        layer?.backgroundColor = Palette.green.cgColor
        layer?.shadowColor = Palette.green.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 5
        layer?.shadowOffset = .zero
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum Palette {
    static let panelTint = NSColor(calibratedWhite: 1.0, alpha: 0.08)
    static let tileBackground = NSColor(calibratedWhite: 1.0, alpha: 0.075)
    static let border = NSColor(calibratedWhite: 1.0, alpha: 0.32)
    static let tileBorder = NSColor(calibratedWhite: 1.0, alpha: 0.26)
    static let grid = NSColor(calibratedWhite: 1.0, alpha: 0.18)
    static let primaryText = NSColor(calibratedWhite: 1.0, alpha: 0.98)
    static let secondaryText = NSColor(calibratedWhite: 1.0, alpha: 0.76)
    static let mutedText = NSColor(calibratedWhite: 1.0, alpha: 0.56)
    static let green = NSColor(calibratedRed: 0.70, green: 1.00, blue: 0.84, alpha: 1.0)
    static let orange = NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.48, alpha: 1.0)
    static let red = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.58, alpha: 1.0)
    static let cyan = NSColor(calibratedRed: 0.82, green: 0.95, blue: 1.00, alpha: 1.0)
}

private extension DateFormatter {
    static let widgetTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
