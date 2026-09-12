import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extractionService: any DraftExtractionService
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extractionService: any DraftExtractionService,
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extractionService = extractionService
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        do {
            let schema = Schema([
                SDTransactionParticipant.self,
                SDTransactionDraft.self,
                SDLedgerEntry.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: config)
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            return AppContainer(repository: repo, extractionService: extraction)
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            let extraction = HybridQwenExtractionService(llmClient: MLXQwenClient())
            let message = "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extractionService: extraction,
                storageErrorMessage: message
            )
        }
    }
}
