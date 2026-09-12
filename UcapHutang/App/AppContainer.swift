import Foundation
import Combine
import SwiftData

@MainActor
final class AppContainer: ObservableObject {
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

enum PreviewData {
    static let drafts: [TransactionDraft] = [
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Makan siang",
            totalAmount: 150_000,
            participants: [TransactionParticipant(name: "Dito", shareAmount: 150_000)],
            notes: "Pinjam buat makan siang",
            rawTranscript: "Dito pinjam seratus lima puluh ribu buat makan siang"
        ),
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 300_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Orang A", shareAmount: 100_000),
                TransactionParticipant(name: "Orang B", shareAmount: 100_000)
            ],
            notes: "Bagi rata termasuk saya",
            rawTranscript: "Aku bayarin makan malam bertiga sama Orang A dan Orang B total tiga ratus ribu"
        )
    ]
}
