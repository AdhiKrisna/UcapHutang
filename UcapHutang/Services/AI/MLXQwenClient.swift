import Foundation
import MLX
import MLXLMCommon
import MLXLLM
import MLXHuggingFace
import HuggingFace
import Tokenizers

enum MLXQwenClientError: LocalizedError {
    case modelDirectoryMissing(String)
    case requiredFileMissing(String)
    case modelLoadFailed(String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .modelDirectoryMissing(let path):
            return "Model Qwen belum ditemukan di aplikasi. Pastikan folder Qwen3-0.6B-4bit terpasang di Resources/Models. Lokasi yang dicari: \(path)"
        case .requiredFileMissing(let file):
            return "Model Qwen belum lengkap karena file \(file) tidak ditemukan. Pasang ulang model dari GitHub Release."
        case .modelLoadFailed(let reason):
            return "Model Qwen tidak dapat dimuat: \(reason)"
        case .emptyOutput:
            return "Model Qwen tidak menghasilkan data. Ucapan tetap disimpan sebagai draft agar bisa kamu lengkapi."
        }
    }
}

enum LocalModelReadiness: Equatable {
    case ready
    case missing(String)

    var title: String {
        switch self {
        case .ready: "Model AI siap"
        case .missing: "Model AI belum siap"
        }
    }

    var detail: String {
        switch self {
        case .ready: "Pemrosesan ucapan dilakukan secara lokal di perangkat."
        case .missing(let reason): reason
        }
    }
}

actor MLXQwenClient: LLMClientProtocol {
    static let modelFolderName = "Qwen3-0.6B-4bit"
    private let maxTokens: Int
    private let temperature: Float
    private var modelContainer: ModelContainer?

    init(maxTokens: Int = 180, temperature: Float = 0) {
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    nonisolated static func readiness(bundle: Bundle = .main) -> LocalModelReadiness {
        do {
            _ = try localModelURL(bundle: bundle)
            return .ready
        } catch {
            return .missing(error.localizedDescription)
        }
    }

    func generate(prompt: String) async throws -> String {
        let container = try await loadModelIfNeeded()
        var parameters = GenerateParameters()
        parameters.maxTokens = maxTokens
        parameters.temperature = temperature

        let tokenizer = await container.tokenizer
        let tokens = tokenizer.encode(text: prompt)
        let input = LMInput(tokens: MLXArray(tokens))
        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await generation in stream {
            try Task.checkCancellation()
            if let chunk = generation.chunk {
                output += chunk
                if output.utf8.count > 32_768 { break }
            }
        }
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MLXQwenClientError.emptyOutput
        }
        return output
    }

    private func loadModelIfNeeded() async throws -> ModelContainer {
        if let modelContainer { return modelContainer }
        let modelURL = try Self.localModelURL()
        do {
            Memory.cacheLimit = 20 * 1024 * 1024
            let loaded = try await LLMModelFactory.shared.loadContainer(
                from: modelURL,
                using: #huggingFaceTokenizerLoader()
            )
            modelContainer = loaded
            return loaded
        } catch {
            throw MLXQwenClientError.modelLoadFailed(error.localizedDescription)
        }
    }

    static func localModelURL(bundle: Bundle = .main) throws -> URL {
        let candidates: [URL] = [
            bundle.bundleURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent(modelFolderName, isDirectory: true),
            bundle.bundleURL.appendingPathComponent(modelFolderName, isDirectory: true),
            bundle.bundleURL
        ]
        guard let modelURL = candidates.first(where: { candidate in
            FileManager.default.fileExists(
                atPath: candidate.appendingPathComponent("model.safetensors").path
            )
        }) else {
            throw MLXQwenClientError.modelDirectoryMissing(candidates[0].path)
        }
        for filename in ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"] {
            let fileURL = modelURL.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw MLXQwenClientError.requiredFileMissing(filename)
            }
        }
        return modelURL
    }
}
