import AppKit
import SwiftUI

enum BrandAssets {
    static let icon: NSImage? = {
        let candidates: [URL?] = [
            Bundle.module.url(
                forResource: "icon_1024x1024",
                withExtension: "png",
                subdirectory: "Resources"
            ),
            Bundle.module.url(forResource: "icon_1024x1024", withExtension: "png"),
            Bundle.main.url(forResource: "icon_1024x1024", withExtension: "png")
        ]
        for case let url? in candidates {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }()

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static func statusBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            context.saveGraphicsState()
            NSColor.black.setFill()

            let shield = NSBezierPath()
            shield.move(to: NSPoint(x: 9, y: 16.9))
            shield.curve(
                to: NSPoint(x: 15.1, y: 14.6),
                controlPoint1: NSPoint(x: 11.0, y: 16.9),
                controlPoint2: NSPoint(x: 13.1, y: 16.1)
            )
            shield.line(to: NSPoint(x: 15.1, y: 8.2))
            shield.curve(
                to: NSPoint(x: 9, y: 1.2),
                controlPoint1: NSPoint(x: 15.1, y: 5.3),
                controlPoint2: NSPoint(x: 12.7, y: 2.3)
            )
            shield.curve(
                to: NSPoint(x: 2.9, y: 8.2),
                controlPoint1: NSPoint(x: 5.3, y: 2.3),
                controlPoint2: NSPoint(x: 2.9, y: 5.3)
            )
            shield.line(to: NSPoint(x: 2.9, y: 14.6))
            shield.curve(
                to: NSPoint(x: 9, y: 16.9),
                controlPoint1: NSPoint(x: 4.9, y: 16.1),
                controlPoint2: NSPoint(x: 7.0, y: 16.9)
            )
            shield.close()
            shield.fill()

            context.compositingOperation = .clear
            NSColor.white.setStroke()

            func chevron(centerY: CGFloat) {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 5.7, y: centerY - 1.45))
                path.line(to: NSPoint(x: 9, y: centerY + 1.45))
                path.line(to: NSPoint(x: 12.3, y: centerY - 1.45))
                path.lineWidth = 1.42
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }

            chevron(centerY: 12.3)
            chevron(centerY: 9.1)

            NSColor.white.setFill()
            let dot = NSBezierPath(
                ovalIn: NSRect(x: 7.95, y: 5.25, width: 2.1, height: 2.1)
            )
            dot.fill()

            context.compositingOperation = .sourceOver
            context.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct BrandMark: View {
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let image = BrandAssets.icon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [CBTheme.lime, CBTheme.limeDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(CBTheme.background)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

struct BrandWordmark: View {
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 2) {
            HStack(spacing: 0) {
                Text(L10n.t("Builders "))
                    .fontWeight(.bold)
                Text(L10n.t("Protect"))
                    .fontWeight(.light)
            }
            .font(.system(size: compact ? 16 : 21, design: .rounded))
            .foregroundStyle(CBTheme.text)

            if !compact {
                Text(L10n.t("POR CULTURA BUILDER"))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(CBTheme.textTertiary)
            }
        }
    }
}
