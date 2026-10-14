import Foundation

enum FormField: String, Hashable, CaseIterable {
    // Lure
    case name, type, length, weight, color, brand, lureNotes
    // Test
    case lure, place, date, duration, bites, catches, weatherNote, testNotes
}

struct ValidationIssue: Equatable, Error {
    let field: FormField
    let message: String
}

enum Validated<Value: Equatable>: Equatable {
    case valid(Value)
    case invalid([ValidationIssue])

    var issues: [ValidationIssue] {
        if case let .invalid(issues) = self { return issues }
        return []
    }

    var value: Value? {
        if case let .valid(value) = self { return value }
        return nil
    }
}

/// Parses user-entered decimals ("9", "9.5", "9,5"). Empty text means "unknown" (nil), never 0.
enum DecimalInput {
    enum ParseResult: Equatable {
        case empty
        case value(Decimal)
        case invalid
    }

    static func parse(_ text: String) -> ParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard normalized.unicodeScalars.allSatisfy(allowed.contains),
              normalized.filter({ $0 == "." }).count <= 1,
              normalized != ".",
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        else { return .invalid }
        return .value(value)
    }

    static func parseInt(_ text: String) -> Int?? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard trimmed.allSatisfy(\.isNumber), trimmed.count <= 6, let value = Int(trimmed) else { return nil }
        return .some(value)
    }
}

/// A measurement field. When the text was not touched the original canonical value is kept,
/// so switching units never accumulates rounding.
struct MeasurementInput: Equatable {
    var text: String
    var initialText: String
    var initialCanonical: Decimal?

    init(text: String = "", initialText: String = "", initialCanonical: Decimal? = nil) {
        self.text = text
        self.initialText = initialText
        self.initialCanonical = initialCanonical
    }
}

struct LureInput: Equatable {
    var name: String
    var type: LureType?
    var length: MeasurementInput
    var weight: MeasurementInput
    var color: String
    var brand: String
    var notes: String
    var units: UnitSystem
}

struct ValidatedLureFields: Equatable {
    let name: String
    let type: LureType
    let lengthCm: Decimal?
    let weightG: Decimal?
    let color: String?
    let brand: String?
    let notes: String
}

enum LureValidator {
    static func validate(_ input: LureInput) -> Validated<ValidatedLureFields> {
        var issues: [ValidationIssue] = []
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            issues.append(.init(field: .name, message: "Enter a name for this lure."))
        } else if name.count > Lure.Limits.name.upperBound {
            issues.append(.init(field: .name, message: "Use up to 80 characters."))
        }
        if input.type == nil {
            issues.append(.init(field: .type, message: "Choose a lure type."))
        }

        let length = canonical(input.length, kind: .length, units: input.units)
        if case let .failure(issue) = length { issues.append(issue) }
        let weight = canonical(input.weight, kind: .weight, units: input.units)
        if case let .failure(issue) = weight { issues.append(issue) }

        let color = input.color.trimmingCharacters(in: .whitespacesAndNewlines)
        if color.count > Lure.Limits.shortText { issues.append(.init(field: .color, message: "Use up to 80 characters.")) }
        let brand = input.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        if brand.count > Lure.Limits.shortText { issues.append(.init(field: .brand, message: "Use up to 80 characters.")) }
        let notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.count > Lure.Limits.notes { issues.append(.init(field: .lureNotes, message: "Use up to 2000 characters.")) }

        guard issues.isEmpty, let type = input.type,
              case let .success(lengthCm) = length, case let .success(weightG) = weight
        else { return .invalid(issues) }

