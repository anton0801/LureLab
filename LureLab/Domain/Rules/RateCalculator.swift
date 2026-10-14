import Foundation

/// Describes past observations; never predicts. rate = 60 × Σcount / Σminutes over tests where the count is known.
struct RateSummary: Equatable {
    let metric: CountMetric
    let includedTests: Int
    let totalMinutes: Int
    let totalCount: Int
    /// `nil` = Not recorded (no test with this count). 0 is a real measured value.
    let ratePerHour: Double?
}

enum RateCalculator {
    static func summarize(_ tests: [TestEntry], metric: CountMetric) -> RateSummary {
        let included = tests.filter { $0.completed && $0.count(metric) != nil }
        let minutes = included.reduce(0) { $0 + $1.durationMinutes }
        let count = included.reduce(0) { $0 + ($1.count(metric) ?? 0) }
        let rate: Double?
        if included.isEmpty || minutes <= 0 {
            rate = nil
        } else {
            rate = 60.0 * Double(count) / Double(minutes)
        }
        return RateSummary(metric: metric, includedTests: included.count, totalMinutes: minutes, totalCount: count, ratePerHour: rate)
    }
}

enum ComparePeriod: String, CaseIterable, Identifiable, Codable {
    case last7, last30, last90, allTime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .last7: return "Last 7 days"
        case .last30: return "Last 30 days"
        case .last90: return "Last 90 days"
        case .allTime: return "All dates"
        }
    }

    func startDate(now: Date, calendar: Calendar = .current) -> Date? {
        let days: Int
        switch self {
        case .last7: days = 7
        case .last30: days = 30
        case .last90: days = 90
        case .allTime: return nil
        }
        return calendar.date(byAdding: .day, value: -days, to: now)
    }
}

/// Shared filter used by Journal and Compare so a metric opens exactly its source tests.
struct TestFilter: Equatable, Hashable, Codable {
    var period: ComparePeriod = .allTime
    var lureIDs: Set<UUID> = []
    var waterType: WaterType?
    var clarity: WaterClarity?
    var retrieve: RetrieveStyle?
    var requiredMetric: CountMetric?
    var searchText: String = ""

    var hasConditionFilter: Bool { waterType != nil || clarity != nil || retrieve != nil }

    func apply(to tests: [TestEntry], now: Date = Date()) -> [TestEntry] {
        let start = period.startDate(now: now)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tests.filter { test in
            guard test.completed else { return false }
            if let start, test.occurredAt < start { return false }
            if !lureIDs.isEmpty && !lureIDs.contains(test.lureID) { return false }
            if let waterType, test.waterType != waterType { return false }
            if let clarity, test.clarity != clarity { return false }
            if let retrieve, test.retrieve != retrieve { return false }
            if let requiredMetric, test.count(requiredMetric) == nil { return false }
            if !query.isEmpty {
                let haystack = [test.placeName, test.notes, test.weatherNote].joined(separator: " ").lowercased()
                if !haystack.contains(query) { return false }
            }
            return true
        }
    }
}
