import Foundation

extension Notification.Name {
    static let transactionRepositoryDidChange = Notification.Name("transactionRepositoryDidChange")
}

protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    func discardDraft(id: UUID) async throws
    func confirmDraft(_ draft: TransactionDraft) async throws
    func ledgerEntries() async throws -> [LedgerEntry]
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount
    case paymentExceedsBalance
    case noOutstandingBalance

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Nominal harus lebih dari nol."
        case .paymentExceedsBalance: "Pembayaran tidak boleh melewati saldo saat ini."
        case .noOutstandingBalance: "Saldo orang ini sudah lunas atau tidak lagi tersedia. Muat ulang Riwayat."
        }
    }
}
