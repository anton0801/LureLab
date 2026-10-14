import Foundation

/// Lucky Cast maths: 5 × 3 symbols, only the middle row is evaluated.
struct CastEngine {
    let rules: WorkshopRules

    struct Evaluation: Equatable {
        let parts: Int
        /// Longest run of identical symbols in the evaluated row.
        let runStart: Int
        let runLength: Int

        /// Columns to highlight; only a real 3+ match is highlighted.
        var highlightedColumns: Range<Int> {
            runLength >= 3 ? runStart..<(runStart + runLength) : 0..<0
        }
    }

    /// Draws `rows × columns` independent symbols with the system RNG (or an injected one in tests).
    func spin<G: RandomNumberGenerator>(using generator: inout G) -> [[CastSymbol]] {
        let symbols = rules.castSymbols
        let weights = rules.symbolWeights
        let total = weights.reduce(0, +)
        return (0..<rules.rows).map { _ in
            (0..<rules.columns).map { _ in
                var pick = Int.random(in: 0..<total, using: &generator)
                for (index, weight) in weights.enumerated() {
                    if pick < weight { return symbols[index] }
                    pick -= weight
                }
                return symbols[symbols.count - 1]
            }
        }
    }

    func spin() -> [[CastSymbol]] {
        var generator = SystemRandomNumberGenerator()
        return spin(using: &generator)
    }

    func evaluate(matrix: [[CastSymbol]]) -> Evaluation {
        guard matrix.indices.contains(rules.evaluatedRow) else {
            return Evaluation(parts: rules.reward.defaultParts, runStart: 0, runLength: 1)
        }
        return evaluate(row: matrix[rules.evaluatedRow])
    }

    func evaluate(row: [CastSymbol]) -> Evaluation {
        let run = Self.longestRun(in: row)
        let parts: Int
        if run.length >= 5 {
            parts = rules.reward.longestRun5Parts
        } else if run.length >= 3 {
            parts = rules.reward.longestRun3or4Parts
        } else {
            parts = rules.reward.defaultParts
        }
        return Evaluation(parts: parts, runStart: run.start, runLength: run.length)
    }

    static func longestRun(in row: [CastSymbol]) -> (start: Int, length: Int) {
        guard !row.isEmpty else { return (0, 0) }
        var bestStart = 0, bestLength = 1
        var currentStart = 0, currentLength = 1
        for index in 1..<row.count {
            if row[index] == row[index - 1] {
                currentLength += 1
            } else {
                currentStart = index
                currentLength = 1
            }
            if currentLength > bestLength {
                bestLength = currentLength
                bestStart = currentStart
            }
        }
        return (bestStart, bestLength)
    }

    /// Exhaustive distribution of Parts over every possible evaluated row (6^5 = 7776).
    func exhaustiveDistribution() -> [Int: Int] {
        let symbols = rules.castSymbols
        var counts: [Int: Int] = [:]
        var row = [CastSymbol](repeating: symbols[0], count: rules.columns)
        func visit(_ column: Int) {
            if column == rules.columns {
                counts[evaluate(row: row).parts, default: 0] += 1
                return
            }
            for symbol in symbols {
                row[column] = symbol
                visit(column + 1)
            }
        }
        visit(0)
        return counts
    }

    /// A board for the idle "ready" state that does not pretend to show a win.
    func idleBoard() -> [[CastSymbol]] {
        var board = spin()
        var attempts = 0
        while evaluate(matrix: board).runLength >= 3 && attempts < 50 {
            board = spin()
            attempts += 1
        }
        return board
    }
}
