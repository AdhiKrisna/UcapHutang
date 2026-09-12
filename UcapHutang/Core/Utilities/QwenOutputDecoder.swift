import Foundation

enum PersonalDirection: String, Codable, Equatable, Sendable {
    case hutang, piutang, unknown
}

struct PersonalCaptureOutput: Codable, Equatable, Sendable {
    let direction: PersonalDirection
    let person: String?
    let amount: Int64?
    let title: String?

    var warning: String? {
        var missing: [String] = []
        if direction == .unknown { missing.append("arah hutang/piutang") }
        if person?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { missing.append("nama orang") }
        if amount == nil || amount! <= 0 { missing.append("nominal") }
        if title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { missing.append("judul") }
        return missing.isEmpty ? nil : "Perlu dilengkapi: " + missing.joined(separator: ", ")
    }
}

enum SplitBasis: String, Codable, Equatable, Sendable {
    case equal, custom, unknown
}

struct SplitReceivable: Codable, Equatable, Sendable {
    let person: String
    let item: String?
    let amount: Int64?
}

struct SplitCaptureOutput: Codable, Equatable, Sendable {
    private static let maximumSupportedAmount: Int64 = 1_000_000_000_000_000
    let basis: SplitBasis
    let title: String?
    let totalAmount: Int64?
    let splitCount: Int?
    let includesUser: Bool?
    let receivables: [SplitReceivable]

    enum CodingKeys: String, CodingKey {
        case basis, title, receivables
        case totalAmount = "total_amount"
        case splitCount = "split_count"
        case includesUser = "includes_user"
    }

    var effectiveTotalAmount: Int64? {
        if let totalAmount, totalAmount > 0, totalAmount <= Self.maximumSupportedAmount { return totalAmount }
        guard basis == .custom, receivables.allSatisfy({ ($0.amount ?? 0) > 0 }) else { return nil }
        var total: Int64 = 0
        for amount in receivables.compactMap(\.amount) {
            let (next, overflow) = total.addingReportingOverflow(amount)
            guard !overflow, next <= Self.maximumSupportedAmount else { return nil }
            total = next
        }
        return total
    }

    var warning: String? {
        var missing: [String] = []
        if basis == .unknown { missing.append("cara pembagian") }
        if title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { missing.append("judul") }
        if effectiveTotalAmount == nil || effectiveTotalAmount! <= 0 { missing.append("total") }
        if splitCount == nil || splitCount! < 2 { missing.append("jumlah orang") }
        if includesUser != true { missing.append("pengguna sebagai peserta") }
        if receivables.isEmpty { missing.append("tagihan teman") }
        return missing.isEmpty ? nil : "Perlu dilengkapi: " + missing.joined(separator: ", ")
    }
}

enum CaptureOutput: Equatable, Sendable {
    case personal(PersonalCaptureOutput)
    case split(SplitCaptureOutput)
}

enum CaptureOutputError: LocalizedError {
    case missingJSONObject
    case invalidSchema(String)

    var errorDescription: String? {
        switch self {
        case .missingJSONObject: "Output model tidak berisi objek JSON."
        case .invalidSchema(let reason): "Output model tidak sesuai: \(reason)"
        }
    }
}

enum QwenOutputDecoder {
    private static let maximumSupportedAmount: Int64 = 1_000_000_000_000_000

    static func decode(_ text: String, for flow: CaptureFlow, transcript: String? = nil) throws -> CaptureOutput {
        switch flow {
        case .personal: return .personal(try decodePersonal(text, transcript: transcript))
        case .splitBill: return .split(try decodeSplit(text, transcript: transcript))
        }
    }

