# Panduan Implementasi On-Device LLM (Qwen + MLX Swift) di iOS

Dokumen ini berisi panduan bertahap (step-by-step) implementasi model bahasa (LLM) lokal di perangkat iOS secara **100% offline & private** menggunakan framework **MLX Swift**, diadaptasi dari arsitektur nyata project **UcapHutang**.

---

## 📑 Daftar Isi
1. [Arsitektur & Alur Kerja](#1-arsitektur--alur-kerja)
2. [Spesifikasi & Kebutuhan Sistem](#2-spesifikasi--kebutuhan-sistem)
3. [Tahap 1: Persiapan & Unduh Model (Quantized 4-bit)](#tahap-1-persiapan--unduh-model-quantized-4-bit)
4. [Tahap 2: Konfigurasi Swift Package Manager (SPM)](#tahap-2-konfigurasi-swift-package-manager-spm)
5. [Tahap 3: Service Wrapper Client (`MLXQwenClient.swift`)](#tahap-3-service-wrapper-client-mlxqwenclientswift)
6. [Tahap 4: Chat Template & Prompt Engineering (`QwenPromptBuilder.swift`)](#tahap-4-chat-template--prompt-engineering-qwenpromptbuilderswift)
7. [Tahap 5: Output Decoder & Sanitasi JSON (`QwenOutputDecoder.swift`)](#tahap-5-output-decoder--sanitasi-json-qwenoutputdecoderswift)
8. [Tahap 6: Service Extraction Pipeline](#tahap-6-service-extraction-pipeline)
9. [Tahap 7: Integrasi ke UI SwiftUI](#tahap-7-integrasi-ke-ui-swiftui)
10. [Tips Optimasi & Troubleshooting](#tips-optimasi--troubleshooting)
11. [Checklist Implementasi](#checklist-implementasi)

---

## 1. Arsitektur & Alur Kerja

```text
[Input Teks / Suara (Transcript)]
               │
               ▼
   [1. QwenPromptBuilder]     ──► Format template ChatML (<|im_start|>) & few-shot rules
               │
               ▼
     [2. MLXQwenClient]       ──► Load model 4-bit ke GPU/RAM & eksekusi inference via MLX
               │
               ▼
   [3. QwenOutputDecoder]     ──► Sanitasi & parse output JSON string ke model Swift
               │
               ▼
 [4. SwiftData / Domain UI]   ──► Simpan ke database lokal / tampilkan di layar
```

---

## 2. Spesifikasi & Kebutuhan Sistem

- **iOS Target:** iOS 17.0+ (disarankan iOS 17.4+ atau iOS 18+)
- **Bahasa:** Swift 5.9+ / Swift 6
- **Hardware:** iPhone dengan chip A14 Bionic ke atas (iPhone 12 ke atas, RAM minimal 4 GB).
- **Library:** 
  - `mlx-swift` (Apple Silicon ML Engine)
  - `mlx-swift-lm` (LLM Container & Model Factory)
  - `swift-transformers` (Tokenizer)

---

## Tahap 1: Persiapan & Unduh Model (Quantized 4-bit)

iPhone memiliki batasan alokasi memori ketat. Jangan gunakan model full precision (FP16/FP32). Gunakan **Quantized 4-bit** (ukuran ~350 MB - 600 MB untuk parameter 0.5B / 0.6B).

1. Download model MLX-ready dari Hugging Face (misal: `mlx-community/Qwen2.5-0.5B-Instruct-4bit` atau `Qwen3-0.6B-4bit`).
2. Pastikan file model lengkap berisi:
   ```text
   Qwen3-0.6B-4bit/
   ├── config.json
   ├── tokenizer.json
   ├── tokenizer_config.json
   ├── special_tokens_map.json
   └── model.safetensors
   ```
3. Masukkan folder tersebut ke dalam Xcode:
   - Tarik folder ke navigasi project: `MyApp/Resources/Models/Qwen3-0.6B-4bit/`.
   - **PENTING:** Pilih **"Create folder references"** (folder berwarna biru) dan centang target aplikasi utama pada **Target Membership**.

---

## Tahap 2: Konfigurasi Swift Package Manager (SPM)

Tambahkan package resmi melalui Xcode (**File > Add Package Dependencies...**):

1. **MLX Swift Core:**
   `https://github.com/ml-explore/mlx-swift` (versi `0.31.6` atau terbaru)
2. **MLX Swift Language Model:**
   `https://github.com/ml-explore/mlx-swift-lm` (versi `3.31.4` atau terbaru)
3. **Swift Transformers:**
   `https://github.com/huggingface/swift-transformers` (versi `1.3.4` atau terbaru)

**Link Frameworks pada App Target:**
- `MLX`
- `MLXLLM`
- `MLXLMCommon`
- `MLXHuggingFace`
- `Tokenizers`

> **Tips Kemampuan Memori:** Buka *Target > Signing & Capabilities*, tambahkan capability **Increased Memory Limit** agar iOS tidak mematikan aplikasi saat inference membutuhkan lonjakan memori.

---

## Tahap 3: Service Wrapper Client (`MLXQwenClient.swift`)

Gunakan `actor` di Swift untuk menjamin thread-safety saat model di-load dan menjalankan inference di background thread:

```swift
import Foundation
import MLX
import MLXLMCommon
import MLXLLM
import MLXHuggingFace
import Tokenizers

public actor MLXQwenClient {
    private let modelFolderName = "Qwen3-0.6B-4bit"
    private let maxTokens: Int
    private let temperature: Float
    private var modelContainer: ModelContainer?

    public init(maxTokens: Int = 180, temperature: Float = 0.0) {
        self.maxTokens = maxTokens
        self.temperature = temperature // 0.0 untuk output terstruktur/deterministik (JSON)
    }

    /// Cek lokasi model di dalam bundle aplikasi
    public static func localModelURL(bundle: Bundle = .main) throws -> URL {
        let candidates: [URL] = [
            bundle.bundleURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("Qwen3-0.6B-4bit", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Qwen3-0.6B-4bit", isDirectory: true),
            bundle.bundleURL
        ]
        
        guard let modelURL = candidates.first(where: { candidate in
            FileManager.default.fileExists(atPath: candidate.appendingPathComponent("model.safetensors").path)
        }) else {
            throw NSError(domain: "ModelNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "File model tidak ditemukan di App Bundle."])
        }
        
        return modelURL
    }

    /// Memuat model ke memori hanya saat pertama kali dipanggil (Lazy Load)
    private func loadModelIfNeeded() async throws -> ModelContainer {
        if let modelContainer { return modelContainer }
        
        let modelURL = try Self.localModelURL()
        
        // Batasi batas cache metal memory
        Memory.cacheLimit = 20 * 1024 * 1024 // 20 MB
        
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: modelURL,
            using: #huggingFaceTokenizerLoader()
        )
        self.modelContainer = loaded
        return loaded
    }

    /// Menjalankan inference teks
    public func generate(prompt: String) async throws -> String {
        let container = try await loadModelIfNeeded()
        
        var parameters = GenerateParameters()
        parameters.maxTokens = maxTokens
        parameters.temperature = temperature

        let tokenizer = await container.tokenizer
        let tokens = tokenizer.encode(text: prompt)
        let input = LMInput(tokens: MLXArray(tokens))
        
        let stream = try await container.generate(input: input, parameters: parameters)

        var outputText = ""
        for await generation in stream {
            try Task.checkCancellation()
            if let chunk = generation.chunk {
                outputText += chunk
                // Guard: Cegah looping tak terhingga jika token stop terlewat
                if outputText.utf8.count > 32_768 { break }
            }
        }
        
        let result = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw NSError(domain: "EmptyOutput", code: 500, userInfo: [NSLocalizedDescriptionKey: "Model menghasilkan output kosong."])
        }
        
        return result
    }
}
```

---

## Tahap 4: Chat Template & Prompt Engineering (`QwenPromptBuilder.swift`)

Model seri Qwen menggunakan format template **ChatML** (`<|im_start|>system...<|im_end|>`). 

```swift
import Foundation

enum QwenPromptBuilder {
    static func prompt(for transcript: String) -> String {
        let systemRules = """
        You are a semantic parser for informal personal finance and debt records.
        Return ONLY valid JSON with keys: direction, person, amount, title.
        Schema: {"direction":"hutang|piutang|unknown","person":null,"amount":null,"title":null}
        Rules:
        - direction "hutang" means the speaker owes money / borrowed from someone.
        - direction "piutang" means someone owes money to the speaker / speaker lent money.
        - person is only the counterparty person's name (exclude merchants/places/verbs).
        - amount is integer Rupiah only.
        - Never guess ambiguous values, use null.
        - Return JSON ONLY without extra explanation. /no_think

        Examples:
        User: Aku ngutang 20000 untuk beli kopi ke Budi
        Assistant: {"direction":"hutang","person":"Budi","amount":20000,"title":"beli kopi"}
        User: Gua talangin Adit 18k untuk bayar kopi susu
        Assistant: {"direction":"piutang","person":"Adit","amount":18000,"title":"kopi susu"}
        """

        return """
        <|im_start|>system
        \(systemRules)<|im_end|>
        <|im_start|>user
        \(transcript)<|im_end|>
        <|im_start|>assistant
        <think>
        </think>
        
        """
    }
}
```

---

## Tahap 5: Output Decoder & Sanitasi JSON (`QwenOutputDecoder.swift`)

Model on-device kecil terkadang menyertakan markdown block seperti ````json ... ```` atau trailing characters. Buat decoder yang toleran:

```swift
import Foundation

public struct ExtractedTransaction: Codable, Sendable {
    public let direction: String?
    public let person: String?
    public let amount: Int64?
    public let title: String?
}

public enum QwenOutputDecoder {
    public static func decode(_ rawResponse: String) throws -> ExtractedTransaction {
        var cleaned = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Ekstrak bagian dalam kurung kurawal terluar { ... }
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            cleaned = String(cleaned[start.lowerBound...end.upperBound])
        }
        
        // 2. Decode ke struktur Swift
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "DecoderError", code: 422, userInfo: [NSLocalizedDescriptionKey: "Gagal membaca format data hasil ekstraksi."])
        }
        
        return try JSONDecoder().decode(ExtractedTransaction.self, from: data)
    }
}
```

---

## Tahap 6: Service Extraction Pipeline

Satukan Client, Prompt Builder, dan Decoder ke dalam satu service layer yang bersih:

```swift
import Foundation

public protocol DraftExtracting: Sendable {
    func extract(transcript: String) async throws -> ExtractedTransaction
}

public final class QwenDraftExtractionService: DraftExtracting {
    private let llmClient: MLXQwenClient

    public init(llmClient: MLXQwenClient = MLXQwenClient()) {
        self.llmClient = llmClient
    }

    public func extract(transcript: String) async throws -> ExtractedTransaction {
        let cleanText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw NSError(domain: "ExtractionError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Transkrip ucapan kosong."])
        }

        // 1. Bangun prompt ChatML
        let prompt = QwenPromptBuilder.prompt(for: cleanText)

        // 2. Eksekusi inference
        let rawResponse = try await llmClient.generate(prompt: prompt)

        // 3. Decode hasil JSON
        return try QwenOutputDecoder.decode(rawResponse)
    }
}
```

---

## Tahap 7: Integrasi ke UI SwiftUI

Panggil pipeline dari ViewModel menggunakan Swift Concurrency (`@Observable`) agar UI tetap responsif:

```swift
import SwiftUI
import Observation

@Observable
final class CatatViewModel {
    var liveTranscript: String = ""
    var isProcessing: Bool = false
    var extractedData: ExtractedTransaction?
    var errorMessage: String?

    private let extractionService: any DraftExtracting

    init(extractionService: any DraftExtracting = QwenDraftExtractionService()) {
        self.extractionService = extractionService
    }

    func processAudio(transcript: String) {
        self.liveTranscript = transcript
        self.isProcessing = true
        self.errorMessage = nil

        Task {
            do {
                let result = try await extractionService.extract(transcript: transcript)
                await MainActor.run {
                    self.extractedData = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

struct CatatView: View {
    @State private var viewModel = CatatViewModel()

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isProcessing {
                ProgressView("Menganalisis teks dengan AI lokal...")
            } else if let data = viewModel.extractedData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hasil Ekstraksi AI:").font(.headline)
                    Text("Tipe: \(data.direction ?? "-")")
                    Text("Orang: \(data.person ?? "-")")
                    Text("Nominal: Rp \(data.amount ?? 0)")
                    Text("Deskripsi: \(data.title ?? "-")")
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            Button("Simulasi Rekam Suara") {
                viewModel.processAudio(transcript: "Kemarin nalangin Budi 50 ribu beli bensin")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
        }
        .padding()
    }
}
```

---

## 💡 Tips Optimasi & Troubleshooting

1. **Tes di iPhone Fisik (Real Device):**
   - iOS Simulator berjalan via CPU emulasi, sehingga inference LLM akan terasa lambat (3–10 token/detik).
   - Di iPhone fisik (Apple Silicon A14/A15/A16/A17/A18), Metal GPU & Neural Engine akan menjalankan inference sangat cepat (30–60+ token/detik).
2. **Gunakan `temperature: 0.0`:**
   - Parameter suhu nol memastikan model menghasilkan format JSON yang konsisten dan deterministik.
3. **Manajemen Memori (`Memory.cacheLimit`):**
   - Selalu atur batas cache (`Memory.cacheLimit = 20 * 1024 * 1024`) setelah inisialisasi container untuk mencegah retensi memori Metal yang berlebihan.
4. **Ukuran File Model:**
   - Gunakan model **0.5B / 0.6B** untuk task ekstraksi entitas atau parsing sederhana agar binary size aplikasi tetap di bawah 600 MB.

---

## ✅ Checklist Implementasi

- [ ] Folder model 4-bit (`.safetensors`, `config.json`, tokenizer) ditambahkan ke project Xcode sebagai *Folder Reference* (warna biru).
- [ ] SPM dependencies (`mlx-swift`, `mlx-swift-lm`, `swift-transformers`) terpasang.
- [ ] Capability **Increased Memory Limit** ditambahkan ke App Target.
- [ ] Service inference dibungkus dalam `actor` untuk eksekusi non-blocking.
- [ ] ChatML prompt builder diterapkan (`<|im_start|>system...`).
- [ ] Decoder JSON memiliki toleransi pembersihan string regex / kurung kurawal.
- [ ] Pengujian diverifikasi langsung pada iPhone fisik.
