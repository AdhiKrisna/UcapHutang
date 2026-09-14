import SwiftUI

struct PengaturanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: PengaturanViewModel

    init(scheduler: any ReminderScheduling, settingsStore: any ReminderSettingsStore) {
        _viewModel = State(initialValue: PengaturanViewModel(scheduler: scheduler, settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Pengingat Review", isOn: Binding(
                        get: { viewModel.isReminderEnabled },
                        set: { isOn in Task { await viewModel.setReminderEnabled(isOn) } }
                    ))

                    DatePicker(
                        "Jam",
                        selection: Binding(
                            get: { viewModel.reminderTime },
                            set: { date in Task { await viewModel.setReminderTime(date) } }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .environment(\.locale, Locale(identifier: "id_ID"))
                    .disabled(!viewModel.isReminderEnabled)

                    switch viewModel.access {
                    case .authorized:
                        EmptyView()
                    case .notDetermined:
                        Button("Izinkan Notifikasi") {
                            Task { await viewModel.requestAccess() }
                        }
                    case .denied:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifikasi dimatikan untuk UcapHutang.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Buka Pengaturan") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Pengingat")
                } footer: {
                    Text("Kamu akan diingatkan setiap hari pada jam ini selama masih ada catatan yang perlu ditinjau.")
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { dismiss() }
                }
            }
            .task { await viewModel.refreshAccess() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.refreshAccess() }
                }
            }
        }
    }
}
