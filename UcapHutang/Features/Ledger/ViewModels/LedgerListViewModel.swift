import SwiftUI
import Combine

@MainActor
protocol LedgerListViewModelProtocol: ObservableObject {
    var summaries: [PersonLedgerSummary] { get }
    var filter: LedgerFilter { get set }
    var searchQuery: String { get set }
    var totalReceivable: Int64 { get }
    var receivableCount: Int { get }
    var totalDebt: Int64 { get }
    var debtCount: Int { get }
    var filteredSummaries: [PersonLedgerSummary] { get }
    var errorMessage: String? { get set }

    func load() async
    func entries(for person: PersonLedgerSummary) -> [LedgerEntry]
}

@MainActor
final class LedgerListViewModel: ObservableObject, LedgerListViewModelProtocol {
    @Published private(set) var summaries: [PersonLedgerSummary] = []
    @Published private(set) var entries: [LedgerEntry] = []
    @Published var filter: LedgerFilter = .all
    @Published var searchQuery: String = ""
    @Published var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
    }

    var totalReceivable: Int64 {
        summaries.filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
    }

    var receivableCount: Int {
        summaries.filter { $0.balance > 0 }.count
    }

    var totalDebt: Int64 {
        abs(summaries.filter { $0.balance < 0 }.reduce(0) { $0 + $1.balance })
    }

    var debtCount: Int {
        summaries.filter { $0.balance < 0 }.count
    }

    var filteredSummaries: [PersonLedgerSummary] {
        summaries.filter { person in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .receivable:
                matchesFilter = person.balance > 0
            case .debt:
                matchesFilter = person.balance < 0
            }

            let matchesSearch: Bool
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = person.displayName.localizedCaseInsensitiveContains(searchQuery)
            }

            return matchesFilter && matchesSearch
        }
    }

    func load() async {
        do {
            entries = try await repository.ledgerEntries()
            summaries = Self.summarize(entries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func entries(for person: PersonLedgerSummary) -> [LedgerEntry] {
        entries.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
    }

    private static func summarize(_ entries: [LedgerEntry]) -> [PersonLedgerSummary] {
        Dictionary(grouping: entries, by: \.personID).compactMap { id, values in
            guard let latest = values.max(by: { $0.date < $1.date }) else { return nil }
            return PersonLedgerSummary(
                id: id,
                displayName: latest.personName,
                balance: values.reduce(0) { $0 + $1.balanceDelta },
                entryCount: values.count,
                lastActivity: latest.date
            )
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }
}
