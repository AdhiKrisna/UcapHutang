import Foundation
import Observation

@Observable
final class PersonLedgerDetailViewModel {
    private(set) var person: PersonLedgerSummary
    private(set) var entries: [LedgerEntry]
    var selectedFilter: DetailFilter = .all
    var showingPayment: Bool = false

    private let repository: any TransactionRepository

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        self.person = person
        self.entries = entries
        self.repository = repository
    }

    var filteredEntries: [LedgerEntry] {
        entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .piutang:
                return entry.kind == .charge && entry.balanceDelta > 0
            case .utang:
                return entry.kind == .charge && entry.balanceDelta < 0
            case .bayar:
                return entry.kind == .payment
            }
        }
    }

    /// The `sms:` URL the View opens with `openURL`. ViewModels never call UIKit directly.
    var reminderMessageURL: URL? {
        let text = "Halo \(person.displayName), mengingatkan kembali ada catatan saldo \(abs(person.balance).rupiahFormatted) di UcapHutang ya."
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "sms:&body=\(encoded)")
    }

    func reload() async {
        guard let allEntries = try? await repository.ledgerEntries() else { return }
        let currentEntries = allEntries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
        let latestName = currentEntries.first?.personName ?? person.displayName
        entries = currentEntries
        person = PersonLedgerSummary(
            id: person.id,
            displayName: latestName,
            balance: currentEntries.reduce(Int64(0)) { $0 + $1.balanceDelta },
            entryCount: currentEntries.count,
            lastActivity: currentEntries.first?.date ?? person.lastActivity,
            contactIdentifier: currentEntries.lazy.compactMap(\.contactIdentifier).first
        )
    }
}
