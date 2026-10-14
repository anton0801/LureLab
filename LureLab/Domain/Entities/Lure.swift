import Foundation

/// Lure category. Raw values are the persisted / backup enum values.
enum LureType: String, Codable, CaseIterable, Identifiable {
    case minnow, spinner, softBait, spoon, jig, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minnow: return "Minnow"
        case .spinner: return "Spinner"
        case .softBait: return "Soft bait"
        case .spoon: return "Spoon"
        case .jig: return "Jig"
        case .other: return "Other"
        }
    }
}

/// A real lure owned by the user. Canonical units: centimetres and grams.
struct Lure: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var type: LureType
    var lengthCm: Decimal?
    var weightG: Decimal?
    var color: String?
    var brand: String?
    var notes: String
    /// Relative file name inside the managed photo directory.
    var photoPath: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    enum Limits {
        static let name = 1...80
        static let length: ClosedRange<Decimal> = Decimal(string: "0.1")!...200
        static let weight: ClosedRange<Decimal> = Decimal(string: "0.1")!...10_000
        static let shortText = 80
        static let notes = 2000
    }
}
