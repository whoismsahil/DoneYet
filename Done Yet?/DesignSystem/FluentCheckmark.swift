import SwiftUI
import WidgetKit

struct CompletedCheckmark: View {
    let foreground: Color
    let size: CGFloat

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            Circle()
                .fill(circleFill)
                .overlay {
                    Circle()
                        .strokeBorder(circleStroke, lineWidth: usesVibrantChrome ? 1.5 : 0)
                }

            FluentCheckmark()
                .fill(checkmarkFill)
                .padding(size * 0.22)
        }
        .frame(width: size, height: size)
        .opacity(0.6)
        .widgetAccentable()
        .accessibilityLabel("Completed")
    }

    private var usesVibrantChrome: Bool {
        switch renderingMode {
        case .accented, .vibrant:
            return true
        default:
            return false
        }
    }

    private var circleFill: Color {
        usesVibrantChrome ? Color.primary.opacity(0.18) : Color.white
    }

    private var circleStroke: Color {
        usesVibrantChrome ? Color.primary.opacity(0.55) : .clear
    }

    private var checkmarkFill: Color {
        usesVibrantChrome ? Color.primary : foreground
    }
}

/// Fluent UI System Icons, `ic_fluent_checkmark_24_filled` (MIT).
struct FluentCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: 8.5, y: 16.5858))
        path.addLine(to: CGPoint(x: 4.70711, y: 12.7929))
        path.addCurve(
            to: CGPoint(x: 3.29289, y: 12.7929),
            control1: CGPoint(x: 4.31658, y: 12.4024),
            control2: CGPoint(x: 3.68342, y: 12.4024)
        )
        path.addCurve(
            to: CGPoint(x: 3.29289, y: 14.2071),
            control1: CGPoint(x: 2.90237, y: 13.1834),
            control2: CGPoint(x: 2.90237, y: 13.8166)
        )
        path.addLine(to: CGPoint(x: 7.79289, y: 18.7071))
        path.addCurve(
            to: CGPoint(x: 9.20711, y: 18.7071),
            control1: CGPoint(x: 8.18342, y: 19.0976),
            control2: CGPoint(x: 8.81658, y: 19.0976)
        )
        path.addLine(to: CGPoint(x: 20.2071, y: 7.70711))
        path.addCurve(
            to: CGPoint(x: 20.2071, y: 6.29289),
            control1: CGPoint(x: 20.5976, y: 7.31658),
            control2: CGPoint(x: 20.5976, y: 6.68342)
        )
        path.addCurve(
            to: CGPoint(x: 18.7929, y: 6.29289),
            control1: CGPoint(x: 19.8166, y: 5.90237),
            control2: CGPoint(x: 19.1834, y: 5.90237)
        )
        path.addLine(to: CGPoint(x: 8.5, y: 16.5858))
        path.closeSubpath()

        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
        return path.applying(transform)
    }
}
