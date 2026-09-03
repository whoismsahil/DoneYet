import SwiftUI
import UIKit

enum ReminderEmojiStyle {
    struct Palette {
        let backgroundHex: UInt32
        let textHex: UInt32
    }

    static func normalized(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }

    static func palette(for raw: String?) -> Palette? {
        guard let emoji = normalized(raw) else { return nil }
        let hex = dominantHex(from: emoji) ?? fallbackHex(from: emoji)
        let pair = soothingPair(from: hex)
        return Palette(backgroundHex: pair.background, textHex: pair.text)
    }

    static func contrastingText(forBackground hex: UInt32) -> UInt32 {
        soothingPair(from: hex).text
    }

    private static func dominantHex(from emoji: String) -> UInt32? {
        let size: CGFloat = 128
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let font = UIFont(name: "AppleColorEmoji", size: 96) ?? .systemFont(ofSize: 96)
        let image = renderer.image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraph
            ]
            let drawn = (emoji as NSString).boundingRect(
                with: CGSize(width: size, height: size),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            (emoji as NSString).draw(
                in: CGRect(
                    x: (size - drawn.width) / 2,
                    y: (size - drawn.height) / 2,
                    width: drawn.width,
                    height: drawn.height
                ),
                withAttributes: attrs
            )
        }

        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorR = 0.0
        var colorG = 0.0
        var colorB = 0.0
        var colorWeight = 0.0
        var toneR = 0.0
        var toneG = 0.0
        var toneB = 0.0
        var toneWeight = 0.0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3])
            guard alpha > 40 else { continue }
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let chroma = (maxChannel - minChannel) / 255
            let brightness = (red + green + blue) / 3

            // Ignore near-white paper around the glyph.
            if brightness > 246, chroma < 0.08 { continue }

            let coverage = alpha / 255
            if chroma > 0.12, maxChannel > 18 {
                let weight = chroma * chroma * coverage
                colorR += red * weight
                colorG += green * weight
                colorB += blue * weight
                colorWeight += weight
            }

            let tone = coverage * (0.35 + chroma * 0.65)
            toneR += red * tone
            toneG += green * tone
            toneB += blue * tone
            toneWeight += tone
        }

        if colorWeight > 0.8 {
            return rgbHex(colorR / colorWeight, colorG / colorWeight, colorB / colorWeight)
        }
        if toneWeight > 0 {
            return rgbHex(toneR / toneWeight, toneG / toneWeight, toneB / toneWeight)
        }
        return nil
    }

    private static func fallbackHex(from emoji: String) -> UInt32 {
        var hash: UInt32 = 2_166_132_261
        for scalar in emoji.unicodeScalars {
            hash ^= scalar.value
            hash &*= 16_777_619
        }
        let hue = Double(hash % 360) / 360
        return hexFromHSL(HSL(h: hue, s: 0.38, l: 0.58))
    }

    private static func soothingPair(from hex: UInt32) -> (background: UInt32, text: UInt32) {
        var source = hsl(from: hex)
        let isGray = source.s < 0.14

        let wash = source.l < 0.28 ? 0.74 : (source.l > 0.82 ? 0.42 : 0.60)
        let backgroundHex = rgbHex(
            Double((hex >> 16) & 0xFF) * (1 - wash) + 255 * wash,
            Double((hex >> 8) & 0xFF) * (1 - wash) + 255 * wash,
            Double(hex & 0xFF) * (1 - wash) + 255 * wash
        )

        if isGray {
            source.s = 0.04
            source.h = 0.62
            source.l = 0.36
        } else {
            source.s = min(max(source.s * 0.55 + 0.22, 0.32), 0.62)
            source.l = 0.38
        }

        var textHex = hexFromHSL(source)
        if contrastRatio(backgroundHex, textHex) < 4.5 {
            source.l = 0.28
            textHex = hexFromHSL(source)
        }

        return (backgroundHex, textHex)
    }

    private static func rgbHex(_ red: Double, _ green: Double, _ blue: Double) -> UInt32 {
        let r = UInt32(min(max(red, 0), 255).rounded())
        let g = UInt32(min(max(green, 0), 255).rounded())
        let b = UInt32(min(max(blue, 0), 255).rounded())
        return (r << 16) | (g << 8) | b
    }

    private struct HSL {
        var h: Double
        var s: Double
        var l: Double
    }

    private static func hsl(from hex: UInt32) -> HSL {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2
        let d = maxC - minC
        guard d > 0.0001 else { return HSL(h: 0, s: 0, l: l) }

        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        let h: Double
        if maxC == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        return HSL(h: h / 6, s: s, l: l)
    }

    private static func hexFromHSL(_ hsl: HSL) -> UInt32 {
        let h = hsl.h
        let s = hsl.s
        let l = hsl.l
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        let r = hueToRGB(p: p, q: q, t: h + 1.0 / 3.0)
        let g = hueToRGB(p: p, q: q, t: h)
        let b = hueToRGB(p: p, q: q, t: h - 1.0 / 3.0)
        return (UInt32((r * 255).rounded()) << 16)
            | (UInt32((g * 255).rounded()) << 8)
            | UInt32((b * 255).rounded())
    }

    private static func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
        if t < 1.0 / 2.0 { return q }
        if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
        return p
    }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((hex >> 16) & 0xFF)
        let g = channel((hex >> 8) & 0xFF)
        let b = channel(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let l1 = relativeLuminance(a)
        let l2 = relativeLuminance(b)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

struct ReminderEmojiGlyph: View {
    let emoji: String
    var size: CGFloat = 22
    var white = false

    var body: some View {
        Group {
            if let emoji = ReminderEmojiStyle.normalized(emoji) {
                Text(emoji)
                    .font(.system(size: size * 0.9))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
