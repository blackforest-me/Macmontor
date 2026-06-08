import AppKit

let size = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

NSColor.clear.setFill()
canvas.fill()

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

func drawLinearGradient(in path: NSBezierPath, colors: [NSColor], locations: [CGFloat], angle: CGFloat) {
    let gradient = NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    gradient.draw(in: path, angle: angle)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(alpha)
    ]
    NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}

let iconShape = roundedRect(0, 0, 1024, 1024, 232)
drawLinearGradient(
    in: iconShape,
    colors: [
        NSColor(calibratedRed: 0.55, green: 0.91, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.22, green: 0.64, blue: 0.85, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.45, alpha: 1)
    ],
    locations: [0, 0.48, 1],
    angle: -42
)

let glow = NSBezierPath(ovalIn: NSRect(x: 462, y: 88, width: 620, height: 430))
NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.80, alpha: 0.36).setFill()
glow.fill()

NSShadow().with {
    $0.shadowOffset = NSSize(width: 0, height: -34)
    $0.shadowBlurRadius = 58
    $0.shadowColor = NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.24, alpha: 0.36)
}.set()

let glass = roundedRect(214, 216, 596, 592, 128)
drawLinearGradient(
    in: glass,
    colors: [
        NSColor.white.withAlphaComponent(0.46),
        NSColor.white.withAlphaComponent(0.19),
        NSColor(calibratedRed: 0.82, green: 0.96, blue: 1.0, alpha: 0.12)
    ],
    locations: [0, 0.52, 1],
    angle: -45
)

NSShadow().set()
NSColor.white.withAlphaComponent(0.48).setStroke()
glass.lineWidth = 4
glass.stroke()

let inner = roundedRect(250, 250, 524, 524, 96)
NSColor.white.withAlphaComponent(0.15).setStroke()
inner.lineWidth = 2
inner.stroke()

NSColor(calibratedRed: 0.66, green: 1.0, blue: 0.82, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 292, y: 664, width: 44, height: 44)).fill()
drawText("M", x: 356, y: 656, size: 76, weight: .bold)

func drawMetricTile(x: CGFloat, label: String, value: String, accent: NSColor) {
    let tile = roundedRect(x, 434, 200, 146, 36)
    NSColor.white.withAlphaComponent(0.16).setFill()
    tile.fill()
    NSColor.white.withAlphaComponent(0.25).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    accent.setFill()
    roundedRect(x + 32, 467, 10, 80, 5).fill()
    drawText(label, x: x + 66, y: 506, size: 24, weight: .bold, alpha: 0.68, mono: true)
    drawText(value, x: x + 66, y: 456, size: 46, weight: .bold)
}

drawMetricTile(x: 288, label: "CPU", value: "18", accent: NSColor(calibratedRed: 0.65, green: 1, blue: 0.83, alpha: 1))
drawMetricTile(x: 536, label: "MEM", value: "15", accent: NSColor(calibratedRed: 0.77, green: 0.96, blue: 1, alpha: 1))

let graph = NSBezierPath()
graph.move(to: NSPoint(x: 292, y: 336))
graph.curve(to: NSPoint(x: 438, y: 351), controlPoint1: NSPoint(x: 348, y: 350), controlPoint2: NSPoint(x: 382, y: 364))
graph.curve(to: NSPoint(x: 580, y: 338), controlPoint1: NSPoint(x: 490, y: 339), controlPoint2: NSPoint(x: 520, y: 318))
graph.curve(to: NSPoint(x: 736, y: 368), controlPoint1: NSPoint(x: 640, y: 358), controlPoint2: NSPoint(x: 674, y: 382))
graph.lineWidth = 12
graph.lineCapStyle = .round
NSColor(calibratedRed: 0.74, green: 1, blue: 0.88, alpha: 1).setStroke()
graph.stroke()

NSColor.white.withAlphaComponent(0.18).setStroke()
let bottomGuide = NSBezierPath()
bottomGuide.move(to: NSPoint(x: 292, y: 300))
bottomGuide.line(to: NSPoint(x: 736, y: 300))
bottomGuide.lineWidth = 3
bottomGuide.stroke()

let topGuide = NSBezierPath()
topGuide.move(to: NSPoint(x: 292, y: 382))
topGuide.line(to: NSPoint(x: 736, y: 382))
topGuide.lineWidth = 3
topGuide.stroke()

NSGraphicsContext.restoreGraphicsState()

guard
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Unable to encode PNG")
}

let outputURL = URL(fileURLWithPath: "Assets/macmontor-app-icon.png")
try png.write(to: outputURL)

extension NSObjectProtocol {
    func with(_ configure: (Self) -> Void) -> Self {
        configure(self)
        return self
    }
}
