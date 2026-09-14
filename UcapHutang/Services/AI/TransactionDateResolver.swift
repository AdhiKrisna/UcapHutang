import Foundation

public struct TransactionTemporalComponents: Equatable, Codable, Sendable {
    public var day: Int?
    public var month: Int?
    public var year: Int?
    public var hour: Int?
    public var minute: Int?

    public init(day: Int? = nil, month: Int? = nil, year: Int? = nil, hour: Int? = nil, minute: Int? = nil) {
        self.day = day
        self.month = month
        self.year = year
        self.hour = hour
        self.minute = minute
    }

    public var isAllNil: Bool {
        day == nil && month == nil && year == nil && hour == nil && minute == nil
    }
}

public enum TemporalResolutionSource: String, Codable, CaseIterable, Sendable {
    case transcript
    case model
    case defaultNow = "default_now"
}

public struct ResolvedTransactionDate: Equatable, Sendable {
    public let date: Date
    public let components: TransactionTemporalComponents
    public let source: TemporalResolutionSource
    public let warning: String?

    public init(date: Date, components: TransactionTemporalComponents, source: TemporalResolutionSource, warning: String? = nil) {
        self.date = date
        self.components = components
        self.source = source
        self.warning = warning
    }
}

public enum TransactionDateResolver {
    private static let monthNames: [String: Int] = [
        "januari": 1, "jan": 1,
        "februari": 2, "feb": 2,
        "maret": 3, "mar": 3,
        "april": 4, "apr": 4,
        "mei": 5, "may": 5,
        "juni": 6, "jun": 6,
        "juli": 7, "jul": 7,
        "agustus": 8, "agt": 8, "agu": 8,
        "september": 9, "sep": 9, "sept": 9,
        "oktober": 10, "okt": 10,
        "november": 11, "nov": 11,
        "desember": 12, "des": 12
    ]

