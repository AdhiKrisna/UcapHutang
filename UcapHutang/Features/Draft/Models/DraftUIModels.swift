import Foundation

// MARK: - Filter Enum
enum DraftFilterType: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case hutang = "Utang"
    case piutang = "Piutang"
    case split = "Split"

    var id: String { rawValue }
}

// MARK: - Smart Contact Linking State
enum ContactLinkState: Equatable, Sendable {
    /// Terhubung langsung tanpa keraguan
    case autoLinked(matchedContactName: String)
    /// AI mendeteksi kemiripan nama / potensi typo
    case typoSuggestion(suggestedName: String, originalName: String)
    /// Belum terhubung ke kontak manapun
    case unlinked

    var statusText: String {
        switch self {
        case .autoLinked:
            return "Terhubung otomatis ke kontak"
        case .typoSuggestion(let suggestedName, _):
            return "Mirip kontak \"\(suggestedName)\" — Typo?"
        case .unlinked:
            return "Belum terhubung"
        }
    }
}

// MARK: - Draft Item UI Model
struct DraftItemUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var type: TransactionType
    var prefix: String // "ke" atau "dari"
    var personName: String // "Dito", "Krisna", "3 Orang"
    var avatarInitials: [String] // ["E", "C", "D"] untuk split bill
    var description: String
    var relativeTime: String
    var amount: Int64
    var date: Date

    init(
        id: UUID = UUID(),
        type: TransactionType,
        prefix: String = "",
        personName: String,
        avatarInitials: [String] = [],
        description: String,
        relativeTime: String,
        amount: Int64,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.prefix = prefix
        self.personName = personName
        self.avatarInitials = avatarInitials
        self.description = description
        self.relativeTime = relativeTime
        self.amount = amount
        self.date = date
    }
}

// MARK: - Draft Participant UI Model
struct DraftParticipantUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var shareAmount: Int64
    var linkState: ContactLinkState
    var contactIdentifier: String?
    var phoneNumber: String?

    init(
        id: UUID = UUID(),
        name: String,
        shareAmount: Int64 = 0,
        linkState: ContactLinkState = .unlinked,
        contactIdentifier: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.id = id
        self.name = name
        self.shareAmount = shareAmount
        self.linkState = linkState
        self.contactIdentifier = contactIdentifier
        self.phoneNumber = phoneNumber
    }
}

// MARK: - Contact Picker UI Models
struct ContactUIModel: Identifiable, Equatable, Sendable {
    let id: String
    var fullName: String
    var phoneNumber: String?
    var isFromHistory: Bool

    init(
        id: String = UUID().uuidString,
        fullName: String,
        phoneNumber: String? = nil,
        isFromHistory: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.isFromHistory = isFromHistory
    }
}

struct SelectedContactUIModel: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var amount: Int64
    var isCustomAmount: Bool

    init(
        id: String,
        name: String,
        amount: Int64 = 0,
        isCustomAmount: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isCustomAmount = isCustomAmount
    }
}

// MARK: - Mock / Preview Data
enum DraftMockData {
    static let sampleDrafts: [DraftItemUIModel] = [
        DraftItemUIModel(
            type: .piutang,
            prefix: "ke",
            personName: "Dito",
            description: "“pinjam buat makan siang”",
            relativeTime: "5 menit lalu",
            amount: 15_000
        ),
        DraftItemUIModel(
            type: .hutang,
            prefix: "dari",
            personName: "Krisna",
            description: "“buat bayar kost”",
            relativeTime: "5 menit lalu",
            amount: 500_000
        ),
        DraftItemUIModel(
            type: .splitBill,
            prefix: "ke",
            personName: "3 Orang",
            avatarInitials: ["E", "C", "D"],
            description: "“makan malam, bagi rata”",
            relativeTime: "5 menit lalu",
            amount: 300_000
        )
    ]

    static let sampleHistoryContacts: [ContactUIModel] = [
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: true),
        ContactUIModel(fullName: "Andito Rizkika", phoneNumber: "+62 81234123123", isFromHistory: true)
    ]

    static let sampleDeviceContacts: [ContactUIModel] = [
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: false),
        ContactUIModel(fullName: "Budi Santoso", phoneNumber: "+62 81234123123", isFromHistory: false),
        ContactUIModel(fullName: "Andito Rizkika", phoneNumber: "+62 81234123123", isFromHistory: false)
    ]
}