        return .valid(ValidatedLureFields(
            name: name,
            type: type,
            lengthCm: lengthCm,
            weightG: weightG,
            color: color.isEmpty ? nil : color,
            brand: brand.isEmpty ? nil : brand,
            notes: notes
        ))
    }

    private enum Kind { case length, weight }

    private static func canonical(_ input: MeasurementInput, kind: Kind, units: UnitSystem) -> Result<Decimal?, ValidationIssue> {
        let field: FormField = kind == .length ? .length : .weight
        if input.text == input.initialText, input.initialCanonical != nil {
            return .success(input.initialCanonical)
        }
        let rangeMessage: String
        switch (kind, units) {
        case (.length, .metric): rangeMessage = "Enter a length from 0.1 to 200 cm, or leave it empty."
        case (.length, .imperial): rangeMessage = "Enter a length from 0.04 to 78.74 in, or leave it empty."
        case (.weight, .metric): rangeMessage = "Enter a weight from 0.1 to 10000 g, or leave it empty."
        case (.weight, .imperial): rangeMessage = "Enter a weight from 0.01 to 352.73 oz, or leave it empty."
        }
        switch DecimalInput.parse(input.text) {
        case .empty:
            return .success(nil)
        case .invalid:
            return .failure(.init(field: field, message: rangeMessage))
        case let .value(displayValue):
            let value: Decimal
            switch kind {
            case .length: value = UnitMath.lengthToCentimetres(displayValue, from: units)
            case .weight: value = UnitMath.weightToGrams(displayValue, from: units)
            }
            let range = kind == .length ? Lure.Limits.length : Lure.Limits.weight
            // Imperial bounds are rounded for display; accept tiny conversion slack at the edges.
            let slack: Decimal = units == .metric ? 0 : Decimal(string: "0.01")!
            guard value >= range.lowerBound - slack, value <= range.upperBound + slack else {
                return .failure(.init(field: field, message: rangeMessage))
            }
            return .success(min(max(value, range.lowerBound), range.upperBound))
        }
    }
}

struct TestInput: Equatable {
    var lure: Lure?
    var placeName: String
    var occurredAt: Date
    var durationText: String
    var bites: Int?
    var catches: Int?
    var waterType: WaterType?
    var clarity: WaterClarity?
    var retrieve: RetrieveStyle?
    var weatherNote: String
    var notes: String
}

struct ValidatedTestFields: Equatable {
    let lure: Lure
    let placeName: String
    let occurredAt: Date
    let durationMinutes: Int
    let bites: Int?
    let catches: Int?
    let waterType: WaterType?
    let clarity: WaterClarity?
    let retrieve: RetrieveStyle?
    let weatherNote: String
    let notes: String
}

enum TestValidator {
    static let durationMessage = "Enter a duration from 1 to 1440 min."
    static let catchesMessage = "Catches cannot exceed recorded bites."

    static func validate(_ input: TestInput, now: Date) -> Validated<ValidatedTestFields> {
        var issues: [ValidationIssue] = []
        if input.lure == nil {
            issues.append(.init(field: .lure, message: "Choose a lure for this test."))
        }
        let place = input.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if place.isEmpty {
            issues.append(.init(field: .place, message: "Enter a place."))
        } else if place.count > TestEntry.Limits.place.upperBound {
            issues.append(.init(field: .place, message: "Use up to 80 characters."))
        }
        // Not later than the current minute.
        let latest = Calendar.current.dateInterval(of: .minute, for: now)?.end ?? now
        if input.occurredAt > latest {
            issues.append(.init(field: .date, message: "Choose a date and time that is not in the future."))
        }
        var duration: Int?
        if let parsed = DecimalInput.parseInt(input.durationText), let minutes = parsed,
           TestEntry.Limits.duration.contains(minutes) {
            duration = minutes
        } else {
            issues.append(.init(field: .duration, message: durationMessage))
        }
        if let bites = input.bites, !TestEntry.Limits.count.contains(bites) {
            issues.append(.init(field: .bites, message: "Enter bites from 0 to 9999."))
        }
        if let catches = input.catches, !TestEntry.Limits.count.contains(catches) {
            issues.append(.init(field: .catches, message: "Enter catches from 0 to 9999."))
        }
        if let bites = input.bites, let catches = input.catches, catches > bites {
            issues.append(.init(field: .catches, message: catchesMessage))
        }
        let weather = input.weatherNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if weather.count > TestEntry.Limits.weatherNote {
            issues.append(.init(field: .weatherNote, message: "Use up to 200 characters."))
        }
        let notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.count > TestEntry.Limits.notes {
            issues.append(.init(field: .testNotes, message: "Use up to 2000 characters."))
        }
        guard issues.isEmpty, let lure = input.lure, let duration else { return .invalid(issues) }
        return .valid(ValidatedTestFields(
            lure: lure,
            placeName: place,
            occurredAt: input.occurredAt,
            durationMinutes: duration,
            bites: input.bites,
            catches: input.catches,
            waterType: input.waterType,
            clarity: input.clarity,
            retrieve: input.retrieve,
            weatherNote: weather,
            notes: notes
        ))
    }
}

/// Stepper semantics for bites/catches: + from nil gives 1, − from nil gives 0, never below 0.
enum CountStepper {
    static func increment(_ value: Int?) -> Int? {
        guard let value else { return 1 }
        return min(value + 1, TestEntry.Limits.count.upperBound)
    }

    static func decrement(_ value: Int?) -> Int? {
        guard let value else { return 0 }
        return max(value - 1, 0)
    }
}
