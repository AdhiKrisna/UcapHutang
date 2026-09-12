import Foundation

struct QwenDraftExtractionService: DraftExtracting {
    private let llmClient: (any LLMClientProtocol)?

    init(llmClient: (any LLMClientProtocol)? = nil) {
        self.llmClient = llmClient
    }

    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw DraftExtractionError.extractionFailed("Transkrip kosong.")
        }

        var warnings: [String] = []
        var rawResponse: String?
        if let llmClient {
            let request = DraftExtractionRequest(flow: flow, transcript: cleanTranscript, referenceDate: referenceDate)
            do {
                rawResponse = try await llmClient.generate(prompt: QwenPromptBuilder.prompt(for: request))
            } catch {
                warnings.append(error.localizedDescription)
            }
        }

        let output: CaptureOutput
        if let rawResponse {
            do {
                output = try QwenOutputDecoder.decode(rawResponse, for: flow, transcript: cleanTranscript)
            } catch {
                warnings.append(error.localizedDescription)
                output = try QwenOutputDecoder.decode("{}", for: flow, transcript: cleanTranscript)
            }
        } else {
            output = try QwenOutputDecoder.decode("{}", for: flow, transcript: cleanTranscript)
        }

        let temporalComponents: TransactionTemporalComponents?
        switch output {
        case .personal(let personal):
            temporalComponents = personal.transactionTime
            if let warning = personal.warning { warnings.append(warning) }
        case .split(let split):
            temporalComponents = split.transactionTime
            if let warning = split.warning { warnings.append(warning) }
        }

        let resolved = TransactionDateResolver.resolve(
            transcript: cleanTranscript,
            modelComponents: temporalComponents,
            referenceNow: referenceDate
        )
        if let warning = resolved.warning { warnings.append(warning) }

        return ExtractionResult(
            output: output,
            resolvedDate: resolved.date,
            rawModelResponse: rawResponse,
            warnings: warnings
        )
    }
}