    static func decodePersonal(_ text: String, transcript: String? = nil) throws -> PersonalCaptureOutput {
        let object = (try? jsonObject(in: text)) ?? [:]

        let directionRaw = object["direction"] as? String
        let direction = PersonalDirection(rawValue: directionRaw ?? "") ?? .unknown
        let rawPerson = object["person"] as? String
        let rawAmount = (object["amount"] as? NSNumber)?.int64Value
        let rawTitle = object["title"] as? String

        guard let transcript else {
            return PersonalCaptureOutput(direction: direction, person: rawPerson, amount: rawAmount, title: rawTitle)
        }

        let groundedAmount = extractAmount(from: transcript) ?? rawAmount
        let resolvedDirection = determinePersonalDirection(transcript: transcript, defaultDirection: direction)
        let resolvedPerson = extractPersonName(from: transcript, modelPerson: rawPerson)
        let resolvedTitle = extractTitle(from: transcript, modelTitle: rawTitle)

        return PersonalCaptureOutput(
            direction: resolvedDirection,
            person: resolvedPerson,
            amount: groundedAmount,
            title: resolvedTitle
        )
    }

    static func decodeSplit(_ text: String, transcript: String? = nil) throws -> SplitCaptureOutput {
        let parsedObject = (try? jsonObject(in: text)) ?? [:]

        let rawBasisStr = parsedObject["basis"] as? String
        let basis: SplitBasis = {
            if let rawBasisStr, let b = SplitBasis(rawValue: rawBasisStr) {
                return b
            }
            return .equal
        }()

        let rawTitle = parsedObject["title"] as? String
        let rawTotal = (parsedObject["total_amount"] as? NSNumber)?.int64Value
        let rawSplitCount = (parsedObject["split_count"] as? NSNumber)?.intValue

        var rawReceivables: [SplitReceivable] = []
        if let recList = parsedObject["receivables"] as? [[String: Any]] {
            for rec in recList {
                if let p = rec["person"] as? String {
                    let item = rec["item"] as? String
                    let amount = (rec["amount"] as? NSNumber)?.int64Value
                    rawReceivables.append(SplitReceivable(person: p, item: item, amount: amount))
                }
            }
        }

        guard let transcript else {
            return SplitCaptureOutput(
                basis: basis,
                title: rawTitle,
                totalAmount: rawTotal,
                splitCount: rawSplitCount ?? (rawReceivables.count + 1),
                includesUser: true,
                receivables: rawReceivables
            )
        }

        let groundedTotal = extractAmount(from: transcript) ?? rawTotal
        let names = extractSplitParticipants(from: transcript, modelNames: rawReceivables.map(\.person))

        var receivables: [SplitReceivable] = []
        if !rawReceivables.isEmpty {
            receivables = rawReceivables
        } else {
            receivables = names.map { SplitReceivable(person: $0, item: nil, amount: nil) }
        }

        let resolvedCount = max(2, receivables.count + 1, rawSplitCount ?? 0)
        let resolvedTitle = extractTitle(from: transcript, modelTitle: rawTitle)

        return SplitCaptureOutput(
            basis: basis,
            title: resolvedTitle,
            totalAmount: groundedTotal,
            splitCount: resolvedCount,
            includesUser: true,
            receivables: receivables
        )
    }

    private static func jsonObject(in text: String) throws -> [String: Any] {
        guard let first = text.firstIndex(of: "{"), let last = text.lastIndex(of: "}"), first < last else {
            throw CaptureOutputError.missingJSONObject
        }
        let jsonStr = String(text[first...last])
        guard let data = jsonStr.data(using: .utf8) else {
            throw CaptureOutputError.invalidSchema("UTF-8 encoding error")
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw CaptureOutputError.invalidSchema("Not a dictionary object")
        }
        return dict
    }

    // MARK: - Deterministic Grounding Helpers
    static func extractAmount(from text: String) -> Int64? {
        let lower = text.lowercased()
        if let jt = firstMatch(for: #"(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b"#, in: lower) {
            let clean = jt.replacingOccurrences(of: ",", with: ".")
            if let val = Double(clean) { return Int64((val * 1_000_000).rounded()) }
        }
        if let rb = firstMatch(for: #"(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)\b"#, in: lower) {
            let clean = rb.replacingOccurrences(of: ",", with: ".")
            if let val = Double(clean) { return Int64((val * 1_000).rounded()) }
        }
        if let dot = firstMatch(for: #"(?:^|[^\d.])(\d{1,3}(?:\.\d{3})+)(?![.\d])"#, in: text) {
            let clean = dot.replacingOccurrences(of: ".", with: "")
            if let val = Int64(clean) { return val }
        }
        if let raw = firstMatch(for: #"(?:^|[^\d.])(\d{4,})(?![.\d])"#, in: text) {
            if let val = Int64(raw) { return val }
        }
        return nil
    }

