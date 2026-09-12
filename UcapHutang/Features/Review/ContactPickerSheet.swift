import SwiftUI
import Combine

struct ContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let targetName: String
    let onSelect: (ContactMatchCandidate) -> Void
    let onKeepRaw: () -> Void

    @State private var query = ""
    @State private var candidates: [ContactMatchCandidate] = []
    @State private var selectedID: String?
    @State private var isSearching = false

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
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.small) {
            Text("Tidak menemukan kontak?")
                .font(.headline)
            Button {
                onKeepRaw()
                dismiss()
            } label: {
                Text("Gunakan nama \"\(query.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                    .underline()
            }
            .foregroundStyle(AppColors.accent)
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
        guard !isSearching else { return }
        isSearching = true
        let result = await ContactResolutionService.shared.searchContacts(query: term)
        await MainActor.run {
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
}
