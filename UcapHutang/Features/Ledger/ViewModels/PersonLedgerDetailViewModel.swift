import SwiftUI
import Combine

@MainActor
protocol PersonLedgerDetailViewModelProtocol: ObservableObject {
    var person: PersonLedgerSummary { get }
    var entries: [LedgerEntry] { get }
    var selectedFilter: DetailFilter { get set }
    var showingPayment: Bool { get set }
    var filteredEntries: [LedgerEntry] { get }

    func reload() async
    func sendReminderMessage()
}

@MainActor
final class PersonLedgerDetailViewModel: ObservableObject, PersonLedgerDetailViewModelProtocol {
    @Published private(set) var person: PersonLedgerSummary
    @Published private(set) var entries: [LedgerEntry]
    @Published var selectedFilter: DetailFilter = .all
    @Published var showingPayment: Bool = false

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
            lastActivity: currentEntries.first?.date ?? person.lastActivity
        )
    }

    func sendReminderMessage() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let amountFormatted = "Rp. " + (formatter.string(from: NSNumber(value: abs(person.balance))) ?? "\(abs(person.balance))")
        let text = "Halo \(person.displayName), mengingatkan kembali ada catatan saldo \(amountFormatted) di UcapHutang ya."

        if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "sms:&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
