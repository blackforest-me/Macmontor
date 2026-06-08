import AppKit

final class WidgetView: NSVisualEffectView {
    private let overlayLayer = CALayer()
    private let resizeHandle = ResizeHandleView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 28
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        overlayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.insertSublayer(overlayLayer, at: 0)
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(resizeHandle)
        NSLayoutConstraint.activate([
            resizeHandle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            resizeHandle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            resizeHandle.widthAnchor.constraint(equalToConstant: 18),
            resizeHandle.heightAnchor.constraint(equalToConstant: 18)
        ])
        applyAppearance()
    }

    override func layout() {
        super.layout()
        overlayLayer.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyAppearance() {
        material = Palette.visualEffectMaterial
        blendingMode = .behindWindow
        state = .active
        isEmphasized = true
        layer?.backgroundColor = Palette.panelTint.cgColor
        layer?.borderColor = Palette.border.cgColor
        overlayLayer.backgroundColor = Palette.panelOverlay.cgColor
        resizeHandle.needsDisplay = true
    }
}

final class ResizeHandleView: NSView {
    private var initialWindowFrame: NSRect = .zero
    private var initialMouseLocation: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "Resize"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        initialWindowFrame = window?.frame ?? .zero
        initialMouseLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let current = NSEvent.mouseLocation
        let deltaX = current.x - initialMouseLocation.x
        let deltaY = current.y - initialMouseLocation.y

        let width = min(max(initialWindowFrame.width + deltaX, WidgetWindow.minimumSize.width), WidgetWindow.maximumSize.width)
        let height = min(max(initialWindowFrame.height - deltaY, WidgetWindow.minimumSize.height), WidgetWindow.maximumSize.height)
        let topY = initialWindowFrame.maxY

        let frame = NSRect(
            x: initialWindowFrame.minX,
            y: topY - height,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        (window as? WidgetWindow)?.saveFrame()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath()
        path.lineWidth = 1.2
        path.lineCapStyle = .round

        for offset in [4.0, 8.0, 12.0] {
            path.move(to: NSPoint(x: bounds.maxX - CGFloat(offset), y: bounds.minY + 2))
            path.line(to: NSPoint(x: bounds.maxX - 2, y: bounds.minY + CGFloat(offset)))
        }

        Palette.resizeHandle.setStroke()
        path.stroke()
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
        layer?.borderWidth = 0.8

        titleField.stringValue = title.uppercased()
        titleField.font = .monospacedSystemFont(ofSize: 10, weight: .bold)

        valueField.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        valueField.lineBreakMode = .byTruncatingMiddle
        valueField.maximumNumberOfLines = 1

        detailField.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
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
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(value: String, detail: String, accent: NSColor) {
        valueField.stringValue = value
        detailField.stringValue = detail
        accentBar.layer?.backgroundColor = accent.cgColor
    }

    func applyAppearance() {
        layer?.backgroundColor = Palette.tileBackground.cgColor
        layer?.borderColor = Palette.tileBorder.cgColor
        titleField.textColor = Palette.mutedText
        valueField.textColor = Palette.primaryText
        detailField.textColor = Palette.secondaryText
    }
}

final class ProcessRowView: NSView {
    private let nameField = NSTextField(labelWithString: "--")
    private let valueField = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameField.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        nameField.lineBreakMode = .byTruncatingMiddle

        valueField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
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
        applyAppearance()
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

    func applyAppearance() {
        nameField.textColor = Palette.primaryText
        valueField.textColor = Palette.secondaryText
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
        layer?.borderWidth = 0.8
        applyAppearance()
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

    func applyAppearance() {
        layer?.backgroundColor = Palette.tileBackground.cgColor
        layer?.borderColor = Palette.tileBorder.cgColor
        needsDisplay = true
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
