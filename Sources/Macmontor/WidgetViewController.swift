import AppKit
import Foundation

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
    private let hideButton = NSButton()
    private let titleField = NSTextField(labelWithString: "Macmontor")
    private let topHeader = NSTextField(labelWithString: "TOP CPU")
    private var mutedFields: [NSTextField] = []
    private var primaryFields: [NSTextField] = []
    private var secondaryFields: [NSTextField] = []
    private var topRows: [ProcessRowView] = []
    var currentMode: WidgetMode { mode }

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
        titleField.font = .systemFont(ofSize: 16, weight: .bold)

        let titleGroup = NSStackView(views: [StatusDotView(), titleField])
        titleGroup.orientation = .horizontal
        titleGroup.alignment = .centerY
        titleGroup.spacing = 8

        updatedValue.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        updatedValue.alignment = .right

        configureIconButton(modeButton, symbol: "rectangle.compress.vertical", tooltip: "Toggle layout")
        modeButton.target = self
        modeButton.action = #selector(toggleMode)

        configureIconButton(hideButton, symbol: "xmark", tooltip: "Hide widget")
        hideButton.target = self
        hideButton.action = #selector(hideWidget)

        let controls = NSStackView(views: [updatedValue, modeButton, hideButton])
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

        topHeader.font = .monospacedSystemFont(ofSize: 10, weight: .bold)

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
        primaryFields.append(titleField)
        secondaryFields.append(updatedValue)
        mutedFields.append(topHeader)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 17),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -17)
        ])

        applyMode(animated: false)
        applyAppearance()
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
        labelView.widthAnchor.constraint(equalToConstant: 58).isActive = true
        mutedFields.append(labelView)

        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        value.alignment = .right
        value.lineBreakMode = .byTruncatingMiddle
        primaryFields.append(value)

        let row = NSStackView(views: [labelView, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    @objc func toggleMode() {
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

        guard let window = view.window else { return }
        let newHeight = mode == .detail ? WidgetWindow.detailHeight : WidgetWindow.compactHeight
        var frame = window.frame
        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        if animated {
            window.animator().setFrame(frame, display: true)
        } else {
            window.setFrame(frame, display: true)
        }
        (window as? WidgetWindow)?.saveFrame()
    }

    func resetWindowSize(animated: Bool) {
        (view.window as? WidgetWindow)?.resetFrame(for: mode, animated: animated)
    }

    @objc private func hideWidget() {
        (view.window as? WidgetWindow)?.saveFrame()
        view.window?.orderOut(nil)
    }

    func applyAppearance() {
        (view as? WidgetView)?.applyAppearance()
        cpuTile.applyAppearance()
        memoryTile.applyAppearance()
        networkTile.applyAppearance()
        cpuChart.applyAppearance()
        topRows.forEach { $0.applyAppearance() }
        primaryFields.forEach { $0.textColor = Palette.primaryText }
        secondaryFields.forEach { $0.textColor = Palette.secondaryText }
        mutedFields.forEach { $0.textColor = Palette.mutedText }
        modeButton.contentTintColor = Palette.secondaryText
        hideButton.contentTintColor = Palette.secondaryText
        view.needsDisplay = true
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
