import Foundation

enum PersonalDirection: String, Codable, Equatable, Sendable {
    case hutang, piutang, unknown
}

struct PersonalCaptureOutput: Equatable, Sendable {
    let direction: PersonalDirection
    let person: String?
    let amount: Int64?
    let title: String?
    let notes: String?
    let transactionTime: TransactionTemporalComponents?

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

struct SplitReceivable: Equatable, Sendable {
    let person: String
    let item: String?
    let amount: Int64?
}

struct SplitCaptureOutput: Equatable, Sendable {
    private static let maximumSupportedAmount: Int64 = 1_000_000_000_000_000
    let basis: SplitBasis
    let title: String?
    let totalAmount: Int64?
    let splitCount: Int?
    let includesUser: Bool?
    let receivables: [SplitReceivable]
    let notes: String?
    let transactionTime: TransactionTemporalComponents?

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

enum CaptureOutputError: LocalizedError, Equatable {
    case missingJSONObject
    case multipleJSONObjects
    case invalidSchema(String)

    var errorDescription: String? {
        switch self {
        case .missingJSONObject: "Output model tidak berisi objek JSON."
        case .multipleJSONObjects: "Output model berisi lebih dari satu objek JSON."
        case .invalidSchema(let reason): "Output model tidak sesuai: \(reason)"
        }
    }
}

enum QwenOutputDecoder {
    private static let maximumSupportedAmount: Int64 = 1_000_000_000_000_000
    private static let maximumSplitCount = 50

    static func decode(_ text: String, for flow: CaptureFlow, transcript: String? = nil) throws -> CaptureOutput {
        switch flow {
        case .personal: return .personal(try decodePersonal(text, transcript: transcript))
        case .splitBill: return .split(try decodeSplit(text, transcript: transcript))
        }
    }

    static func decodePersonal(_ text: String, transcript: String? = nil) throws -> PersonalCaptureOutput {
        let object = try jsonObject(in: text, allowEmptyObject: true)
        try assertAllowedKeys(
            object,
            allowed: ["direction", "person", "amount", "title", "notes", "transaction_time"],
            context: "personal"
        )

        let direction = try optionalString(object["direction"], key: "direction")
            .flatMap(PersonalDirection.init(rawValue:)) ?? .unknown
        let rawPerson = try optionalString(object["person"], key: "person")
        let rawAmount = try optionalInt64(object["amount"], key: "amount", maximum: maximumSupportedAmount)
        let rawTitle = try optionalString(object["title"], key: "title")
        let notes = try optionalString(object["notes"], key: "notes")
        let temporal = try optionalTemporalComponents(object["transaction_time"])

        guard let transcript else {
            return PersonalCaptureOutput(
                direction: direction,
                person: sanitizeOptional(rawPerson),
                amount: rawAmount,
                title: sanitizeOptional(rawTitle),
                notes: sanitizeOptional(notes),
                transactionTime: temporal
            )
        }

        let groundedAmount = extractAmount(from: transcript) ?? rawAmount
        let resolvedDirection = determinePersonalDirection(transcript: transcript, defaultDirection: direction)
        let resolvedPerson = extractPersonName(from: transcript, modelPerson: rawPerson)
        let resolvedTitle = extractTitle(from: transcript, modelTitle: rawTitle)

        return PersonalCaptureOutput(
            direction: resolvedDirection,
            person: sanitizeOptional(resolvedPerson),
            amount: groundedAmount,
            title: sanitizeOptional(resolvedTitle),
            notes: sanitizeOptional(notes),
            transactionTime: temporal
        )
    }

