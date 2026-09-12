import Foundation

enum CaptureFlow: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal
    case splitBill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Utang / Piutang"
        case .splitBill: "Split Bill"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Sendable {
    case unknown
    case hutang
    case piutang
    case splitBill

    var title: String {
        switch self {
        case .unknown: "Belum Ditentukan"
        case .hutang: "Utang"
        case .piutang: "Piutang"
        case .splitBill: "Split Bill"
        }
    }
}

enum DraftStatus: String, Codable, Sendable {
    case needsReview
    case confirmed
    case discarded
}

enum SplitMethod: String, Codable, CaseIterable, Sendable {
    case equal
    case custom

    var title: String { self == .equal ? "Bagi Rata" : "Nominal Custom" }
}

struct TransactionParticipant: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var contactIdentifier: String?
    var shareAmount: Int64
    var itemTitle: String?
    var notes: String?
}

struct TransactionDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var status: DraftStatus = .needsReview
    var flow: CaptureFlow
    var type: TransactionType
    var transactionDate: Date = Date()
    var title: String
    var totalAmount: Int64
    var splitMethod: SplitMethod?
    var participants: [TransactionParticipant]
    var notes: String?
    var rawTranscript: String
    var rawModelResponse: String?
    var reviewWarnings: [String] = []
    var createdAt: Date = Date()
}

enum LedgerEntryKind: String, Codable, Sendable {
    case charge
    case payment
}

struct LedgerEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var personID: String
    var personName: String
    var kind: LedgerEntryKind
    var balanceDelta: Int64
    var date: Date
    var title: String
    var notes: String?
    var sourceDraftID: UUID?
}

struct PersonLedgerSummary: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var balance: Int64
    var entryCount: Int
    var lastActivity: Date
}
