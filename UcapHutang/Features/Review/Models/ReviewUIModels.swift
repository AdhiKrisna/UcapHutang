import Foundation

// MARK: - Filter Enum
enum ReviewFilterType: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case hutang = "Utang"
    case piutang = "Piutang"
    case split = "Split"

    var id: String { rawValue }
}

// MARK: - Review Item UI Model
struct ReviewItemUIModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var type: TransactionType
    var prefix: String // "ke" atau "dari"
    var personName: String // "Dito", "Belum ada nama", "3 Orang"
    var avatarInitials: [String]
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

// MARK: - Contact card state
enum ContactCardState: Equatable, Sendable {
    /// Not linked and no single matching contact.
    case unlinked
    /// Exactly one contact matches the name; the user must confirm.
    case suggestion(ContactRef)
    /// Linked to an iPhone contact.
    case linked(ContactRef)
}

// MARK: - Picker request
enum ContactPickerRequest: Identifiable, Hashable, Sendable {
    case link(participantID: UUID, prefill: String)
    case addParticipants

    var id: String {
        switch self {
        case .link(let participantID, _):
            return "link-\(participantID.uuidString)"
        case .addParticipants:
            return "add-participants"
        }
    }

    var allowsMultipleSelection: Bool {
        if case .addParticipants = self { return true }
        return false
    }

    var initialQuery: String {
        if case .link(_, let prefill) = self { return prefill }
        return ""
    }
}

// MARK: - Alerts
enum ReviewAlert: Identifiable, Equatable {
    case incomplete(messages: [String])
    case contactsAccessRequired
    case duplicateContact
    case saveFailed(message: String)
    case deleteFailed(message: String)

    var id: String {
        switch self {
        case .incomplete: return "incomplete"
        case .contactsAccessRequired: return "contacts-access"
        case .duplicateContact: return "duplicate-contact"
        case .saveFailed: return "save-failed"
        case .deleteFailed: return "delete-failed"
        }
    }

    var title: String {
        switch self {
        case .incomplete: return "Data Belum Lengkap"
        case .contactsAccessRequired: return "Akses Kontak Diperlukan"
        case .duplicateContact: return "Orang ini sudah ada di catatan."
        case .saveFailed: return "Data Belum Bisa Disimpan"
        case .deleteFailed: return "Catatan Belum Bisa Dihapus"
        }
    }

    var message: String? {
        switch self {
        case .incomplete(let messages):
            return messages.map { "• " + $0 }.joined(separator: "\n")
        case .contactsAccessRequired:
            return "UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat."
        case .duplicateContact:
            return nil
        case .saveFailed(let message), .deleteFailed(let message):
            return message
        }
    }
}
