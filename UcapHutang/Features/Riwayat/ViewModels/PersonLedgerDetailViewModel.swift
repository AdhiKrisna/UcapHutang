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
    private(set) var reminderPhoneNumber: String?

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

    var canRecordPayment: Bool {
        person.isLinked && person.balance != 0
    }

    var canRemind: Bool {
        person.balance != 0 && reminderPhoneNumber != nil
    }

    var balanceStatusTitle: String {
        if person.balance > 0 { return "Dia berutang padamu" }
        if person.balance < 0 { return "Kamu berutang padanya" }
        return "Saldo seimbang"
    }

    var balanceStatusDetail: String {
        if person.balance > 0 { return "\(person.displayName) perlu membayarmu." }
        if person.balance < 0 { return "Kamu perlu membayar \(person.displayName)." }
        return "Tidak ada saldo tertunggak."
    }

    var paymentActionTitle: String {
        person.balance > 0 ? "Catat Bayar dari \(person.displayName)" : "Catat Bayar ke \(person.displayName)"
    }

    var paymentDirectionDetail: String {
        person.balance > 0
            ? "\(person.displayName) membayar utangnya kepadamu."
            : "Kamu membayar utangmu kepada \(person.displayName)."
    }

    /// Drives the merge confirmation dialog.
    var isConfirmingMerge: Bool {
        get { pendingMerge != nil }
        set { if !newValue { pendingMerge = nil } }
    }

    /// The `sms:` URL the View opens with `openURL`. ViewModels never call UIKit directly.
    var reminderMessageURL: URL? {
        guard canRemind, let reminderPhoneNumber else { return nil }
        let text = "Halo \(person.displayName), mengingatkan kembali ada catatan saldo \(abs(person.balance).rupiahFormatted) di UcapHutang ya."
        let recipient = reminderPhoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !recipient.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "sms"
        components.path = recipient
        components.queryItems = [URLQueryItem(name: "body", value: text)]
        return components.url
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
        await refreshReminderRecipient()
    }

    func deleteEntry(id: UUID) async {
        do {
            try await repository.deleteLedgerEntry(id: id)
            await reload()
        } catch {
            alert = .deleteFailed(message: error.localizedDescription)
        }
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

    private func refreshReminderRecipient() async {
        guard person.balance != 0, let identifier = person.contactIdentifier else {
            reminderPhoneNumber = nil
            return
        }
        reminderPhoneNumber = await contacts.contacts(withIdentifiers: [identifier]).first?.phoneNumber
    }
}
