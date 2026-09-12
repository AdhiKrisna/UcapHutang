import Foundation

struct DraftExtractionRequest: Sendable {
    let flow: CaptureFlow
    let transcript: String
    let referenceDate: Date

    init(flow: CaptureFlow, transcript: String, referenceDate: Date = Date()) {
        self.flow = flow
        self.transcript = transcript
        self.referenceDate = referenceDate
    }
}

protocol LLMClientProtocol: Sendable {
    func generate(prompt: String) async throws -> String
}

protocol DraftExtractionService: Sendable {
    func extract(_ request: DraftExtractionRequest) async throws -> TransactionDraft
}

enum DraftExtractionError: LocalizedError {
    case modelNotInstalled
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled: "Model Qwen belum terpasang."
        case .extractionFailed(let reason): "Ekstraksi gagal: \(reason)"
        }
    }
}

enum QwenPromptBuilder {
    static func prompt(for request: DraftExtractionRequest) -> String {
        let rules: String
        switch request.flow {
        case .personal:
            rules = """
            Extract exactly one Indonesian personal debt. The selected flow is authoritative.
            Return only JSON with keys: direction, person, amount, title, notes, transaction_time.
            direction is hutang when the user owes the person, piutang when the person owes the user, otherwise unknown.
            Preserve the person's spelling from the transcript. Use null for missing values. Never guess.
            """
        case .splitBill:
            rules = """
            Extract one user-paid Indonesian split bill. The user is always the payer and is included implicitly.
            Return only JSON with keys: basis, title, total_amount, split_count, includes_user, receivables, notes, transaction_time.
            Each receivable keeps person, item, and amount together. Use equal only when explicitly equal; otherwise custom or unknown.
            Preserve names from the transcript. Never calculate equal shares and never guess missing values.
            """
        }
        return "<|im_start|>system\n\(rules)<|im_end|>\n<|im_start|>user\n\(request.transcript)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }
}

struct HybridQwenExtractionService: DraftExtractionService {
    private let llmClient: (any LLMClientProtocol)?

    init(llmClient: (any LLMClientProtocol)? = nil) {
        self.llmClient = llmClient
    }

    func extract(_ request: DraftExtractionRequest) async throws -> TransactionDraft {
        let transcript = request.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw DraftExtractionError.extractionFailed("Transkrip kosong.")
        }

        var rawResponse: String? = nil
        var inferenceWarning: String? = nil
        if let llmClient {
            let prompt = QwenPromptBuilder.prompt(for: request)
            do {
                rawResponse = try await llmClient.generate(prompt: prompt)
            } catch {
                inferenceWarning = error.localizedDescription
            }
        }

        let captureOutput: CaptureOutput
        if let raw = rawResponse, let decoded = try? QwenOutputDecoder.decode(raw, for: request.flow, transcript: transcript) {
            captureOutput = decoded
        } else {
            captureOutput = try QwenOutputDecoder.decode("{}", for: request.flow, transcript: transcript)
        }

        let resolvedDate = TransactionDateResolver.resolve(transcript: transcript, modelComponents: nil, referenceNow: request.referenceDate)

        switch captureOutput {
        case .personal(let personal):
            let type: TransactionType = switch personal.direction {
            case .hutang: .hutang
            case .piutang: .piutang
            case .unknown: .unknown
            }
            let personName = personal.person ?? ""
            let amount = personal.amount ?? 0
            let title = personal.title ?? ""

            var warnings: [String] = []
            if let inferenceWarning { warnings.append(inferenceWarning) }
            if let w = personal.warning { warnings.append(w) }
            if let dw = resolvedDate.warning { warnings.append(dw) }

            return TransactionDraft(
                status: .needsReview,
                flow: .personal,
                type: type,
                transactionDate: resolvedDate.date,
                title: title,
                totalAmount: amount,
                splitMethod: nil,
                participants: [
                    TransactionParticipant(
                        name: personName,
                        shareAmount: amount
                    )
                ],
                notes: nil,
                rawTranscript: transcript,
                rawModelResponse: rawResponse,
                reviewWarnings: warnings,
                createdAt: request.referenceDate
            )

        case .split(let split):
            let title = split.title ?? ""
            let totalAmount = split.effectiveTotalAmount ?? (split.totalAmount ?? 0)
            let method: SplitMethod = split.basis == .custom ? .custom : .equal

            let participants = split.receivables.map { rec in
                TransactionParticipant(
                    name: rec.person,
                    shareAmount: rec.amount ?? 0,
                    itemTitle: rec.item
                )
            }

            // If equal split and amounts not set per person, calculate equal shares
            let safeParticipantCount = max(2, split.splitCount ?? (participants.count + 1))
            var finalParticipants = participants
            if method == .equal && totalAmount > 0 {
                let shares = SplitCalculationEngine.calculateEqualShares(totalAmount: totalAmount, participantCount: safeParticipantCount)
                for (idx, share) in shares.prefix(finalParticipants.count).enumerated() {
                    finalParticipants[idx].shareAmount = share
                }
            }

            var warnings: [String] = []
            if let inferenceWarning { warnings.append(inferenceWarning) }
            if let w = split.warning { warnings.append(w) }
            if let dw = resolvedDate.warning { warnings.append(dw) }

            return TransactionDraft(
                status: .needsReview,
                flow: .splitBill,
                type: .splitBill,
                transactionDate: resolvedDate.date,
                title: title,
                totalAmount: totalAmount,
                splitMethod: method,
                participants: finalParticipants,
                notes: nil,
                rawTranscript: transcript,
                rawModelResponse: rawResponse,
                reviewWarnings: warnings,
                createdAt: request.referenceDate
            )
        }
    }
}
