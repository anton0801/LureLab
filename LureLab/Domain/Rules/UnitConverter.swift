import Foundation

/// Canonical storage is cm / g. in = cm / 2.54, oz = g / 28.349523125.
enum UnitMath {
    static let centimetresPerInch = Decimal(string: "2.54")!
    static let gramsPerOunce = Decimal(string: "28.349523125")!

    static func lengthToCentimetres(_ value: Decimal, from units: UnitSystem) -> Decimal {
        units == .metric ? value : value * centimetresPerInch
    }

    static func weightToGrams(_ value: Decimal, from units: UnitSystem) -> Decimal {
        units == .metric ? value : value * gramsPerOunce
    }

    static func lengthForDisplay(_ centimetres: Decimal, in units: UnitSystem) -> Decimal {
        units == .metric ? centimetres : centimetres / centimetresPerInch
    }

    static func weightForDisplay(_ grams: Decimal, in units: UnitSystem) -> Decimal {
        units == .metric ? grams : grams / gramsPerOunce
    }

    static func lengthUnit(_ units: UnitSystem) -> String { units == .metric ? "cm" : "in" }
    static func weightUnit(_ units: UnitSystem) -> String { units == .metric ? "g" : "oz" }

    /// Plain decimal text without grouping, max `fractionDigits` digits, trailing zeros trimmed.
    static func plainText(_ value: Decimal, fractionDigits: Int) -> String {
        var rounded = Decimal()
        var source = value
        NSDecimalRound(&rounded, &source, fractionDigits, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: rounded as NSDecimalNumber) ?? "\(rounded)"
    }

    static func lengthText(_ centimetres: Decimal, units: UnitSystem) -> String {
        plainText(lengthForDisplay(centimetres, in: units), fractionDigits: units == .metric ? 1 : 2)
    }

    static func weightText(_ grams: Decimal, units: UnitSystem) -> String {
        plainText(weightForDisplay(grams, in: units), fractionDigits: units == .metric ? 1 : 2)
    }
}
