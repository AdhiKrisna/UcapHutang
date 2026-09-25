import SwiftUI

struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .subheadline) private var stepBadgeSize: CGFloat = 28

    private let steps = [
        "Tekan dan tahan area kosong di Home Screen.",
        "Pilih Edit, lalu Tambah Widget.",
        "Cari UcapHutang dan pilih widget Catat Cepat.",
        "Tambahkan widget ke Home Screen."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    Image(systemName: "rectangle.3.group.bubble.left.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("Tambahkan Widget UcapHutang")
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("iOS mengharuskan widget ditambahkan sendiri dari Home Screen. Setelah dipasang, sekali tap akan langsung membuka tab Catat untuk memilih Utang/Piutang atau Split Bill.")
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                            instruction(number: index + 1, text: step)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Mengerti")
                        .font(.headline)
                        .foregroundStyle(AppColors.background)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(AppColors.background)
            .navigationTitle("Widget Catat Cepat")
            .navigationBarTitleDisplayMode(.large)
        }
        .presentationDetents([.medium, .large])
    }

    private func instruction(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(AppColors.accent, in: Circle())
            Text(text)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 3)
        }
        .accessibilityElement(children: .combine)
    }
}
