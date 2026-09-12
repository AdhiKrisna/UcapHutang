import SwiftUI
import Combine

@MainActor
protocol DraftListViewModelProtocol: ObservableObject {
    var drafts: [DraftItemUIModel] { get }
    var selectedFilter: DraftFilterType { get set }
    var filteredDrafts: [DraftItemUIModel] { get }
    var isEmpty: Bool { get }
    var errorMessage: String? { get set }

    func loadDrafts() async
    func selectFilter(_ filter: DraftFilterType)
    func deleteDraft(id: UUID) async
}

@MainActor
final class DraftListViewModel: ObservableObject, DraftListViewModelProtocol {
    @Published private(set) var drafts: [DraftItemUIModel] = []
    @Published var selectedFilter: DraftFilterType = .all
    @Published var errorMessage: String?

    private let repository: (any TransactionRepository)?

    init(repository: (any TransactionRepository)? = nil, previewDrafts: [DraftItemUIModel]? = nil) {
        self.repository = repository
        if let previewDrafts {
            self.drafts = previewDrafts
        } else if repository == nil {
            // Default mock data untuk slicing & preview
            self.drafts = DraftMockData.sampleDrafts
        }
    }

    var filteredDrafts: [DraftItemUIModel] {
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

    func selectFilter(_ filter: DraftFilterType) {
        selectedFilter = filter
    }

    func loadDrafts() async {
        guard let repository else {
            // Jika dalam mode standalone/slicing preview tanpa repo
            if drafts.isEmpty {
                drafts = DraftMockData.sampleDrafts
            }
            return
        }

        do {
            let entityDrafts = try await repository.draftsNeedingReview()
            self.drafts = entityDrafts.map { entity in
                let prefix: String
                let personName: String
                var avatarInitials: [String] = []

                if entity.flow == .splitBill || entity.type == .splitBill {
                    prefix = "ke"
                    personName = "\(max(1, entity.participants.count)) Orang"
                    avatarInitials = entity.participants.prefix(3).map { participant in
                        let trimmed = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        return String(trimmed.prefix(1)).uppercased()
                    }
                    if avatarInitials.isEmpty {
                        avatarInitials = ["E", "C", "D"]
                    }
                } else if entity.type == .piutang {
                    prefix = "ke"
                    personName = entity.participants.first?.name ?? "Teman"
                } else {
                    prefix = "dari"
                    personName = entity.participants.first?.name ?? "Teman"
                }

                let desc = entity.notes?.isEmpty == false ? "“\(entity.notes!)”" : "“\(entity.title)”"

                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                formatter.locale = Locale(identifier: "id_ID")
                let relTime = formatter.localizedString(for: entity.createdAt, relativeTo: Date())

                return DraftItemUIModel(
                    id: entity.id,
                    type: entity.type,
                    prefix: prefix,
                    personName: personName,
                    avatarInitials: avatarInitials,
                    description: desc,
                    relativeTime: relTime.isEmpty ? "5 menit lalu" : relTime,
                    amount: entity.totalAmount,
                    date: entity.transactionDate
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteDraft(id: UUID) async {
        if let repository {
            try? await repository.discardDraft(id: id)
        }
        drafts.removeAll { $0.id == id }
    }
}
