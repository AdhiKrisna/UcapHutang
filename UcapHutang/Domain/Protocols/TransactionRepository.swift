import Foundation

extension Notification.Name {
    static let transactionRepositoryDidChange = Notification.Name("transactionRepositoryDidChange")
}

protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func pendingDraftCount() async throws -> Int
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    /// Permanently deletes the draft and its participants. Unknown IDs are ignored.
    func deleteDraft(id: UUID) async throws
    func confirmDraft(_ draft: TransactionDraft) async throws
    func ledgerEntries() async throws -> [LedgerEntry]
    /// Distinct, sorted contact identifiers that already have ledger history.
    func linkedContactIdentifiers() async throws -> [String]
    /// Moves every entry of `personID` (and every entry already under the contact) to the contact identity.
    func linkPerson(personID: String, to contact: ContactRef) async throws
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount
    case paymentExceedsBalance
    case noOutstandingBalance
    case personNotLinked
    case personNotFound

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Nominal harus lebih dari nol."
        case .paymentExceedsBalance: "Pembayaran tidak boleh melewati saldo saat ini."
        case .noOutstandingBalance: "Saldo orang ini sudah lunas atau tidak lagi tersedia. Muat ulang Riwayat."
        case .personNotLinked: "Hubungkan orang ini ke kontak sebelum mencatat pembayaran."
        case .personNotFound: "Orang ini tidak ditemukan di Riwayat. Muat ulang Riwayat."
        }
    }
}
