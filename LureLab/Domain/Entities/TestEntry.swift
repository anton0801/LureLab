import Foundation

enum WaterType: String, Codable, CaseIterable, Identifiable {
    case lake, river, pond, coast, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lake: return "Lake"
        case .river: return "River"
        case .pond: return "Pond"
        case .coast: return "Coast"
        case .other: return "Other"
        }
    }
}

enum WaterClarity: String, Codable, CaseIterable, Identifiable {
    case clear, stained, muddy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clear: return "Clear"
        case .stained: return "Stained"
        case .muddy: return "Muddy"
        }
    }
}

enum RetrieveStyle: String, Codable, CaseIterable, Identifiable {
    case slow, steady, fast, stopAndGo, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .slow: return "Slow"
        case .steady: return "Steady"
        case .fast: return "Fast"
        case .stopAndGo: return "Stop and go"
        case .other: return "Other"
        }
    }
    /// Longer form used in lists ("Slow retrieve").
    var listTitle: String {
        switch self {
        case .other: return "Other retrieve"
        default: return "\(title) retrieve"
        }
    }
}

/// One completed field test of a lure. `nil` counts mean "Not recorded"; zero is a real value.
struct TestEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var lureID: UUID
    var lureNameSnapshot: String
    var lureTypeSnapshot: LureType
    var placeName: String
    var occurredAt: Date
    var durationMinutes: Int
    var bites: Int?
    var catches: Int?
    var waterType: WaterType?
    var clarity: WaterClarity?
    var retrieve: RetrieveStyle?
    var weatherNote: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var completed: Bool = true

    enum Limits {
        static let place = 1...80
        static let duration = 1...1440
        static let count = 0...9999
        static let weatherNote = 200
        static let notes = 2000
    }

    func count(_ metric: CountMetric) -> Int? {
        switch metric {
        case .bites: return bites
        case .catches: return catches
        }
    }
}

enum CountMetric: String, Codable, CaseIterable, Identifiable {
    case bites, catches
    var id: String { rawValue }
    var title: String { self == .bites ? "Bites" : "Catches" }
    var perHourTitle: String { self == .bites ? "Bites per hour" : "Catches per hour" }
    var singular: String { self == .bites ? "bite" : "catch" }
    var plural: String { self == .bites ? "bites" : "catches" }
}

/// Journal ordering: occurredAt DESC, then createdAt DESC.
extension Array where Element == TestEntry {
    func sortedForJournal() -> [TestEntry] {
        sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            return $0.createdAt > $1.createdAt
        }
    }
}
