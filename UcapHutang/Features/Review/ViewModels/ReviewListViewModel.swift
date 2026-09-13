import Foundation
import Observation

@Observable
final class ReviewListViewModel {
    private(set) var drafts: [ReviewItemUIModel] = []
    var selectedFilter: ReviewFilterType = .all
    var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) {
        self.repository = repository
    }

    var filteredDrafts: [ReviewItemUIModel] {
        drafts.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .hutang:
                return item.type == .hutang || item.type == .unknown
            case .piutang:
                return item.type == .piutang
            case .split:
                return item.type == .splitBill
            }
        }
    }

    var isEmpty: Bool {
        filteredDrafts.isEmpty
    }

    func selectFilter(_ filter: ReviewFilterType) {
        selectedFilter = filter
    }

    func loadDrafts() async {
        do {
            let now = Date()
            drafts = try await repository.draftsNeedingReview().map { Self.makeItem(from: $0, now: now) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func makeItem(from draft: TransactionDraft, now: Date) -> ReviewItemUIModel {
        let prefix: String
        let personName: String
        var avatarInitials: [String] = []

        if draft.flow == .splitBill || draft.type == .splitBill {
            prefix = "ke"
            personName = "\(draft.participants.count) Orang"
            avatarInitials = draft.participants
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { String($0.prefix(1)).uppercased() }
        } else {
            prefix = draft.type == .piutang ? "ke" : "dari"
            let name = draft.participants.first?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            personName = name.isEmpty ? "Belum ada nama" : name
            if !name.isEmpty {
                avatarInitials = [String(name.prefix(1)).uppercased()]
            }
        }

        let notes = draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description: String
        if !notes.isEmpty {
            description = "“\(notes)”"
        } else if !title.isEmpty {
            description = "“\(title)”"
        } else {
            // No notes and no title: leave blank so the card can show a dedicated placeholder
            // instead of an empty pair of quotation marks.
            description = ""
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "id_ID")

        return ReviewItemUIModel(
            id: draft.id,
            type: draft.type,
            prefix: prefix,
            personName: personName,
            avatarInitials: avatarInitials,
            description: description,
            relativeTime: formatter.localizedString(for: draft.createdAt, relativeTo: now),
            amount: draft.totalAmount,
            date: draft.transactionDate
        )
    }
}
