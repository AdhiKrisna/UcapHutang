import SwiftUI

struct NotificationPrimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NotificationPrimerViewModel

    init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) {
        _viewModel = State(initialValue: NotificationPrimerViewModel(scheduler: scheduler, settingsStore: settingsStore))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.largeTitle)
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Pengingat Review")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Kami akan mengingatkanmu setiap hari pukul 20.00 untuk meninjau catatan hasil rekaman. Jam pengingat bisa kamu ubah kapan saja di Pengaturan.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.allow() }
                } label: {
                    Text("Izinkan Notifikasi")
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.primary)

                Button("Nanti Saja") {
                    Task { await viewModel.later() }
                }
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }
}
