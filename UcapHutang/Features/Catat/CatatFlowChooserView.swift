import SwiftUI

struct CatatFlowChooserView: View {
    let onSelect: (CaptureFlow) -> Void
    private let readiness = MLXQwenClient.readiness()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(CaptureFlow.allCases) { flow in
                    Button { onSelect(flow) } label: {
                        HStack(spacing: AppSpacing.large) {
                            Image(systemName: flowIcon(flow))
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(flowAccent(flow))
                                .frame(width: 58, height: 58)
                                .background(flowAccent(flow).opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                Text(flow.title)
                                    .font(.title3.weight(.bold))
                                Text(flowDescription(flow))
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(flowAccent(flow))
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(AppSpacing.xLarge)
                        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [AppColors.surface, flowAccent(flow).opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                .stroke(flowAccent(flow).opacity(0.25))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(readiness != .ready)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.xLarge)
            .padding(.top, AppSpacing.xLarge)
            .navigationTitle("Pilih jenis pencatatan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func flowIcon(_ flow: CaptureFlow) -> String {
        flow == .personal ? "person.2" : "person.3.fill"
    }

    private func flowAccent(_ flow: CaptureFlow) -> Color {
        flow == .personal ? AppColors.accent : AppColors.split
    }

    private func flowDescription(_ flow: CaptureFlow) -> String {
        flow == .personal
            ? "Catat hutang atau piutang dengan satu orang."
            : "Bagi satu tagihan bersama beberapa orang."
    }
}
