import SwiftUI

enum AppTypography {
    static func appTitle() -> Font {
        AppFont.instrument(34, weight: .bold)
    }

    static func sectionTitle() -> Font {
        AppFont.instrument(22, weight: .bold)
    }

    static func reminderTitle() -> Font {
        AppFont.instrument(17, weight: .bold)
    }

    static func body() -> Font {
        AppFont.instrument(16, weight: .regular)
    }

    static func metadata() -> Font {
        AppFont.mono(11, weight: .medium)
    }

    static func buttonLabel() -> Font {
        AppFont.mono(13, weight: .bold)
    }

    static func widgetPreviewTitle() -> Font {
        AppFont.instrument(20, weight: .bold)
    }

    static func widgetPreviewButton() -> Font {
        AppFont.mono(12, weight: .bold)
    }

    static func pixelLabel() -> Font {
        AppFont.mono(10, weight: .medium)
    }
}

enum AppTextStyle {
    static let uppercaseTracking: CGFloat = 1.2
    static let headlineTracking: CGFloat = 0.6
}