    public static func resolve(
        transcript: String,
        modelComponents: TransactionTemporalComponents?,
        referenceNow: Date = Date(),
        calendar: Calendar = .current
    ) -> ResolvedTransactionDate {
        if let deterministic = extractFromTranscript(transcript, referenceNow: referenceNow, calendar: calendar) {
            return deterministic
        }

        if let model = modelComponents, !model.isAllNil {
            if let resolvedModel = resolveFromComponents(model, referenceNow: referenceNow, calendar: calendar, source: .model) {
                return resolvedModel
            } else {
                return ResolvedTransactionDate(
                    date: referenceNow,
                    components: model,
                    source: .defaultNow,
                    warning: "Komponen waktu dari AI tidak valid. Menggunakan waktu saat ini."
                )
            }
        }

        let currentComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: referenceNow)
        let defaultComponents = TransactionTemporalComponents(
            day: currentComps.day,
            month: currentComps.month,
            year: currentComps.year,
            hour: currentComps.hour,
            minute: currentComps.minute
        )
        return ResolvedTransactionDate(
            date: referenceNow,
            components: defaultComponents,
            source: .defaultNow,
            warning: nil
        )
    }

    public static func resolveFromComponents(
        _ comps: TransactionTemporalComponents,
        referenceNow: Date,
        calendar: Calendar,
        source: TemporalResolutionSource
    ) -> ResolvedTransactionDate? {
        let nowComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: referenceNow)

        let targetYear = comps.year ?? nowComps.year!
        let targetMonth = comps.month ?? nowComps.month!
        let targetDay = comps.day ?? nowComps.day!

        let targetHour = comps.hour ?? nowComps.hour!
        let targetMinute = comps.minute ?? (comps.hour != nil ? 0 : nowComps.minute!)

        guard (1...12).contains(targetMonth) else { return nil }
        guard (0...23).contains(targetHour) else { return nil }
        guard (0...59).contains(targetMinute) else { return nil }

        var testComps = DateComponents()
        testComps.year = targetYear
        testComps.month = targetMonth
        testComps.day = 1
        guard let monthDate = calendar.date(from: testComps),
              let range = calendar.range(of: .day, in: .month, for: monthDate),
              range.contains(targetDay) else {
            return nil
        }

        var finalComps = DateComponents()
        finalComps.year = targetYear
        finalComps.month = targetMonth
        finalComps.day = targetDay
        finalComps.hour = targetHour
        finalComps.minute = targetMinute
        finalComps.second = 0

        guard let resolvedDate = calendar.date(from: finalComps) else { return nil }

        return ResolvedTransactionDate(
            date: resolvedDate,
            components: comps,
            source: source,
            warning: nil
        )
    }

    public static func extractFromTranscript(
        _ text: String,
        referenceNow: Date,
        calendar: Calendar
    ) -> ResolvedTransactionDate? {
        let lower = text.lowercased()
        let nowComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: referenceNow)

        var extractedDay: Int?
        var extractedMonth: Int?
        var extractedYear: Int?
        var extractedHour: Int?
        var extractedMinute: Int?
        var hasExplicitTemporal = false

        if lower.contains("kemarin") || lower.contains("semalam") {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceNow) {
                let yComps = calendar.dateComponents([.year, .month, .day], from: yesterday)
                extractedYear = yComps.year
                extractedMonth = yComps.month
                extractedDay = yComps.day
                hasExplicitTemporal = true
            }
        } else if lower.contains("besok") {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceNow) {
                let tComps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                extractedYear = tComps.year
                extractedMonth = tComps.month
                extractedDay = tComps.day
                hasExplicitTemporal = true
            }
        } else if lower.contains("hari ini") {
            extractedYear = nowComps.year
            extractedMonth = nowComps.month
            extractedDay = nowComps.day
            hasExplicitTemporal = true
        }

        let dateMonthNameRegex = #"\b(\d{1,2})\s+(januari|februari|maret|april|mei|juni|juli|agustus|september|oktober|november|desember|jan|feb|mar|apr|may|jun|jul|agt|agu|sep|sept|okt|nov|des)(?:\s+(\d{4}))?\b"#
        if let match = firstMatch(for: dateMonthNameRegex, in: lower),
           match.count > 2,
           let dStr = match[1], let d = Int(dStr),
           let mStr = match[2], let m = monthNames[mStr] {
            extractedDay = d
            extractedMonth = m
            if match.count > 3, let yStr = match[3], let y = Int(yStr) {
                extractedYear = y
            } else {
                extractedYear = extractedYear ?? nowComps.year
            }
            hasExplicitTemporal = true
        }

        let numericDateRegex = #"\b(\d{1,2})[\/-](\d{1,2})(?:[\/-](\d{4}))?\b"#
        if extractedDay == nil, let match = firstMatch(for: numericDateRegex, in: lower),
           match.count > 2,
           let dStr = match[1], let d = Int(dStr),
           let mStr = match[2], let m = Int(mStr), (1...12).contains(m) {
            extractedDay = d
            extractedMonth = m
            if match.count > 3, let yStr = match[3], let y = Int(yStr) {
                extractedYear = y
            } else {
                extractedYear = nowComps.year
            }
            hasExplicitTemporal = true
        }

        let timeRegex = #"\b(?:jam|pukul)\s+(\d{1,2})(?:[:.](\d{2}))?(?:\s+(pagi|siang|sore|malam))?\b"#
        if let match = firstMatch(for: timeRegex, in: lower),
           match.count > 1,
           let hStr = match[1], var h = Int(hStr) {
            let m: Int
            if match.count > 2, let mStr = match[2], let parsedM = Int(mStr) {
                m = parsedM
            } else {
                m = 0
            }
            let period = match.count > 3 ? match[3] : nil

            if let period {
                if period == "malam" || period == "sore" {
                    if h < 12 { h += 12 }
                } else if period == "pagi" {
                    if h == 12 { h = 0 }
                } else if period == "siang" {
                    if h < 11 { h += 12 }
                }
            }

            if (0...23).contains(h) && (0...59).contains(m) {
                extractedHour = h
                extractedMinute = m
                hasExplicitTemporal = true
            }
        }

        guard hasExplicitTemporal else { return nil }

        let comps = TransactionTemporalComponents(
            day: extractedDay,
            month: extractedMonth,
            year: extractedYear,
            hour: extractedHour,
            minute: extractedMinute
        )

        return resolveFromComponents(comps, referenceNow: referenceNow, calendar: calendar, source: .transcript)
    }

    private static func firstMatch(for pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        var results: [String?] = []
        for i in 0..<match.numberOfRanges {
            let r = match.range(at: i)
            if r.location != NSNotFound {
                results.append(nsString.substring(with: r))
            } else {
                results.append(nil)
            }
        }
        return results
    }
}
