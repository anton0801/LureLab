import Foundation

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var title: String { self == .metric ? "Metric" : "Imperial" }
}

struct AppSettings: Codable, Equatable {
    var hapticsEnabled: Bool = true
    var reduceMotion: Bool = false
    var units: UnitSystem = .metric
    var onboardingCompleted: Bool = false
    /// Last lure the user chose for a test; drives the Home "On the bench" card.
    var lastSelectedLureID: UUID?
}

enum DraftKind: String, Codable {
    case test
    case lure
}

/// An unsaved form. Drafts never take part in statistics or rewards.
struct Draft: Codable, Equatable, Identifiable {
    /// Same UUID as the entity being created / edited, so retries stay idempotent.
    let id: UUID
    let kind: DraftKind
    var payload: Data
    var updatedAt: Date
}

/// Serializable state of the "Log a Test" form.
struct TestDraftPayload: Codable, Equatable {
    var isEditing: Bool
    var lureID: UUID?
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

/// Serializable state of the "Add Lure" form. Photo bytes are not kept in drafts.
struct LureDraftPayload: Codable, Equatable {
    /// Units the measurement texts were typed in (nil in drafts from before this field existed).
    var units: UnitSystem? = nil
    var isEditing: Bool
    var name: String
    var type: LureType?
    var lengthText: String
    var weightText: String
    var color: String
    var brand: String
    var notes: String
}
