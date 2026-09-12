import Foundation
import Observation

@Observable
final class ReviewDetailViewModel {
    let draftID: UUID
    var timeText: String = "Hari ini, 12:41"
    var transactionDate: Date = Date()
    var nominal: Int64 = 150_000
    var description: String = "Pinjam buat makan siang"
    var transactionType: TransactionType = .hutang
    var participants: [ReviewParticipantUIModel] = []
    var isSaving: Bool = false
    var didFinish: Bool = false
    var errorMessage: String?
    var showDeleteConfirmation: Bool = false
    var activeContactPickerParticipantID: UUID?

    private let repository: (any TransactionRepository)?

    init(
        draftID: UUID = UUID(),
        repository: (any TransactionRepository)? = nil,
        initialType: TransactionType = .hutang,
        initialNominal: Int64 = 150_000,
        initialDescription: String = "Pinjam buat makan siang",
        initialParticipants: [ReviewParticipantUIModel]? = nil
    ) {
        self.draftID = draftID
        self.repository = repository
        self.transactionType = initialType
        self.nominal = initialNominal
        self.description = initialDescription

        if let initialParticipants {
            self.participants = initialParticipants
        } else {
            // Default mock data untuk slicing & preview: 1 orang "Dito" terhubung otomatis
            self.participants = [
                ReviewParticipantUIModel(
                    name: "Dito",
                    shareAmount: initialNominal,
                    linkState: .autoLinked(matchedContactName: "Andito Rizkika"),
                    contactIdentifier: "1",
                    phoneNumber: "+62 81234123123"
                )
            ]
        }
    }

    var formattedNominal: String {
        nominal.rupiahFormatted
    }

    func setTransactionType(_ type: TransactionType) {
        self.transactionType = type
    }

    func confirmTypo(for participantID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        if case .typoSuggestion(let suggestedName, _) = participants[index].linkState {
            participants[index].name = suggestedName
            participants[index].linkState = .autoLinked(matchedContactName: suggestedName)
        }
    }

    func rejectTypo(for participantID: UUID) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        // Biarkan nama asli, set ke unlinked, dan buka modal picker
        participants[index].linkState = .unlinked
        activeContactPickerParticipantID = participantID
    }

    func openContactPicker(for participantID: UUID) {
        activeContactPickerParticipantID = participantID
    }

    func addParticipant() {
        let newParticipant = ReviewParticipantUIModel(
            name: "Orang Baru",
            shareAmount: 0,
            linkState: .unlinked
        )
        participants.append(newParticipant)
        recalculateEqualSplit()
    }

    func removeParticipant(id: UUID) {
        participants.removeAll { $0.id == id }
        recalculateEqualSplit()
    }

    func updateParticipantContact(id: UUID, contact: ContactUIModel) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        participants[index].name = contact.fullName
        participants[index].phoneNumber = contact.phoneNumber
        participants[index].contactIdentifier = contact.id
        participants[index].linkState = .autoLinked(matchedContactName: contact.fullName)
    }

    private func recalculateEqualSplit() {
        guard !participants.isEmpty, nominal > 0 else { return }
        let share = nominal / Int64(participants.count)
        for i in participants.indices {
            participants[i].shareAmount = share
        }
    }

    func saveDraft() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if let repository {
            do {
                if var loaded = try await repository.draft(id: draftID) {
                    loaded.type = transactionType
                    loaded.totalAmount = nominal
                    loaded.title = description
                    loaded.transactionDate = transactionDate
                    loaded.status = .confirmed
                    try await repository.confirmDraft(loaded)
                }
            } catch {
                self.errorMessage = error.localizedDescription
                return
            }
        }

        didFinish = true
    }

    func deleteDraft() async {
        if let repository {
            try? await repository.discardDraft(id: draftID)
        }
        didFinish = true
    }
}
