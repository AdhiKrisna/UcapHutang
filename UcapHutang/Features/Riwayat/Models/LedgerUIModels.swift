import Foundation

// MARK: - Filter Enums
enum LedgerFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case receivable = "Berutang ke kamu"
    case debt = "Kamu berutang"

    var id: String { rawValue }
}

enum DetailFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Semua"
    case piutang = "Piutang"
    case utang = "Utang"
    case bayar = "Bayar"

    var id: String { rawValue }
}

// MARK: - Alerts
enum RiwayatAlert: Identifiable, Equatable {
    case contactsAccessRequired
    case linkFailed(message: String)

    var id: String {
        switch self {
        case .contactsAccessRequired: return "contacts-access"
        case .linkFailed: return "link-failed"
        }
    }

    var title: String {
        switch self {
        case .contactsAccessRequired: return "Akses Kontak Diperlukan"
        case .linkFailed: return "Belum Bisa Menghubungkan"
        }
    }

    var message: String {
        switch self {
        case .contactsAccessRequired:
            return "UcapHutang perlu akses penuh ke Kontak agar setiap catatan terhubung ke orang yang tepat."
        case .linkFailed(let message):
            return message
        }
    }
}
