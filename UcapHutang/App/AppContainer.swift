import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extraction: any DraftExtracting
    let capture: any VoiceCapturing
    let contacts: any ContactsProviding
    let router: AppRouter
    let makeSpeechTranscriber: @MainActor () -> any SpeechTranscribing
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extraction: any DraftExtracting,
        contacts: any ContactsProviding,
        router: AppRouter = AppRouter(),
        makeSpeechTranscriber: @escaping @MainActor () -> any SpeechTranscribing = { SpeechRecognizer() },
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extraction = extraction
        self.capture = VoiceCapturePipeline(extraction: extraction, repository: repository)
        self.contacts = contacts
        self.router = router
        self.makeSpeechTranscriber = makeSpeechTranscriber
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let contacts = SystemContactsProvider()
        let extraction = QwenDraftExtractionService(llmClient: MLXQwenClient())
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UcapHutangMigrationPlan.self,
                configurations: config
            )
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            return AppContainer(repository: repo, extraction: extraction, contacts: contacts)
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            // SwiftData has no migration-specific error type. If a store file already exists,
            // the failure happened while opening/migrating existing data.
            let storeExists = FileManager.default.fileExists(atPath: config.url.path)
            let message = storeExists
                ? "Migrasi data ke versi terbaru gagal. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
                : "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extraction: extraction,
                contacts: contacts,
                storageErrorMessage: message
            )
        }
    }
}
