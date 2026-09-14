import Foundation
import Observation

@Observable
final class PersonLedgerDetailViewModel {
    private(set) var person: PersonLedgerSummary
    private(set) var entries: [LedgerEntry]
    var selectedFilter: DetailFilter = .all
    var showingPayment: Bool = false
    var isShowingContactPicker = false
    var pendingMerge: ContactRef?
    var alert: RiwayatAlert?

    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(
        person: PersonLedgerSummary,
        entries: [LedgerEntry],
        repository: any TransactionRepository,
        contacts: any ContactsProviding
    ) {
        self.person = person
        self.entries = entries
        self.repository = repository
        self.contacts = contacts
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

    /// Payments and reminders require a contact link (the repository enforces payments too).
    var canRecordPaymentOrRemind: Bool {
        person.isLinked
    }

    /// Drives the merge confirmation dialog.
    var isConfirmingMerge: Bool {
        get { pendingMerge != nil }
        set { if !newValue { pendingMerge = nil } }
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

    // MARK: - Contact linking

    func requestLink() async {
        switch await contacts.access() {
        case .authorized:
            isShowingContactPicker = true
        case .denied:
            alert = .contactsAccessRequired
        case .notDetermined:
            if await contacts.requestAccess() == .authorized {
                isShowingContactPicker = true
            } else {
                alert = .contactsAccessRequired
            }
        }
    }

    /// Links right away, or asks for merge confirmation when the contact already has its own history.
    func handlePicked(_ contact: ContactRef) async {
        let allEntries = (try? await repository.ledgerEntries()) ?? []
        let contactHasOwnHistory = allEntries.contains {
            $0.personID == contact.identifier && $0.personID != person.id
        }
        if contactHasOwnHistory {
            pendingMerge = contact
        } else {
            await link(to: contact)
        }
    }

    func confirmMerge() async {
        guard let contact = pendingMerge else { return }
        pendingMerge = nil
        await link(to: contact)
    }

    func cancelMerge() {
        pendingMerge = nil
    }

    private func link(to contact: ContactRef) async {
        do {
            try await repository.linkPerson(personID: person.id, to: contact)
            person = PersonLedgerSummary(
                id: contact.identifier,
                displayName: contact.displayName,
                balance: person.balance,
                entryCount: person.entryCount,
                lastActivity: person.lastActivity,
                contactIdentifier: contact.identifier
            )
            await reload()
        } catch {
            alert = .linkFailed(message: error.localizedDescription)
        }
    }
}
