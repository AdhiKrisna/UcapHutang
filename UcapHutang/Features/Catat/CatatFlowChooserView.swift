import SwiftUI

struct CatatFlowChooserView: View {
    let onSelect: (CaptureFlow) -> Void
    private let readiness = MLXQwenClient.readiness()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(CaptureFlow.allCases) { flow in
                    Button { onSelect(flow) } label: {
                        HStack {
                            Image(systemName: flow == .personal ? "person.fill" : "person.3.fill")
                                .frame(width: 32)
                            Text(flow.title).font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(AppSpacing.large)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(readiness != .ready)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Pilih jenis pencatatan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
