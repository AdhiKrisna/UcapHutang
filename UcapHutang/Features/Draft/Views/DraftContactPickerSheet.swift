import SwiftUI

struct DraftContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DraftContactPickerViewModel

    var onSelectSingle: ((ContactUIModel) -> Void)?
    var onSelectMultiple: (([SelectedContactUIModel]) -> Void)?

    init(
        isMultiSelect: Bool = false,
        totalAmount: Int64 = 300_000,
        initialSelected: [SelectedContactUIModel] = [],
        onSelectSingle: ((ContactUIModel) -> Void)? = nil,
        onSelectMultiple: (([SelectedContactUIModel]) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: DraftContactPickerViewModel(
            isMultiSelect: isMultiSelect,
            totalAmount: totalAmount,
            initialSelected: initialSelected
        ))
        self.onSelectSingle = onSelectSingle
        self.onSelectMultiple = onSelectMultiple
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // MARK: - Section Terpilih (Khusus Multi-select / Split)
                    if viewModel.isMultiSelect && !viewModel.selectedContacts.isEmpty {
                        Section("Terpilih") {
                            ForEach(viewModel.selectedContacts) { contact in
                                SplitParticipantRow(contact: contact) { newAmount in
                                    viewModel.updateCustomAmount(for: contact.id, amount: newAmount)
                                }
                            }

                            HStack {
                                Text("Total")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Text(viewModel.totalAllocatedAmount.rupiahFormatted)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // MARK: - Empty Search State / Add New Contact
                    if viewModel.hasNoResults {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Tidak menemukan kontak?")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)

                                Button {
                                    let newContact = viewModel.createNewContact(name: viewModel.searchQuery)
                                    if !viewModel.isMultiSelect {
                                        onSelectSingle?(newContact)
                                        dismiss()
                                    }
                                } label: {
                                    Text("Buat kontak baru \"\(viewModel.searchQuery)\"")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // MARK: - Section Kontak yang Pernah Dicatat
                        if !viewModel.filteredRecentContacts.isEmpty {
                            Section("Kontak yang pernah di catat") {
                                ForEach(viewModel.filteredRecentContacts) { contact in
                                    contactRow(contact: contact)
                                }
                            }
                        }

                        // MARK: - Section Kontak yang Kamu Simpan
                        if !viewModel.filteredDeviceContacts.isEmpty {
                            Section("Kontak yang kamu simpan") {
                                ForEach(viewModel.filteredDeviceContacts) { contact in
                                    contactRow(contact: contact)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if viewModel.isMultiSelect {
                            onSelectMultiple?(viewModel.selectedContacts)
                        } else if let first = viewModel.selectedContacts.first {
                            let match = ContactUIModel(id: first.id, fullName: first.name)
                            onSelectSingle?(match)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contactRow(contact: ContactUIModel) -> some View {
        let selected = viewModel.isSelected(contactID: contact.id)

        Button {
            viewModel.toggleSelection(for: contact)
            if !viewModel.isMultiSelect {
                onSelectSingle?(contact)
                dismiss()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)

                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AppColors.textPrimary : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Single Select") {
    DraftContactPickerSheet(isMultiSelect: false)
}

#Preview("Multi Select") {
    DraftContactPickerSheet(isMultiSelect: true, totalAmount: 300_000)
}
