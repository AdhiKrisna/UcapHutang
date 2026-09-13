import SwiftUI
import Combine
import Contacts
import ContactsUI

struct ContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let targetName: String
    let onSelect: (ContactMatchCandidate) -> Void

    @State private var query = ""
    @State private var candidates: [ContactMatchCandidate] = []
    @State private var selectedID: String?
    @State private var isSearching = false
    @State private var isCreatingContact = false
    @State private var createdContact: ContactMatchCandidate?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        if candidates.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            emptyState
                        } else {
                            contactSection(
                                title: "Kontak yang pernah di catat",
                                contacts: candidates
                            )
                            contactSection(
                                title: "Kontak yang kamu simpan",
                                contacts: candidates
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.top, AppSpacing.medium)
                }

                if !candidates.isEmpty {
                    createContactAction
                }
                searchBar
            }
            .background(AppColors.background)
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmSelection()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(selectedID == nil ? AppColors.textSecondary : .white)
                            .frame(width: 34, height: 34)
                            .background(selectedID == nil ? AppColors.surface : AppColors.accent)
                            .clipShape(Circle())
                    }
                    .disabled(selectedID == nil)
                }
            }
            .task {
                query = targetName
                await search(targetName)
            }
            .onChange(of: query) { _, newValue in
                Task { await search(newValue) }
            }
            .sheet(isPresented: $isCreatingContact, onDismiss: finishContactCreation) {
                NativeContactCreationView(suggestedName: creationName) { candidate in
                    createdContact = candidate
                    isCreatingContact = false
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("Tidak menemukan kontak?")
                .font(.headline)
            Text("Kamu tetap bisa membuat kontak baru dari nama yang sedang dicari.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                isCreatingContact = true
            } label: {
                Label("Buat Kontak", systemImage: "person.crop.circle.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, AppSpacing.large)
                    .frame(minHeight: 44)
                    .background(AppColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxLarge)
    }

    private func contactSection(title: String, contacts: [ContactMatchCandidate]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            if contacts.isEmpty {
                Text("Belum ada kontak yang cocok.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(contacts) { candidate in
                    Button {
                        selectedID = candidate.id
                    } label: {
                        HStack(spacing: AppSpacing.medium) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.fullName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                if let phone = candidate.phoneNumber {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            Spacer()
                            Image(systemName: selectedID == candidate.id ? "circle.inset.filled" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedID == candidate.id ? AppColors.accent : AppColors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var createContactAction: some View {
        Button {
            isCreatingContact = true
        } label: {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Buat Kontak Baru")
                    .fontWeight(.semibold)
                Spacer()
                Text(creationName)
                    .lineLimit(1)
                    .foregroundStyle(AppColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .font(.subheadline)
            .foregroundStyle(AppColors.accent)
            .padding(.horizontal, AppSpacing.large)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AppColors.surface)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppColors.border)
        }
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(height: 46)
        .background(AppColors.surface)
        .clipShape(Capsule())
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
    }

    private func search(_ term: String) async {
        isSearching = true
        let result = await ContactResolutionService.shared.searchContacts(query: term)
        await MainActor.run {
            guard query == term else { return }
            candidates = result
            isSearching = false
            if selectedID != nil && !result.contains(where: { $0.id == selectedID }) {
                selectedID = nil
            }
        }
    }

    private func confirmSelection() {
        guard let selectedID,
              let selected = candidates.first(where: { $0.id == selectedID }) else { return }
        onSelect(selected)
        dismiss()
    }

    private func finishContactCreation() {
        guard let createdContact else { return }
        self.createdContact = nil
        onSelect(createdContact)
        dismiss()
    }

    private var creationName: String {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanQuery.isEmpty ? targetName : cleanQuery
    }
}

private struct NativeContactCreationView: UIViewControllerRepresentable {
    let suggestedName: String
    let onComplete: (ContactMatchCandidate?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        let components = PersonNameComponentsFormatter().personNameComponents(from: suggestedName)
        contact.givenName = components?.givenName ?? suggestedName
        contact.middleName = components?.middleName ?? ""
        contact.familyName = components?.familyName ?? ""

        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: (ContactMatchCandidate?) -> Void

        init(onComplete: @escaping (ContactMatchCandidate?) -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            guard let contact else {
                onComplete(nil)
                return
            }
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            onComplete(ContactMatchCandidate(
                id: contact.identifier,
                fullName: fullName,
                phoneNumber: contact.phoneNumbers.first?.value.stringValue,
                email: contact.emailAddresses.first?.value as String?
            ))
        }
    }
}
