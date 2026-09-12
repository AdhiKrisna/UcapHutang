import Foundation
import SwiftData

enum UcapHutangMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static var migrateV1toV2: MigrationStage {
        MigrationStage.custom(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                try UcapHutangMigrationPlan.applyV2DataRules(in: context)
            }
        )
    }

    /// V1 → V2 data rules (spec §6.5):
    /// 1. Permanently delete drafts that were soft-deleted ("discarded"), including their participants.
    /// 2. Backfill `SDLedgerEntry.contactIdentifier`: a `personID` counts as linked when it equals
    ///    the `contactIdentifier` of any remaining stored participant.
    static func applyV2DataRules(in context: ModelContext) throws {
        let discarded = "discarded"
        let discardedDrafts = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == discarded }
        ))
        for draft in discardedDrafts {
            for participant in draft.participants {
                context.delete(participant)
            }
        }
        try context.save()
        for draft in discardedDrafts {
            context.delete(draft)
        }
        try context.save()

        let participants = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionParticipant>())
        let linkedIdentifiers = Set(participants.compactMap(\.contactIdentifier))

        let entries = try context.fetch(FetchDescriptor<SchemaV2.SDLedgerEntry>())
        for entry in entries {
            entry.contactIdentifier = linkedIdentifiers.contains(entry.personID) ? entry.personID : nil
        }
        try context.save()
    }
}
