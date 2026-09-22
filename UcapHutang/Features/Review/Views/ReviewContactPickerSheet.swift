import SwiftUI

struct ReviewContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewContactPickerViewModel
    @State private var isCreatingContact = false
    @State private var createdContact: ContactRef?
    private let onPick: ([ContactRef]) -> Void

    init(
        allowsMultipleSelection: Bool,
        initialQuery: String,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            allowsMultipleSelection: allowsMultipleSelection,
            initialQuery: initialQuery,
            contacts: contacts,
            repository: repository
        ))
        self.onPick = onPick
    }

    init(
        request: ContactPickerRequest,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        self.init(
            allowsMultipleSelection: request.allowsMultipleSelection,
            initialQuery: request.initialQuery,
            contacts: contacts,
            repository: repository,
            onPick: onPick
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.hasNoResults {
                    Section {
                        Button {
                            isCreatingContact = true
                        } label: {
                            createContactRow
                        }
                        .buttonStyle(.plain)
                    }
                }

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
                    ContentUnavailableView {
                        Label("Tidak menemukan kontak?", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("Kamu tetap bisa membuat kontak baru dari nama yang sedang dicari.")
                    } actions: {
                        Button("Buat Kontak") {
                            isCreatingContact = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $isCreatingContact, onDismiss: finishContactCreation) {
                NewContactView(suggestedName: viewModel.newContactName) { contact in
                    createdContact = contact
                    isCreatingContact = false
                }
            }
        }
    }

    private var createContactRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Buat Kontak Baru")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 8)
            if !viewModel.newContactName.isEmpty {
                Text(viewModel.newContactName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
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

    /// Runs after the New Contact sheet is fully dismissed, so this sheet can close safely.
    private func finishContactCreation() {
        guard let contact = createdContact else { return }
        createdContact = nil
        Task {
            if await viewModel.didCreateContact(contact) {
                onPick([contact])
                dismiss()
            }
        }
    }
}
