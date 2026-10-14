import Foundation

/// Mirror of `workshop_rules.json` shipped with the design package. The bundled JSON is the source of truth.
struct WorkshopRules: Codable, Equatable {
    struct Reward: Codable, Equatable {
        let defaultParts: Int
        let longestRun3or4Parts: Int
        let longestRun5Parts: Int
    }

    let schemaVersion: Int
    let symbols: [String]
    let symbolWeights: [Int]
    let rows: Int
    let columns: Int
    let evaluatedRow: Int
    let reward: Reward
    let rewardCountsOver7776: [String: Int]
    let capsuleCooldownSeconds: Int
    let maxCapsules: Int
    let craftCostParts: Int
    let collectibles: [CollectibleDefinition]

    var castSymbols: [CastSymbol] { symbols.compactMap(CastSymbol.init(rawValue:)) }

    static let fallback = WorkshopRules(
        schemaVersion: 1,
        symbols: CastSymbol.allCases.map(\.rawValue),
        symbolWeights: [1, 1, 1, 1, 1, 1],
        rows: 3,
        columns: 5,
        evaluatedRow: 1,
        reward: Reward(defaultParts: 1, longestRun3or4Parts: 2, longestRun5Parts: 3),
        rewardCountsOver7776: ["1": 7200, "2": 570, "3": 6],
        capsuleCooldownSeconds: 86_400,
        maxCapsules: 7,
        craftCostParts: 3,
        collectibles: [
            CollectibleDefinition(id: "L01", name: "Coral Comet", costParts: 3),
            CollectibleDefinition(id: "L02", name: "Emerald Drift", costParts: 3),
            CollectibleDefinition(id: "L03", name: "Midnight Fin", costParts: 3),
            CollectibleDefinition(id: "L04", name: "Sunrise Spinner", costParts: 3)
        ]
    )

    /// Loads the bundled rules; falls back to the identical compiled-in values.
    static func load(bundle: Bundle = .main) -> WorkshopRules {
        guard let url = bundle.url(forResource: "workshop_rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(WorkshopRules.self, from: data),
              rules.castSymbols.count == rules.symbols.count,
              rules.symbolWeights.count == rules.symbols.count,
              rules.symbolWeights.allSatisfy({ $0 > 0 })
        else { return .fallback }
        return rules
    }

    func collectible(_ id: String) -> CollectibleDefinition? {
        collectibles.first { $0.id == id }
    }
}
