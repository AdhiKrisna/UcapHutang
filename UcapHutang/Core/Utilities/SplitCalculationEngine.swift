import Foundation

public enum SplitCalculationEngine {
    private static let maximumSupportedAmount: Int64 = 1_000_000_000_000_000

    /// Divides totalAmount among N participants, distributing integer Rupiah remainder to the first `remainder` participants.
    /// Sum of shares is guaranteed to equal totalAmount.
    public static func calculateEqualShares(totalAmount: Int64, participantCount: Int) -> [Int64] {
        guard participantCount > 0 else { return [] }
        guard totalAmount > 0 else { return Array(repeating: 0, count: participantCount) }

        let count64 = Int64(participantCount)
        let baseShare = totalAmount / count64
        let remainder = totalAmount % count64

        var shares: [Int64] = []
        for i in 0..<participantCount {
            let share = baseShare + (Int64(i) < remainder ? 1 : 0)
            shares.append(share)
        }
        return shares
    }

    /// Derives integer Rupiah amounts from percentages, distributing rounding remainder deterministically.
    public static func calculatePercentageShares(totalAmount: Int64, percentages: [Double]) -> [Int64] {
        guard !percentages.isEmpty else { return [] }
        guard totalAmount > 0, totalAmount <= maximumSupportedAmount else {
            return totalAmount <= 0 ? Array(repeating: 0, count: percentages.count) : []
        }

        let exactShares = percentages.map { Double(totalAmount) * ($0 / 100.0) }
        var rawShares = exactShares.map { Int64($0.rounded(.down)) }
        let currentSum = rawShares.reduce(0, +)
        let remainder = max(0, min(Int64(rawShares.count), totalAmount - currentSum))
        let remainderOrder = exactShares.indices.sorted {
            let leftFraction = exactShares[$0] - Double(rawShares[$0])
            let rightFraction = exactShares[$1] - Double(rawShares[$1])
            return leftFraction == rightFraction ? $0 < $1 : leftFraction > rightFraction
        }
        for index in remainderOrder.prefix(Int(remainder)) {
            rawShares[index] += 1
        }

        return rawShares
    }

    /// Validates if custom manual amounts sum exactly to totalAmount.
    public static func isManualAllocationValid(shares: [Int64], totalAmount: Int64) -> Bool {
        let sum = shares.reduce(0, +)
        let allNonNegative = shares.allSatisfy { $0 >= 0 }
        return allNonNegative && sum == totalAmount
    }
}