    static func determinePersonalDirection(transcript: String, defaultDirection: PersonalDirection) -> PersonalDirection {
        let t = transcript.lowercased()
        if t.contains("aku ngutang") || t.contains("gw ngutang") || t.contains("gue ngutang") || t.contains("aku pinjam") || t.contains("aku minjem") || t.contains("titip beli") || t.contains("nitip") {
            return .hutang
        }
        if t.contains("ngutang ke aku") || t.contains("pinjam ke aku") || t.contains("bayarin") || t.contains("nalangin") || t.contains("talangin") {
            return .piutang
        }
        return defaultDirection
    }

    static func extractPersonName(from text: String, modelPerson: String?) -> String {
        if let modelPerson, !modelPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return modelPerson.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
        if let subject = firstMatch(
            for: #"^\s*([\p{L}][\p{L}'-]*(?:\s+[\p{L}][\p{L}'-]*)?)\s+(?:ngutang|minjam|pinjam|nitip|titip)\b"#,
            in: text
        ) {
            let reserved: Set<String> = ["aku", "saya", "gue", "gw", "gua", "ane"]
            let clean = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reserved.contains(clean.lowercased()) { return clean.capitalized }
        }
        let stop: Set<String> = ["aku", "saya", "gue", "gw", "gua", "ke", "dari", "sama", "buat", "beli", "makan", "ribu", "juta"]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for (index, w) in words.enumerated() where ["ke", "dari", "sama"].contains(w.lowercased()) && index + 1 < words.count {
            let candidate = words[index + 1].trimmingCharacters(in: .punctuationCharacters)
            if !stop.contains(candidate.lowercased()) && candidate.count > 1 {
                return candidate.capitalized
            }
        }
        return ""
    }

    static func extractSplitParticipants(from text: String, modelNames: [String]) -> [String] {
        if !modelNames.isEmpty {
            return modelNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
        }
        let patterns = [
            #"\b(?:untuk|bersama|bareng|sama|dengan)\s+(.+?)(?=\s+(?:bagi\s+rata|dibagi|total(?:nya)?|seharga|senilai)\b|$)"#,
            #"\b(?:pesertanya|anggotanya)\s+(.+)$"#
        ]
        for pattern in patterns {
            guard let rawList = firstMatch(for: pattern, in: text) else { continue }
            let normalized = rawList
                .replacingOccurrences(of: ",", with: " dan ")
                .replacingOccurrences(of: #"\s+(?:dan|sama|dengan|plus)\s+"#, with: "|", options: .regularExpression)
            let names = normalized.split(separator: "|").compactMap { part -> String? in
                let clean = part
                    .replacingOccurrences(of: #"\b(?:aku|saya|gue|gw|gua|ane)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                guard clean.count > 1 else { return nil }
                return clean.capitalized
            }
            if !names.isEmpty { return Array(NSOrderedSet(array: names)) as? [String] ?? names }
        }
        return []
    }

    static func extractTitle(from text: String, modelTitle: String?) -> String {
        if let modelTitle, !modelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return modelTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let lower = text.lowercased()
        for item in ["makan", "kopi", "bensin", "tiket", "belanja", "gacoan", "ramen", "pizza"] {
            if lower.contains(item) { return item.capitalized }
        }
        return ""
    }

    private static func firstMatch(for pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > 1 else { return nil }
        let r = match.range(at: 1)
        return r.location != NSNotFound ? nsString.substring(with: r) : nil
    }
}
