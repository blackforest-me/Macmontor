import AppKit
import Foundation

enum WidgetAppearance: String {
    case glass
    case contrast
}

enum Palette {
    private static let appearanceKey = "widgetAppearance"

    static var appearance: WidgetAppearance {
        get {
            UserDefaults.standard.string(forKey: appearanceKey).flatMap(WidgetAppearance.init(rawValue:)) ?? .glass
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appearanceKey)
        }
    }

    static var visualEffectMaterial: NSVisualEffectView.Material {
        appearance == .contrast ? .popover : .hudWindow
    }

    static var panelTint: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.08)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.05)
        }
    }

    static var panelOverlay: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.02)
        case .contrast:
            return NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.24, alpha: 0.28)
        }
    }

    static var tileBackground: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.075)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.14)
        }
    }

    static var border: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.32)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.42)
        }
    }

    static var tileBorder: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.26)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.34)
        }
    }

    static var grid: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.18)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.26)
        }
    }

    static var primaryText: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.98)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 1.0)
        }
    }

    static var secondaryText: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.76)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.88)
        }
    }

    static var mutedText: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.56)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.70)
        }
    }

    static var resizeHandle: NSColor {
        switch appearance {
        case .glass:
            return NSColor(calibratedWhite: 1.0, alpha: 0.38)
        case .contrast:
            return NSColor(calibratedWhite: 1.0, alpha: 0.54)
        }
    }

    static let green = NSColor(calibratedRed: 0.70, green: 1.00, blue: 0.84, alpha: 1.0)
    static let orange = NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.48, alpha: 1.0)
    static let red = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.58, alpha: 1.0)
    static let cyan = NSColor(calibratedRed: 0.82, green: 0.95, blue: 1.00, alpha: 1.0)
}
