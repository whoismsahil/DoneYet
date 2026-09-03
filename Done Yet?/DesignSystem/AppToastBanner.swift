import Observation
import SwiftUI

@Observable
@MainActor
final class AppToastBanner {
    private(set) var message: String?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String) {
        hideTask?.cancel()
        withAnimation(.spring(duration: 0.38, bounce: 0.24)) {
            self.message = message
        }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                self.message = nil
            }
        }
    }
}

struct ProminentToastBar: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.textPrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
        .padding(.horizontal, 16)
        .accessibilityAddTraits(.isStaticText)
    }
}
