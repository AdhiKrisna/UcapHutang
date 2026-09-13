import Foundation
import Observation

@Observable
final class ReviewContactPickerViewModel {
    let allowsMultipleSelection: Bool
    var searchQuery: String
    private(set) var recentContacts: [ContactRef] = []
    private(set) var deviceContacts: [ContactRef] = []
    private(set) var selectedContacts: [ContactRef] = []
    private let initialQuery: String

    private let contacts: any ContactsProviding
    private let repository: any TransactionRepository

    init(
        allowsMultipleSelection: Bool,
        initialQuery: String,
        contacts: any ContactsProviding,
        repository: any TransactionRepository
    ) {
        self.allowsMultipleSelection = allowsMultipleSelection
        self.searchQuery = initialQuery
        self.initialQuery = initialQuery
        self.contacts = contacts
        self.repository = repository
    }

    var filteredRecentContacts: [ContactRef] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recentContacts }
        return recentContacts.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var hasNoResults: Bool {
        filteredRecentContacts.isEmpty && deviceContacts.isEmpty
    }

    /// Name used to prefill the system "New Contact" form.
    var newContactName: String {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? initialQuery.trimmingCharacters(in: .whitespacesAndNewlines) : query
    }

    /// Loads contacts that already have Riwayat history.
    func load() async {
        let identifiers = (try? await repository.linkedContactIdentifiers()) ?? []
        recentContacts = await contacts.contacts(withIdentifiers: identifiers)
    }

    /// Refreshes "Kontak di iPhone" for the current query (blank query → all contacts A–Z).
    func search() async {
        deviceContacts = await contacts.search(name: searchQuery)
    }

    func toggle(_ contact: ContactRef) {
        if let index = selectedContacts.firstIndex(of: contact) {
            selectedContacts.remove(at: index)
        } else {
            selectedContacts.append(contact)
        }
    }

    func isSelected(_ contact: ContactRef) -> Bool {
        selectedContacts.contains(contact)
    }

    /// Returns `true` when the sheet should hand `contact` back and close.
    /// In multiple selection the new contact is selected and shown, and the sheet stays open.
    func didCreateContact(_ contact: ContactRef) async -> Bool {
        guard allowsMultipleSelection else { return true }
        if !selectedContacts.contains(contact) {
            selectedContacts.append(contact)
        }
        searchQuery = contact.displayName
        await search()
        return false
    }
}
