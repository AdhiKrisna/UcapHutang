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