    static func decodeSplit(_ text: String, transcript: String? = nil) throws -> SplitCaptureOutput {
        let object = try jsonObject(in: text, allowEmptyObject: true)
        try assertAllowedKeys(
            object,
            allowed: ["basis", "title", "total_amount", "split_count", "includes_user", "receivables", "notes", "transaction_time"],
            context: "split bill"
        )

        let basis = try optionalString(object["basis"], key: "basis")
            .flatMap(SplitBasis.init(rawValue:)) ?? .unknown
        let rawTitle = try optionalString(object["title"], key: "title")
        let rawTotal = try optionalInt64(object["total_amount"], key: "total_amount", maximum: maximumSupportedAmount)
        let rawSplitCount = try optionalInt(object["split_count"], key: "split_count", maximum: maximumSplitCount)
        let includesUser = try optionalBool(object["includes_user"], key: "includes_user")
        let notes = try optionalString(object["notes"], key: "notes")
        let temporal = try optionalTemporalComponents(object["transaction_time"])
        let rawReceivables = try receivables(from: object["receivables"])

        guard let transcript else {
            return SplitCaptureOutput(
                basis: basis,
                title: sanitizeOptional(rawTitle),
                totalAmount: rawTotal,
                splitCount: rawSplitCount,
                includesUser: includesUser,
                receivables: dedupeReceivables(rawReceivables),
                notes: sanitizeOptional(notes),
                transactionTime: temporal
            )
        }

        let groundedTotal = extractAmount(from: transcript) ?? rawTotal
        let resolvedReceivables: [SplitReceivable]
        if rawReceivables.isEmpty {
            resolvedReceivables = extractSplitParticipants(from: transcript, modelNames: [])
                .map { SplitReceivable(person: $0, item: nil, amount: nil) }
        } else {
            let names = extractSplitParticipants(from: transcript, modelNames: rawReceivables.map(\.person))
            if names.isEmpty {
                resolvedReceivables = rawReceivables
            } else {
                resolvedReceivables = names.map { name in
                    if let existing = rawReceivables.first(where: { normalizedName($0.person) == normalizedName(name) }) {
                        return SplitReceivable(person: name, item: existing.item, amount: existing.amount)
                    }
                    return SplitReceivable(person: name, item: nil, amount: nil)
                }
            }
        }

        let resolvedCount = rawSplitCount ?? (resolvedReceivables.isEmpty ? nil : resolvedReceivables.count + 1)
        let resolvedTitle = extractTitle(from: transcript, modelTitle: rawTitle)
        let resolvedBasis: SplitBasis = basis == .unknown && groundedTotal != nil ? .equal : basis

        return SplitCaptureOutput(
            basis: resolvedBasis,
            title: sanitizeOptional(resolvedTitle),
            totalAmount: groundedTotal,
            splitCount: resolvedCount,
            includesUser: includesUser ?? true,
            receivables: dedupeReceivables(resolvedReceivables),
            notes: sanitizeOptional(notes),
            transactionTime: temporal
        )
    }

    private static func jsonObject(in text: String, allowEmptyObject: Bool) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if allowEmptyObject, trimmed == "{}" { return [:] }
        let withoutThink = trimmed.replacingOccurrences(
            of: #"<think>[\s\S]*?</think>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        guard let range = firstJSONObjectRange(in: withoutThink) else {
            throw CaptureOutputError.missingJSONObject
        }
        let after = withoutThink[range.upperBound...]
        if firstJSONObjectRange(in: String(after)) != nil {
            throw CaptureOutputError.multipleJSONObjects
        }
        let jsonStr = String(withoutThink[range])
        guard let data = jsonStr.data(using: .utf8) else {
            throw CaptureOutputError.invalidSchema("UTF-8 encoding error")
        }
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw CaptureOutputError.invalidSchema("Top-level JSON harus object")
        }
        return dict
    }

