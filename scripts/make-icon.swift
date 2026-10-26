import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let outputURL = URL(fileURLWithPath: outputDirectory)
    .appendingPathComponent("icon_1024x1024.png")

let size = CGFloat(1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Falha ao criar bitmap\n", stderr)
    exit(1)
}
bitmap.size = NSSize(width: size, height: size)

guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Sem contexto grafico\n", stderr)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
graphics.cgContext.translateBy(x: 0, y: size)
graphics.cgContext.scaleBy(x: 1, y: -1)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let outer = NSRect(x: 64, y: 64, width: size - 128, height: size - 128)
let background = NSBezierPath(roundedRect: outer, xRadius: 224, yRadius: 224)
background.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.105, green: 0.118, blue: 0.100, alpha: 1),
    NSColor(calibratedRed: 0.042, green: 0.048, blue: 0.040, alpha: 1),
    NSColor(calibratedRed: 0.018, green: 0.021, blue: 0.017, alpha: 1)
])!
gradient.draw(in: background, angle: -76)

let innerBorder = NSBezierPath(
    roundedRect: outer.insetBy(dx: 7, dy: 7),
    xRadius: 218,
    yRadius: 218
)
NSColor.white.withAlphaComponent(0.10).setStroke()
innerBorder.lineWidth = 3
innerBorder.stroke()

func shieldPath(in rect: NSRect) -> NSBezierPath {
    let x = rect.minX
    let y = rect.minY
    let w = rect.width
    let h = rect.height

    let path = NSBezierPath()
    path.move(to: NSPoint(x: x + 0.205 * w, y: y + 0.055 * h))
    path.curve(
        to: NSPoint(x: x + 0.086 * w, y: y + 0.170 * h),
        controlPoint1: NSPoint(x: x + 0.135 * w, y: y + 0.055 * h),
        controlPoint2: NSPoint(x: x + 0.092 * w, y: y + 0.095 * h)
    )
    path.line(to: NSPoint(x: x + 0.086 * w, y: y + 0.430 * h))
    path.curve(
        to: NSPoint(x: x + 0.500 * w, y: y + 0.982 * h),
        controlPoint1: NSPoint(x: x + 0.086 * w, y: y + 0.665 * h),
        controlPoint2: NSPoint(x: x + 0.235 * w, y: y + 0.845 * h)
    )
    path.curve(
        to: NSPoint(x: x + 0.914 * w, y: y + 0.430 * h),
        controlPoint1: NSPoint(x: x + 0.765 * w, y: y + 0.845 * h),
        controlPoint2: NSPoint(x: x + 0.914 * w, y: y + 0.665 * h)
    )
    path.line(to: NSPoint(x: x + 0.914 * w, y: y + 0.170 * h))
    path.curve(
        to: NSPoint(x: x + 0.795 * w, y: y + 0.055 * h),
        controlPoint1: NSPoint(x: x + 0.908 * w, y: y + 0.095 * h),
        controlPoint2: NSPoint(x: x + 0.865 * w, y: y + 0.055 * h)
    )
    path.close()
    return path
}

func chevronPath(in rect: NSRect, centerY: CGFloat) -> NSBezierPath {
    let x = rect.minX
    let baseY = rect.minY
    let w = rect.width
    let h = rect.height
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x + 0.292 * w, y: baseY + (centerY + 0.075) * h))
    path.line(to: NSPoint(x: x + 0.500 * w, y: baseY + (centerY - 0.010) * h))
    path.line(to: NSPoint(x: x + 0.708 * w, y: baseY + (centerY + 0.075) * h))
    path.lineWidth = 0.088 * w
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    return path
}

let shieldRect = NSRect(x: 292, y: 238, width: 440, height: 610)
let shield = shieldPath(in: shieldRect)

let shieldGradient = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.905, green: 0.918, blue: 0.885, alpha: 1)
])!
shieldGradient.draw(in: shield, angle: -90)

graphics.compositingOperation = .clear

for chevronY in [0.335, 0.500] {
    chevronPath(in: shieldRect, centerY: chevronY).stroke()
}

let dotSize = 0.155 * shieldRect.width
let dot = NSBezierPath(
    ovalIn: NSRect(
        x: shieldRect.midX - dotSize / 2,
        y: shieldRect.minY + 0.720 * shieldRect.height - dotSize / 2,
        width: dotSize,
        height: dotSize
    )
)
dot.fill()

graphics.compositingOperation = .sourceOver
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Falha ao gerar PNG\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print(outputURL.path)
