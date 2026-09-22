import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    let person: PersonLedgerSummary
    let repository: any TransactionRepository
    let onSaved: () -> Void

    @FocusState private var isAmountFocused: Bool
    @State private var amount: Int64 = 0
    @State private var date = Date()
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Pembayaran dilakukan di luar aplikasi. UcapHutang hanya mencatat pelunasan.", systemImage: "info.circle")
                }
                Section("Pembayaran") {
                    TextField("Nominal", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .focused($isAmountFocused)
                    DatePicker("Tanggal & Waktu", selection: $date)
                    TextField("Catatan (opsional)", text: $notes)
                }
                Section {
                    Button {
                        save()
                    } label: {
                        Text("Simpan Log Bayar")
                            .font(.headline)
                            .foregroundStyle(AppColors.background)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.primary)
                    .disabled(amount <= 0 || amount > abs(person.balance) || isSaving)
                }
            }
            .navigationTitle("Catat Pembayaran")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                isAmountFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
            .alert("Tidak Dapat Menyimpan", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Terjadi kesalahan.")
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await repository.recordPayment(for: person, amount: amount, date: date, notes: notes.isEmpty ? nil : notes)
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
