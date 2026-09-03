import SwiftUI
import UIKit

enum AppColors {
    static let pageBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 25 / 255, green: 25 / 255, blue: 25 / 255, alpha: 1)
            : UIColor(red: 247 / 255, green: 246 / 255, blue: 243 / 255, alpha: 1)
    })

    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 32 / 255, green: 32 / 255, blue: 32 / 255, alpha: 1)
            : UIColor.white
    })

    static let hover = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 47 / 255, green: 47 / 255, blue: 47 / 255, alpha: 1)
            : UIColor(red: 239 / 255, green: 237 / 255, blue: 236 / 255, alpha: 1)
    })

    static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.81)
            : UIColor(red: 55 / 255, green: 53 / 255, blue: 47 / 255, alpha: 1)
    })

    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 155 / 255, green: 155 / 255, blue: 155 / 255, alpha: 1)
            : UIColor(red: 120 / 255, green: 119 / 255, blue: 116 / 255, alpha: 1)
    })

    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 82 / 255, green: 156 / 255, blue: 202 / 255, alpha: 1)
            : UIColor(red: 35 / 255, green: 131 / 255, blue: 226 / 255, alpha: 1)
    })

    static let background = pageBackground
    static let foreground = textPrimary
    static let secondary = textSecondary
    static let tertiary = textSecondary.opacity(0.8)
    static let divider = textPrimary.opacity(0.08)
    static let buttonBackground = textPrimary
    static let buttonForeground = pageBackground
    static let grid = textPrimary.opacity(0.08)
    static let pixel = textPrimary.opacity(0.35)
    static let widgetCircle = Color.white.opacity(0.24)
}
