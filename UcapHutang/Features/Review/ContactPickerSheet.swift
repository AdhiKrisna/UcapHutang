import SwiftUI
import Combine

struct ContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let targetName: String
    let onSelect: (ContactMatchCandidate) -> Void
    let onKeepRaw: () -> Void

    @State private var query: String = ""
    @State private var candidates: [ContactMatchCandidate] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onKeepRaw()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .foregroundStyle(AppColors.accent)
                            VStack(alignment: .leading) {
                                Text("Gunakan nama \"\(targetName)\"")
                                    .font(.headline)
                                Text("Simpan tanpa menghubungkan ke Kontak HP")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }

                Section("Hasil Pencarian Kontak") {
                    if candidates.isEmpty {
                        Text(query.isEmpty ? "Ketik nama untuk mencari di kontak HP..." : "Tidak ada kontak yang cocok.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                onSelect(candidate)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.fullName)
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                    if let phone = candidate.phoneNumber {
                                        Text(phone)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Cari nama di Kontak...")
            .onChange(of: query) { _, newQuery in
                search(newQuery)
            }
            .task {
                search(targetName)
            }
            .navigationTitle("Hubungkan Kontak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }

    private func search(_ term: String) {
        Task {
            let res = await ContactResolutionService.shared.searchContacts(query: term)
            await MainActor.run {
                self.candidates = res
            }
        }
    }
}
