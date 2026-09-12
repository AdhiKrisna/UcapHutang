import SwiftUI

struct ReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewDetailViewModel
    @State private var isShowingDatePicker = false

    init(
        draftID: UUID = UUID(),
        repository: (any TransactionRepository)? = nil,
        initialType: TransactionType = .hutang,
        initialNominal: Int64 = 150_000,
        initialDescription: String = "Pinjam buat makan siang",
        initialParticipants: [ReviewParticipantUIModel]? = nil
    ) {
        _viewModel = State(initialValue: ReviewDetailViewModel(
            draftID: draftID,
            repository: repository,
            initialType: initialType,
            initialNominal: initialNominal,
            initialDescription: initialDescription,
            initialParticipants: initialParticipants
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Waktu
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Waktu")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Button {
                            isShowingDatePicker.toggle()
                        } label: {
                            HStack {
                                Text(viewModel.timeText)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if isShowingDatePicker {
                            DatePicker(
                                "",
                                selection: $viewModel.transactionDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .onChange(of: viewModel.transactionDate) { _, newDate in
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: "id_ID")
                                formatter.dateFormat = "d MMM, HH:mm"
                                viewModel.timeText = "Hari ini, " + formatter.string(from: newDate)
                            }
                        }
                    }

                    // MARK: - Nominal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nominal")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Text(viewModel.formattedNominal)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    // MARK: - Deskripsi
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deskripsi")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        TextField("Deskripsi transaksi", text: $viewModel.description)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    // MARK: - Jenis (Segmented Control)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Jenis")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        Picker("Jenis", selection: Binding(
                            get: { viewModel.transactionType },
                            set: { viewModel.setTransactionType($0) }
                        )) {
                            Text("Utang").tag(TransactionType.hutang)
                            Text("Piutang").tag(TransactionType.piutang)
                        }
                        .pickerStyle(.segmented)
                    }

                    // MARK: - Orang (Smart Contact Cards)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Orang")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        ForEach(viewModel.participants) { participant in
                            SmartContactCardView(
                                participant: participant,
                                onConfirmTypo: {
                                    viewModel.confirmTypo(for: participant.id)
                                },
                                onRejectTypo: {
                                    viewModel.rejectTypo(for: participant.id)
                                },
                                onOpenPicker: {
                                    viewModel.openContactPicker(for: participant.id)
                                }
                            )
                        }

                        // Tombol Tambah Orang (Outlined / Dotted)
                        Button {
                            viewModel.addParticipant()
                        } label: {
                            HStack {
                                Spacer()
                                Text("+ Tambah orang")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundStyle(Color.secondary.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)

                    // MARK: - Action Buttons (Bottom)
                    VStack(spacing: 12) {
                        Button {
                            Task { await viewModel.saveDraft() }
                        } label: {
                            Text("Simpan Catatan")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.primary)
                                .foregroundStyle(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Text("Hapus catatan ini")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Review Catatan")
            .navigationBarTitleDisplayMode(.inline)
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
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished {
                    dismiss()
                }
            }
            .sheet(item: Binding<IdentifiableUUID?>(
                get: { viewModel.activeContactPickerParticipantID.map { IdentifiableUUID($0) } },
                set: { viewModel.activeContactPickerParticipantID = $0?.id }
            )) { identifiable in
                ReviewContactPickerSheet(
                    isMultiSelect: false,
                    onSelectSingle: { selected in
                        viewModel.updateParticipantContact(id: identifiable.id, contact: selected)
                    }
                )
            }
            .confirmationDialog("Hapus catatan ini?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
                Button("Hapus Catatan", role: .destructive) {
                    Task { await viewModel.deleteDraft() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Draf transaksi ini akan dihapus permanen.")
            }
        }
    }
}

#Preview("Review - Connected") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito",
                linkState: .autoLinked(matchedContactName: "Andito Rizkika")
            )
        ]
    )
}

#Preview("Review - Typo Suggestion") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .typoSuggestion(suggestedName: "Dito Rizkika", originalName: "Dito Rizkaka")
            )
        ]
    )
}

#Preview("Review - Unlinked") {
    ReviewDetailView(
        initialType: .hutang,
        initialNominal: 150_000,
        initialDescription: "Pinjam buat makan siang",
        initialParticipants: [
            ReviewParticipantUIModel(
                name: "Dito Rizkaka",
                linkState: .unlinked
            )
        ]
    )
}