    private static func firstJSONObjectRange(in text: String) -> Range<String.Index>? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = start
        while index < text.endIndex {
            let char = text[index]
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else if char == "\"" {
                inString = true
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return start..<text.index(after: index)
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func assertAllowedKeys(_ object: [String: Any], allowed: Set<String>, context: String) throws {
        let unknown = Set(object.keys).subtracting(allowed)
        guard unknown.isEmpty else {
            throw CaptureOutputError.invalidSchema("Key tidak dikenal pada \(context): \(unknown.sorted().joined(separator: ", "))")
        }
    }

    private static func optionalString(_ value: Any?, key: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let string = value as? String else {
            throw CaptureOutputError.invalidSchema("\(key) harus string atau null")
        }
        return string
    }

    private static func optionalBool(_ value: Any?, key: String) throws -> Bool? {
        guard let value, !(value is NSNull) else { return nil }
        guard let bool = value as? Bool else {
            throw CaptureOutputError.invalidSchema("\(key) harus boolean atau null")
        }
        return bool
    }

    private static func optionalInt(_ value: Any?, key: String, maximum: Int) throws -> Int? {
        guard let parsed = try optionalInt64(value, key: key, maximum: Int64(maximum)) else { return nil }
        guard parsed <= Int64(Int.max) else {
            throw CaptureOutputError.invalidSchema("\(key) melewati batas Int")
        }
        return Int(parsed)
    }

    private static func optionalInt64(_ value: Any?, key: String, maximum: Int64) throws -> Int64? {
        guard let value, !(value is NSNull) else { return nil }
        guard let number = value as? NSNumber else {
            throw CaptureOutputError.invalidSchema("\(key) harus integer atau null")
        }
        if String(cString: number.objCType) == "c" {
            throw CaptureOutputError.invalidSchema("\(key) tidak boleh boolean")
        }
        let double = number.doubleValue
        guard double.isFinite, double.rounded(.towardZero) == double else {
            throw CaptureOutputError.invalidSchema("\(key) tidak boleh pecahan")
        }
        let value = number.int64Value
        guard value > 0, value <= maximum else {
            throw CaptureOutputError.invalidSchema("\(key) di luar batas domain")
        }
        return value
    }

    private static func optionalTemporalComponents(_ value: Any?) throws -> TransactionTemporalComponents? {
        guard let value, !(value is NSNull) else { return nil }
        guard let object = value as? [String: Any] else {
            throw CaptureOutputError.invalidSchema("transaction_time harus object atau null")
        }
        try assertAllowedKeys(object, allowed: ["day", "month", "year", "hour", "minute"], context: "transaction_time")
        return TransactionTemporalComponents(
            day: try optionalTemporalInt(object["day"], key: "transaction_time.day", min: 1, max: 31),
            month: try optionalTemporalInt(object["month"], key: "transaction_time.month", min: 1, max: 12),
            year: try optionalTemporalInt(object["year"], key: "transaction_time.year", min: 2000, max: 2100),
            hour: try optionalTemporalInt(object["hour"], key: "transaction_time.hour", min: 0, max: 23),
            minute: try optionalTemporalInt(object["minute"], key: "transaction_time.minute", min: 0, max: 59)
        )
    }

    private static func optionalTemporalInt(_ value: Any?, key: String, min: Int, max: Int) throws -> Int? {
        guard let parsed = try optionalInt(value, key: key, maximum: max) else { return nil }
        guard parsed >= min else {
            throw CaptureOutputError.invalidSchema("\(key) di luar batas domain")
        }
        return parsed
    }

    private static func receivables(from value: Any?) throws -> [SplitReceivable] {
        guard let value, !(value is NSNull) else { return [] }
        guard let array = value as? [[String: Any]] else {
            throw CaptureOutputError.invalidSchema("receivables harus array")
        }
        return try array.map { item in
            try assertAllowedKeys(item, allowed: ["person", "item", "amount"], context: "receivable")
            guard let person = try optionalString(item["person"], key: "receivables.person"),
                  let cleanPerson = sanitizeOptional(person) else {
                throw CaptureOutputError.invalidSchema("receivables.person wajib string non-kosong")
            }
            return SplitReceivable(
                person: cleanPerson,
                item: sanitizeOptional(try optionalString(item["item"], key: "receivables.item")),
                amount: try optionalInt64(item["amount"], key: "receivables.amount", maximum: maximumSupportedAmount)
            )
        }
    }

    static func extractAmount(from text: String) -> Int64? {
        let lower = text.lowercased()
        if let billion = firstMatch(for: #"(\d+(?:[.,]\d+)?)\s*(?:m|miliar|milyar|milliar)\b"#, in: lower) {
            return scaledAmount(billion, multiplier: 1_000_000_000)
        }
        if let million = firstMatch(for: #"(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b"#, in: lower) {
            return scaledAmount(million, multiplier: 1_000_000)
        }
        if let thousand = firstMatch(for: #"(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)\b"#, in: lower) {
            return scaledAmount(thousand, multiplier: 1_000)
        }
        if let dot = firstMatch(for: #"(?:^|[^\d.])(\d{1,3}(?:\.\d{3})+)(?![.\d])"#, in: text) {
            let clean = dot.replacingOccurrences(of: ".", with: "")
            if let value = Int64(clean), value <= maximumSupportedAmount { return value }
        }
        if let raw = firstMatch(for: #"(?:^|[^\d.])(\d{4,})(?![.\d])"#, in: text) {
            if let value = Int64(raw), value <= maximumSupportedAmount { return value }
        }
        return nil
    }

    static func determinePersonalDirection(transcript: String, defaultDirection: PersonalDirection) -> PersonalDirection {
        let t = stripDiscoursePrefixes(transcript).lowercased()
        let user = #"(?:aku|saya|gue|gw|gua|ane)"#

        if matches(#"\b(?:catat\s+hutang|tolong\s+catat\s+hutang|catat\s+utang|tolong\s+catat\s+utang)\s+ke\b"#, in: t) { return .hutang }
        if matches(#"^(?:utang|ngutang|pinjam|pinjem|catat\s+utang|tolong\s+catat\s+utang|uang\s+utang|pinjam\s+saldo)\b"#, in: t) { return .hutang }
        if matches(#"\b"# + user + #"\s+(?:ngutang|utang|pinjam|minjem|mau\s+ngutang|nitip|titip)\b"#, in: t) { return .hutang }
        if matches(#"\b(?:utang|ngutang|pinjam|minjem)\b.*(?:ke|sama|pada)\s+(?!"# + user + #"\b)[\p{L}0-9_]+"#, in: t) { return .hutang }
        if matches(#"di(?:talangin|bayarin|nombokin|tombokin|pinjamin|pinjemin|tutupin)\b"#, in: t) { return .hutang }
        if matches(#"[\p{L}0-9_]+\s+(?:bayarin|nombokin|beliin|bayar\s+dulu|minjemin)\s+.*"# + user + #"\b"#, in: t) { return .hutang }
        if matches(user + #"\s+(?:kepake\s+duit|hutang)\b"#, in: t) { return .hutang }

        if matches(#"\b"# + user + #"\s+(?:bayarin|talangin|nalangin|nombokin|tombokin|tutupin|beliin|belikan|bayar\s+duluan|bayar\s+dulu|tf\s+duluan|beli|meminjamkan)\b"#, in: t) { return .piutang }
        if matches(#"^(?:bayarin|talangin|nalangin|nombokin|beliin|kasih\s+pinjaman|top\s+up)\b"#, in: t) { return .piutang }
        if matches(#"\b(?:ngutang|utang|pinjam|minjem)\b.*(?:ke|sama|dari|pada)\s+"# + user + #"\b"#, in: t) { return .piutang }
        if matches(#"\b(?:utang\s+"# + user + #"|ngutang\s+"# + user + #"|belum\s+bayar\s+utang|utang\s+kas|piutang\s+dari|piutang|meminjamkan)\b"#, in: t) { return .piutang }
        if matches(#"duit\s+"# + user + #"\s+kepake\b"#, in: t) { return .piutang }
        if matches(#"\b[\p{L}0-9_]+\s+(?:nitip|titip|menitip)\b"#, in: t), !matches(#"\b"# + user + #"\s+(?:nitip|titip|menitip)\b"#, in: t) { return .piutang }
        if matches(#"^(?:pak\s+|bu\s+|si\s+)?[\p{L}0-9_]+\s+(?:pinjam|pinjem|minjem|ngutang|utang)\b"#, in: t), !matches(#"^"# + user + #"\b"#, in: t) { return .piutang }

        return defaultDirection
    }

    static func extractPersonName(from text: String, modelPerson: String?) -> String? {
        let text = stripDiscoursePrefixes(text)
        if let honorific = firstMatch(for: #"\b((?:Bu|Pak)\s+[\p{L}][\p{L}'-]*)\b"#, in: text), isUsablePersonName(honorific) {
            return honorific.capitalized
        }
        if let modelPerson = sanitizePersonCandidate(modelPerson), isUsablePersonName(modelPerson) {
            return modelPerson.capitalized
        }
        let patterns = [
            #"\bsi\s+([\p{L}][\p{L}'-]*)\b"#,
            #"\b(?:talangin|nalangin|nombokin|pinjem\s+duit|utang\s+ke|hutang\s+ke|pinjam\s+uang\s+ke)\s+([\p{L}][\p{L}'-]*)\b"#,
            #"\b(?:ke|sama|dari|buat|untuk|lewat)\s+(?:si\s+)?([\p{L}][\p{L}'-]*)\b"#,
            #"^(?:si\s+)?([\p{L}][\p{L}'-]*)\s+(?:barusan\s+|tadi\s+|baru\s+|kemarin\s+|abis\s+)?(?:ngutang|utang|pinjam|pinjem|minjem|titip|nitip|menitip|bayarin|minjemin|nombokin|beliin)\b"#
        ]
        for pattern in patterns {
            if let candidate = firstMatch(for: pattern, in: text), isUsablePersonName(candidate) {
                return candidate.capitalized
            }
        }
        return nil
    }

    static func extractSplitParticipants(from text: String, modelNames: [String]) -> [String] {
        let candidates: [String]
        if modelNames.isEmpty {
            candidates = splitNameList(from: text)
        } else {
            candidates = modelNames.flatMap(expandPossibleNameList)
        }
        var result: [String] = []
        var seen: Set<String> = []
        for raw in candidates {
            guard let name = sanitizePersonCandidate(raw), isUsableSplitName(name) else { continue }
            let key = normalizedName(name)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name.capitalized)
        }
        return result
    }

    static func extractTitle(from text: String, modelTitle: String?) -> String? {
        if let title = titleFromTranscript(text) { return title }
        guard let modelTitle = sanitizeOptional(modelTitle) else { return nil }
        let cleaned = modelTitle
            .replacingOccurrences(of: #"\s+\b(?:ke|sama|dari|buat|untuk|oleh|si)\b.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^\b(?:buat|untuk|keperluan|ke|sama|dari|si|seharga|sebesar|total|sebanyak|\d+|rp)\b\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return isGenericTitle(cleaned) ? nil : cleaned
    }

    private static func titleFromTranscript(_ text: String) -> String? {
        let itemPattern = #"\b(?:tiket\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|nasi\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|kopi\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|kopi|token\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|buku\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|sepatu\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|martabak\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|jas\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|bensin\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|rokok\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|obat\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|modal\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|uang\s+kas|saldo\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|makan\s+siang|makan\s+malam|makan\s+di\s+[\p{L}]+|makan|servis\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|sewa\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|dendeng|sate\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|telur\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|kacang\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|pulsa|boba\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|belanja\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|parkir\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|bensin|top\s+up\s+(?!ke\b|sama\b|dari\b|buat\b|untuk\b)[\p{L}]+|duit\s+kantor|uang\s+kepake)\b"#
        if let item = firstMatch(for: "(" + itemPattern + ")", in: text) {
            return item.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let verb = firstMatch(for: #"\b((?:beli|bayar|pesen|sewa|servis)\s+[\p{L}\s]+?)(?:\s+(?:seharga|sebesar|total|sebanyak|habis|\d|ke|sama|dari|tanggal|kemarin|semalam)|$)"#, in: text) {
            let cleaned = verb.trimmingCharacters(in: .whitespacesAndNewlines)
            return isGenericTitle(cleaned) ? nil : cleaned
        }
        return nil
    }

    private static func splitNameList(from text: String) -> [String] {
        let patterns = [
            #"\b(?:untuk|bersama|bareng|sama|dengan|orangnya)\s+(.+?)(?=\s+(?:bagi\s+rata|dibagi|total(?:nya)?|seharga|senilai|abis|habis|qris|\d)\b|$)"#,
            #"\b(?:pesertanya|anggotanya)\s+(.+)$"#
        ]
        for pattern in patterns {
            if let raw = firstMatch(for: pattern, in: text) {
                let names = expandPossibleNameList(raw)
                if !names.isEmpty { return names }
            }
        }
        return []
    }

    private static func expandPossibleNameList(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: ",", with: " dan ")
            .replacingOccurrences(of: #"\s+(?:dan|sama|dengan|plus|&|/)\s+"#, with: "|", options: [.regularExpression, .caseInsensitive])
        return normalized.split(separator: "|").flatMap { part -> [String] in
            let words = part.split(separator: " ").map(String.init)
            if words.count > 1, words.allSatisfy({ isUsableSplitName($0) && $0.first?.isUppercase == true }) {
                return words
            }
            return [String(part)]
        }
    }

    private static func sanitizeOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func sanitizePersonCandidate(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: #"^(?:si|ke|sama|dari|buat|untuk|oke|tadi|bu|pak|mulai|bayarin|nombokin|dinombokin|ditalangin|talangin|gua\s+talangin|gua|dan|dengan|plus|bareng)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func isUsablePersonName(_ value: String) -> Bool {
        let stop: Set<String> = [
            "aku", "saya", "gue", "gw", "gua", "ane", "kamu", "dia", "mereka", "kita", "kami",
            "nitip", "titip", "beli", "utang", "ngutang", "hutang", "pinjam", "pinjem", "minjem", "transaksi", "makan",
            "kantor", "si", "uang", "duit", "rp", "rupiah", "total", "totalnya", "tolong", "catat",
            "bayarin", "nombokin", "dinombokin", "ditalangin", "bayar", "talangin", "nalangin", "pesen", "beliin",
            "sama", "ke", "buat", "untuk", "tadi", "siang", "pagi", "malam", "mulai", "oke", "servis"
        ]
        return value.count > 1 && !stop.contains(value.lowercased())
    }

    private static func isUsableSplitName(_ value: String) -> Bool {
        let stop: Set<String> = [
            "aku", "saya", "gue", "gw", "gua", "ane", "kamu", "dia", "mereka", "kita", "kami",
            "dan", "sama", "bareng", "buat", "untuk", "dengan", "ke", "di", "plus",
            "mcd", "kfc", "domino", "hut", "pizza", "starbucks", "shabu", "hachi", "gacoan", "suki",
            "oke", "total", "totalnya", "beli", "makan", "nongkrong", "pesan", "patungan", "split", "bill"
        ]
        return value.count > 1 && !stop.contains(value.lowercased())
    }

    private static func isGenericTitle(_ value: String) -> Bool {
        let generic: Set<String> = ["", "transaksi", "none", "utang", "hutang", "piutang", "pinjaman", "ngutang", "pinjam", "pinjem", "bayar"]
        return generic.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func scaledAmount(_ raw: String, multiplier: Int64) -> Int64? {
        let clean = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(clean) else { return nil }
        let result = Int64((value * Double(multiplier)).rounded())
        return result > 0 && result <= maximumSupportedAmount ? result : nil
    }

    private static func dedupeReceivables(_ values: [SplitReceivable]) -> [SplitReceivable] {
        var seen: Set<String> = []
        var result: [SplitReceivable] = []
        for rec in values {
            guard isUsableSplitName(rec.person) else { continue }
            let key = normalizedName(rec.person)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(SplitReceivable(person: rec.person.capitalized, item: rec.item, amount: rec.amount))
        }
        return result
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func stripDiscoursePrefixes(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"^\s*(?:tadi|kemarin|oke(?:\s+jadi)?|nah|mulai|kayaknya|seingatku\s+sih)\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func firstMatch(for pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > 1 else { return nil }
        let r = match.range(at: 1)
        return r.location != NSNotFound ? nsString.substring(with: r) : nil
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }
}
