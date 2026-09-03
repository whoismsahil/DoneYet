import SwiftUI
import UIKit
import CoreText

enum AppFont {
    private static var didRegister = false

    static let instrumentSans = "Instrument Sans"
    static let firaMonoRegular = "Fira Mono"
    static let firaMonoMedium = "Fira Mono Medium"
    static let firaMonoBold = "Fira Mono Bold"

    static func registerFonts() {
        guard !didRegister else { return }
        didRegister = true

        let fontFiles = [
            "InstrumentSans.ttf",
            "FiraMono-Regular.ttf",
            "FiraMono-Medium.ttf",
            "FiraMono-Bold.ttf"
        ]

        for file in fontFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: file.replacingOccurrences(of: ".ttf", with: ""), withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func instrument(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerFonts()
        return .custom(instrumentSans, size: size).weight(weight)
    }

    /// SF Pro Text, Apple’s default UI typeface for sizes under 20pt.
    static func sfProText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// SF Mono, Apple’s monospaced system font.
    static func sfMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerFonts()
        switch weight {
        case .bold, .heavy, .black:
            return .custom(firaMonoBold, size: size)
        case .medium, .semibold:
            return .custom(firaMonoMedium, size: size)
        default:
            return .custom(firaMonoRegular, size: size)
        }
    }
}
