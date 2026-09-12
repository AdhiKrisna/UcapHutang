import Foundation
import SwiftData

/// Current SwiftData models. App code refers to them through the typealiases in `PersistenceModels.swift`.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SDTransactionParticipant.self, SDTransactionDraft.self, SDLedgerEntry.self]
    }

    @Model
    final class SDTransactionParticipant {
        @Attribute(.unique) var id: UUID
        var name: String
        var contactIdentifier: String?
        var shareAmount: Int64
        var itemTitle: String?
        var notes: String?

        init(
            id: UUID = UUID(),
            name: String,
            contactIdentifier: String? = nil,
            shareAmount: Int64 = 0,
            itemTitle: String? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.name = name
            self.contactIdentifier = contactIdentifier
            self.shareAmount = shareAmount
            self.itemTitle = itemTitle
            self.notes = notes
        }
    }

    @Model
    final class SDTransactionDraft {
        @Attribute(.unique) var id: UUID
        var statusRaw: String
        var flowRaw: String
        var typeRaw: String
        var transactionDate: Date
        var title: String
        var totalAmount: Int64
        var splitMethodRaw: String?
        var includesUser: Bool = true
        var notes: String?
        var rawTranscript: String
        var rawModelResponse: String?
        var reviewWarningsRaw: [String]
        var createdAt: Date

        @Relationship(deleteRule: .cascade)
        var participants: [SDTransactionParticipant]

        init(
            id: UUID = UUID(),
            statusRaw: String = "needsReview",
            flowRaw: String = "personal",
            typeRaw: String = "hutang",
            transactionDate: Date = Date(),
            title: String = "",
            totalAmount: Int64 = 0,
            splitMethodRaw: String? = nil,
            includesUser: Bool = true,
            notes: String? = nil,
            rawTranscript: String = "",
            rawModelResponse: String? = nil,
            reviewWarningsRaw: [String] = [],
            createdAt: Date = Date(),
            participants: [SDTransactionParticipant] = []
        ) {
            self.id = id
            self.statusRaw = statusRaw
            self.flowRaw = flowRaw
            self.typeRaw = typeRaw
            self.transactionDate = transactionDate
            self.title = title
            self.totalAmount = totalAmount
            self.splitMethodRaw = splitMethodRaw
            self.includesUser = includesUser
            self.notes = notes
            self.rawTranscript = rawTranscript
            self.rawModelResponse = rawModelResponse
            self.reviewWarningsRaw = reviewWarningsRaw
            self.createdAt = createdAt
            self.participants = participants
        }
    }

    @Model
    final class SDLedgerEntry {
        @Attribute(.unique) var id: UUID
        var personID: String
        var personName: String
        var kindRaw: String
        var balanceDelta: Int64
        var date: Date
        var title: String
        var notes: String?
        var sourceDraftID: UUID?
        var contactIdentifier: String? = nil

        init(
            id: UUID = UUID(),
            personID: String,
            personName: String,
            kindRaw: String,
            balanceDelta: Int64,
            date: Date = Date(),
            title: String,
            notes: String? = nil,
            sourceDraftID: UUID? = nil,
            contactIdentifier: String? = nil
        ) {
            self.id = id
            self.personID = personID
            self.personName = personName
            self.kindRaw = kindRaw
            self.balanceDelta = balanceDelta
            self.date = date
            self.title = title
            self.notes = notes
            self.sourceDraftID = sourceDraftID
            self.contactIdentifier = contactIdentifier
        }
    }
}
