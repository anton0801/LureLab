import Foundation

/// Display strings. Unknown values read "Not recorded"; zero is shown as a real value.
enum Format {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    private static let dayMonth = formatter("d MMM")
    private static let dayMonthPadded = formatter("dd MMM")
    private static let fullDate = formatter("d MMM yyyy")

    private static var uses12HourClock: Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    private static var timeFormatter: DateFormatter { formatter(uses12HourClock ? "h:mm a" : "HH:mm") }

    static func shortDate(_ date: Date) -> String { dayMonth.string(from: date) }
    static func groupHeader(_ date: Date) -> String { dayMonthPadded.string(from: date).uppercased() }
    static func mediumDate(_ date: Date) -> String { fullDate.string(from: date) }
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func dateAndTime(_ date: Date) -> String { "\(mediumDate(date)), \(time(date))" }
    static func shortDateAndTime(_ date: Date) -> String { "\(shortDate(date)), \(time(date))" }

    static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    static func tests(_ value: Int) -> String { value == 0 ? "Not tested" : count(value, "test", "tests") }
    static func capsules(_ value: Int) -> String { count(value, "capsule", "capsules") }
    static func parts(_ value: Int) -> String { count(value, "Part", "Parts") }

    static func durationAndCounts(_ test: TestEntry) -> String {
        var parts = ["\(test.durationMinutes) min"]
        switch (test.bites, test.catches) {
        case (nil, nil):
            parts.append("Counts not recorded")
        default:
            parts.append(test.bites.map { count($0, "bite", "bites") } ?? "Bites not recorded")
            parts.append(test.catches.map { count($0, "catch", "catches") } ?? "Catches not recorded")
        }
        return parts.joined(separator: " · ")
    }

    static func lureAndRetrieve(lureName: String, retrieve: RetrieveStyle?) -> String {
        [lureName, retrieve?.listTitle].compactMap { $0 }.joined(separator: " · ")
    }

    static func length(_ centimetres: Decimal, units: UnitSystem) -> String {
        "\(UnitMath.lengthText(centimetres, units: units)) \(UnitMath.lengthUnit(units))"
    }

    static func weight(_ grams: Decimal, units: UnitSystem) -> String {
        "\(UnitMath.weightText(grams, units: units)) \(UnitMath.weightUnit(units))"
    }

    static func lureMeta(_ lure: Lure, units: UnitSystem) -> String {
        var parts = [lure.type.title]
        if let centimetres = lure.lengthCm { parts.append(length(centimetres, units: units)) }
        if let grams = lure.weightG { parts.append(weight(grams, units: units)) }
        return parts.joined(separator: " · ")
    }

    static func rate(_ value: Double?) -> String {
        guard let value else { return "Not recorded" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
