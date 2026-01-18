import AppKit
import Foundation

enum ColorHexCodec {
    static let defaultSelectionDimmingColorHex = "#FFFFFF1E"
    static let defaultSelectionDimmingColor = NSColor.white.withAlphaComponent(30.0 / 255.0)

    static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }
        guard cleaned.allSatisfy(\.isHexDigit) else { return nil }
        let upper = cleaned.uppercased()
        let withAlpha = cleaned.count == 6 ? upper + "FF" : upper
        return "#\(withAlpha)"
    }

    static func nsColor(from value: String) -> NSColor? {
        guard let normalized = normalized(value) else { return nil }
        let hex = Array(normalized.dropFirst())
        guard hex.count == 8 else { return nil }

        let red = component(hex, start: 0)
        let green = component(hex, start: 2)
        let blue = component(hex, start: 4)
        let alpha = component(hex, start: 6)

        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    static func hex(from color: NSColor) -> String {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        let alpha = Int(round(rgbColor.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    private static func component(_ hex: [Character], start: Int) -> CGFloat {
        let pair = String(hex[start ..< start + 2])
        let value = Int(pair, radix: 16) ?? 0
        return CGFloat(value) / 255.0
    }
}
