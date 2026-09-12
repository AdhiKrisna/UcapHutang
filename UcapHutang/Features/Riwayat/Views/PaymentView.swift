import SwiftUI

struct PaymentView: View {
    let person: PersonLedgerSummary
    let repository: any TransactionRepository
    let onSaved: () -> Void

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
                    TextField("Nominal", value: $amount, format: .number).keyboardType(.numberPad)
                    DatePicker("Tanggal & Waktu", selection: $date)
                    TextField("Catatan (opsional)", text: $notes)
                }
                Section {
                    Button("Simpan Log Bayar") { save() }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(amount <= 0 || amount > abs(person.balance) || isSaving)
                }
            }
            .navigationTitle("Catat Pembayaran")
            .alert("Tidak Dapat Menyimpan", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Terjadi kesalahan.") }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer {
                Task { @MainActor in isSaving = false }
            }
            do {
                try await repository.recordPayment(for: person, amount: amount, date: date, notes: notes.isEmpty ? nil : notes)
                await MainActor.run { onSaved() }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
