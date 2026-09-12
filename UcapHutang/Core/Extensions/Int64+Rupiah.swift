import Foundation

extension Int64 {
    var rupiahFormatted: String {
        "Rp. " + formatted(.number.locale(Locale(identifier: "id_ID")).precision(.fractionLength(0)))
    }
}
