import Foundation
import Observation

@Observable
final class ReviewDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case notFound
    }

    static let autosaveFailedMessage = "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."

    let draftID: UUID
    private(set) var loadState: LoadState = .loading
    private(set) var draft: TransactionDraft?
    private(set) var suggestions: [UUID: ContactRef] = [:]
    private(set) var hasAttemptedSave = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var didFinish = false
    /// True while an edit is being written back to the draft.
    private(set) var isAutosaving = false
    /// Set when the last automatic draft save failed. Shown inline, never as an alert.
    private(set) var autosaveErrorMessage: String?
    var alert: ReviewAlert?
    var pickerRequest: ContactPickerRequest?
    var isConfirmingDelete = false

    @ObservationIgnored private var savedSnapshot: TransactionDraft?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.draftID = draftID
        self.repository = repository
        self.contacts = contacts
    }

    // MARK: - Derived state

    var issues: [DraftValidationIssue] {
        guard let draft else { return [] }
        return DraftValidator.issues(for: draft)
    }

    var isDirty: Bool {
        draft != savedSnapshot
    }

    var isCustomSplit: Bool {
        guard let draft, draft.flow == .splitBill else { return false }
        return (draft.splitMethod ?? .equal) == .custom
    }

    var friendsTotal: Int64 {
        SplitCalculationEngine.customTotal(draft?.participants.map(\.shareAmount) ?? []) ?? 0
    }

    var userShare: Int64 {
        guard let draft, draft.flow == .splitBill, !isCustomSplit, draft.includesUser else { return 0 }
        return max(0, draft.totalAmount - friendsTotal)
    }

    func cardState(for participant: TransactionParticipant) -> ContactCardState {
        if Self.isLinked(participant), let identifier = participant.contactIdentifier {
            return .linked(ContactRef(identifier: identifier, displayName: participant.name, phoneNumber: nil))
        }
        if let suggestion = suggestions[participant.id] {
            return .suggestion(suggestion)
        }
        return .unlinked
    }

    func showsRequiredMarker(for participantID: UUID) -> Bool {
        hasAttemptedSave && issues.contains(.participantNotLinked(participantID: participantID))
    }

    // MARK: - Loading

    func load() async {
        do {
            guard var loaded = try await repository.draft(id: draftID) else {
                loadState = .notFound
                return
            }
            Self.recalculate(&loaded)
            draft = loaded
            savedSnapshot = loaded
            loadState = .loaded
            await refreshSuggestions()
        } catch {
            loadState = .notFound
        }
    }

    // MARK: - Field edits

    func setTransactionDate(_ date: Date) {
        mutate { $0.transactionDate = date }
    }

    func setTotalAmount(_ amount: Int64) {
        guard !isCustomSplit else { return }
        mutate { $0.totalAmount = max(0, amount) }
    }

    func setTitle(_ title: String) {
        mutate { $0.title = title }
    }

    func setType(_ type: TransactionType) {
        mutate { $0.type = type }
    }

    func setSplitMethod(_ method: SplitMethod) {
        mutate { $0.splitMethod = method }
    }

    func setIncludesUser(_ includesUser: Bool) {
        mutate { $0.includesUser = includesUser }
    }

    func setShare(participantID: UUID, amount: Int64) {
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].shareAmount = max(0, amount)
        }
    }

    func removeParticipant(id: UUID) {
        mutate { draft in
            guard draft.flow == .splitBill else { return }
            draft.participants.removeAll { $0.id == id }
        }
        suggestions[id] = nil
    }

    // MARK: - Contacts

    func requestPicker(_ request: ContactPickerRequest) async {
        switch await contacts.access() {
        case .authorized:
            pickerRequest = request
        case .denied:
            alert = .contactsAccessRequired
        case .notDetermined:
            if await contacts.requestAccess() == .authorized {
                pickerRequest = request
                await refreshSuggestions()
            } else {
                alert = .contactsAccessRequired
            }
        }
    }

    func confirmSuggestion(participantID: UUID) {
        guard let contact = suggestions[participantID] else { return }
        link(participantID: participantID, to: contact)
    }

    func handlePicked(_ picked: [ContactRef], for request: ContactPickerRequest) {
        switch request {
        case .link(let participantID, _):
            guard let contact = picked.first else { return }
            link(participantID: participantID, to: contact)
        case .addParticipants:
            addParticipants(picked)
        }
    }

    // MARK: - Save / delete / close

    func save() async {
        guard !isSaving, draft != nil else { return }
        isSaving = true
        defer { isSaving = false }
        hasAttemptedSave = true
        await flushPendingEdits()
        guard let current = draft else { return }
        let currentIssues = DraftValidator.issues(for: current)
        guard currentIssues.isEmpty else {
            alert = .incomplete(messages: Self.distinctMessages(currentIssues))
            return
        }
        do {
            try await repository.confirmDraft(current)
            savedSnapshot = current
            didSave = true
            didFinish = true
        } catch {
            alert = .saveFailed(message: error.localizedDescription)
        }
    }

    func delete() async {
        await awaitPendingAutosave()
        do {
            try await repository.deleteDraft(id: draftID)
            didFinish = true
        } catch {
            alert = .deleteFailed(message: error.localizedDescription)
        }
    }

    /// Waits for queued automatic saves, then writes any edit that is still unsaved. Never confirms.
    /// Called when the screen disappears.
    func flushPendingEdits() async {
        await awaitPendingAutosave()
        await persistIfDirty()
    }

    /// Waits until every queued automatic save has finished.
    func awaitPendingAutosave() async {
        await autosaveTask?.value
    }

    // MARK: - Split math

    static func recalculate(_ draft: inout TransactionDraft) {
        switch draft.flow {
        case .personal:
            for index in draft.participants.indices {
                draft.participants[index].shareAmount = draft.totalAmount
            }
        case .splitBill:
            if (draft.splitMethod ?? .equal) == .custom {
                if let total = SplitCalculationEngine.customTotal(draft.participants.map(\.shareAmount)) {
                    draft.totalAmount = total
                }
            } else {
                let shares = SplitCalculationEngine.shares(
                    total: draft.totalAmount,
                    friendCount: draft.participants.count,
                    includesUser: draft.includesUser
                )
                for (index, share) in shares.enumerated() {
                    draft.participants[index].shareAmount = share
                }
            }
        }
    }

    // MARK: - Private

    private func mutate(_ change: (inout TransactionDraft) -> Void) {
        guard var updated = draft else { return }
        change(&updated)
        Self.recalculate(&updated)
        draft = updated
        scheduleAutosave()
    }

    /// Queues a save after any save already in flight, so writes never overlap.
    private func scheduleAutosave() {
        let previous = autosaveTask
        autosaveTask = Task { [weak self] in
            await previous?.value
            await self?.persistIfDirty()
        }
    }

    private func persistIfDirty() async {
        guard !didFinish, loadState == .loaded, let current = draft, current != savedSnapshot else { return }
        isAutosaving = true
        defer { isAutosaving = false }
        do {
            try await repository.saveDraft(current)
            savedSnapshot = current
            autosaveErrorMessage = nil
        } catch {
            autosaveErrorMessage = Self.autosaveFailedMessage
        }
    }

    private func link(participantID: UUID, to contact: ContactRef) {
        guard let current = draft else { return }
        let usedByAnother = current.participants.contains {
            $0.id != participantID && $0.contactIdentifier == contact.identifier
        }
        guard !usedByAnother else {
            alert = .duplicateContact
            return
        }
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].name = contact.displayName
            draft.participants[index].contactIdentifier = contact.identifier
        }
        suggestions[participantID] = nil
    }

    private func addParticipants(_ picked: [ContactRef]) {
        guard let current = draft, current.flow == .splitBill else { return }
        var usedIdentifiers = Set(current.participants.compactMap(\.contactIdentifier))
        var additions: [TransactionParticipant] = []
        var foundDuplicate = false
        for contact in picked {
            guard !usedIdentifiers.contains(contact.identifier) else {
                foundDuplicate = true
                continue
            }
            usedIdentifiers.insert(contact.identifier)
            additions.append(TransactionParticipant(
                name: contact.displayName,
                contactIdentifier: contact.identifier,
                shareAmount: 0
            ))
        }
        mutate { $0.participants.append(contentsOf: additions) }
        if foundDuplicate {
            alert = .duplicateContact
        }
    }

    private func refreshSuggestions() async {
        guard let current = draft, await contacts.access() == .authorized else {
            suggestions = [:]
            return
        }
        var result: [UUID: ContactRef] = [:]
        for participant in current.participants where !Self.isLinked(participant) {
            let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let matches = await contacts.search(name: name)
            if matches.count == 1 {
                result[participant.id] = matches[0]
            }
        }
        suggestions = result
    }

    private static func isLinked(_ participant: TransactionParticipant) -> Bool {
        let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !identifier.isEmpty
    }

    private static func distinctMessages(_ issues: [DraftValidationIssue]) -> [String] {
        var seen = Set<String>()
        return issues.map(\.message).filter { seen.insert($0).inserted }
    }
}
