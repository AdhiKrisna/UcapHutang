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

    /// SF Symbol shown on the flow-chooser tile.
    var icon: String {
        switch self {
        case .personal: "person.2"
        case .splitBill: "person.3.fill"
        }
    }

    /// The recording screen's subtitle, directly under the flow title.
    var subtitle: String {
        switch self {
        case .personal: "Catat utang atau piutang personal dengan satu orang"
        case .splitBill: "Catat patungan/bagi rata makan atau belanja bareng"
        }
    }

    /// Baked into the chooser tile, and shown as the recording screen's "Contoh Ucapan".
    var exampleUcapan: String {
        switch self {
        case .personal: "Dito pinjam 50 ribu buat beli bensin"
        case .splitBill: "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
        }
    }

    var speechExamples: [String] {
        switch self {
        case .personal:
            [
                "Aku pinjam 50 ribu dari Dito buat beli bensin",
                "Dito pinjam 50 ribu buat beli bensin"
            ]
        case .splitBill:
            [exampleUcapan]
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
    /// Split Bill + equal method only: whether the user also takes a share.
    var includesUser: Bool = true
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
    /// `nil` for legacy people that were saved before contact linking became mandatory.
    var contactIdentifier: String?
}

struct PersonLedgerSummary: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var balance: Int64
    var entryCount: Int
    var lastActivity: Date
    var contactIdentifier: String?

    var isLinked: Bool { contactIdentifier != nil }
}
