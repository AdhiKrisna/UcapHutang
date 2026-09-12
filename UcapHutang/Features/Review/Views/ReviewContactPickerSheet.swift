import SwiftUI

struct ReviewContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewContactPickerViewModel
    private let onPick: ([ContactRef]) -> Void

    init(
        request: ContactPickerRequest,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            allowsMultipleSelection: request.allowsMultipleSelection,
            initialQuery: request.initialQuery,
            contacts: contacts,
            repository: repository
        ))
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.filteredRecentContacts.isEmpty {
                    Section("Kontak yang pernah dicatat") {
                        ForEach(viewModel.filteredRecentContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
                if !viewModel.deviceContacts.isEmpty {
                    Section("Kontak di iPhone") {
                        ForEach(viewModel.deviceContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if viewModel.hasNoResults {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                }
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cari kontak"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                if viewModel.allowsMultipleSelection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Selesai") {
                            onPick(viewModel.selectedContacts)
                            dismiss()
                        }
                        .disabled(viewModel.selectedContacts.isEmpty)
                    }
                }
            }
            .task { await viewModel.load() }
            .task(id: viewModel.searchQuery) { await viewModel.search() }
        }
    }

    private func row(_ contact: ContactRef) -> some View {
        Button {
            if viewModel.allowsMultipleSelection {
                viewModel.toggle(contact)
            } else {
                onPick([contact])
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if viewModel.allowsMultipleSelection {
                    Image(systemName: viewModel.isSelected(contact) ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(viewModel.isSelected(contact) ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.allowsMultipleSelection && viewModel.isSelected(contact) ? .isSelected : [])
    }
}
