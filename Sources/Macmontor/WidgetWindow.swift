import AppKit
import Foundation

final class WidgetWindow: NSWindow {
    private static let frameKey = "widgetFrame"
    private static let alwaysOnTopKey = "alwaysOnTop"
    static let defaultWidth: CGFloat = 380
    static let detailHeight: CGFloat = 350
    static let compactHeight: CGFloat = 220
    static let minimumSize = NSSize(width: 340, height: 210)
    static let maximumSize = NSSize(width: 620, height: 520)

    init(contentViewController: NSViewController) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: Self.defaultWidth, height: Self.detailHeight)
        let origin = NSPoint(
            x: screenFrame.midX + 80,
            y: screenFrame.midY - size.height / 2
        )
        let defaultFrame = NSRect(origin: origin, size: size)
        let savedFrame = UserDefaults.standard.string(forKey: Self.frameKey).flatMap(NSRectFromString)
        let initialFrame = savedFrame.map { NSIntersectionRect(screenFrame, $0).isEmpty ? defaultFrame : $0 } ?? defaultFrame

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        level = UserDefaults.standard.bool(forKey: Self.alwaysOnTopKey) ? .floating : .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        minSize = Self.minimumSize
        maxSize = Self.maximumSize
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.frameKey)
    }

    var isAlwaysOnTop: Bool {
        level == .floating
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        level = enabled ? .floating : .normal
        UserDefaults.standard.set(enabled, forKey: Self.alwaysOnTopKey)
    }

    func resetFrame(for mode: WidgetMode, animated: Bool) {
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: Self.defaultWidth, height: mode == .detail ? Self.detailHeight : Self.compactHeight)
        var newFrame = NSRect(
            x: min(max(frame.minX, screenFrame.minX), screenFrame.maxX - size.width),
            y: min(max(frame.maxY - size.height, screenFrame.minY), screenFrame.maxY - size.height),
            width: size.width,
            height: size.height
        )
        if NSIntersectionRect(screenFrame, newFrame).isEmpty {
            newFrame.origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.midY - size.height / 2)
        }

        if animated {
            animator().setFrame(newFrame, display: true)
        } else {
            setFrame(newFrame, display: true)
        }
        saveFrame()
    }
}
