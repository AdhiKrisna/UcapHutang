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
            You are a semantic parser for Indonesian informal personal debt (utang/piutang). The selected flow is authoritative: parse exactly one counterparty and one transaction.
            Return ONLY valid JSON with keys: direction, person, amount, title, notes, transaction_time.
            Schema: {"direction":"hutang|piutang|unknown","person":null,"amount":null,"title":null,"notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            Rules:
            - direction "hutang" means the speaker/user owes or borrowed from the named person.
            - direction "piutang" means the named person owes the speaker/user, or the speaker paid/lent/talangi for them.
            - person is only the other person's name. Exclude pronouns, verbs, temporal words, merchants, and items.
            - amount is integer Rupiah only. Missing or ambiguous fields must be null/unknown. Never guess.
            - title is the item/reason, not generic verbs like utang, bayar, pinjam when a specific item exists.
            - Preserve spelling from the transcript. Return JSON only. /no_think
            Examples:
            User: Aku ngutang 20000 untuk beli kopi ke kapten
            Assistant: {"direction":"hutang","person":"Kapten","amount":20000,"title":"beli kopi","notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            User: Gua talangin Adit 18k untuk bayar kopi susu
            Assistant: {"direction":"piutang","person":"Adit","amount":18000,"title":"kopi susu","notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            User: Pak Joko pinjam 2 juta buat modal usaha 15 Juli 2025
            Assistant: {"direction":"piutang","person":"Pak Joko","amount":2000000,"title":"modal usaha","notes":null,"transaction_time":{"day":15,"month":7,"year":2025,"hour":null,"minute":null}}
            """
        case .splitBill:
            rules = """
            You are a semantic parser for Indonesian informal user-paid split bill transactions. The selected flow is authoritative: the user is always the payer and is included implicitly.
            Return ONLY valid JSON with keys: basis, title, total_amount, split_count, includes_user, receivables, notes, transaction_time.
            Schema: {"basis":"equal|custom|unknown","title":null,"total_amount":null,"split_count":null,"includes_user":true,"receivables":[{"person":"...","item":null,"amount":null}],"notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            Rules:
            - Do not parse third-party-paid utterances; keep unsupported fields null/unknown instead of reversing payer.
            - receivables contains friends who owe the user. Exclude user pronouns and non-person words such as food, shops, and places.
            - Keep each person/item/amount tuple together. For equal split, leave per-person amount null; Swift will calculate shares.
            - total_amount is total bill, not a friend's share. split_count includes the user when the transcript implies it.
            - Missing or ambiguous fields must be null/unknown. Never guess. Return JSON only. /no_think
            Examples:
            User: Gua beli tiket konser nalangin Satria Arif dan Ros totalnya 800.000
            Assistant: {"basis":"equal","title":"tiket konser","total_amount":800000,"split_count":4,"includes_user":true,"receivables":[{"person":"Satria","item":null,"amount":null},{"person":"Arif","item":null,"amount":null},{"person":"Ros","item":null,"amount":null}],"notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            User: Beli McD rame-rame 180k aku bayarin, orangnya Bimo Wahyu Cindy dibagi rata
            Assistant: {"basis":"equal","title":"beli McD","total_amount":180000,"split_count":4,"includes_user":true,"receivables":[{"person":"Bimo","item":null,"amount":null},{"person":"Wahyu","item":null,"amount":null},{"person":"Cindy","item":null,"amount":null}],"notes":"dibagi rata","transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
            """
        }
        return "<|im_start|>system\n\(rules)<|im_end|>\n<|im_start|>user\n\(request.transcript)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }
}
