import SwiftUI

struct SavedToReviewBanner: View {
    let bannerID: UUID
    let onOpen: () -> Void
    let onTimeout: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label("Tersimpan ke Review", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button("Lihat", action: onOpen)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isFocused)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .task(id: bannerID) {
            try? await Task.sleep(for: .seconds(4))
            // Keep the banner while VoiceOver focus is on it.
            while isFocused && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            onTimeout()
        }
    }
}
