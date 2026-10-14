import Foundation

/// Balance of the optional virtual workshop. No real-world value.
struct WorkshopState: Codable, Equatable {
    var capsules: Int = 0
    var parts: Int = 0
    var nextEligibleAt: Date?
    /// Latest wall-clock time seen by the app; used to notice clock roll-back.
    var lastSeenAt: Date?
}

/// Ledger row for a granted free capsule. Kept even when the test is deleted.
struct CapsuleAward: Codable, Equatable, Identifiable {
    let id: UUID
    let testID: UUID
    let grantedAt: Date
    let delta: Int
}

enum CastSymbol: String, Codable, CaseIterable, Identifiable {
    case s01 = "S01", s02 = "S02", s03 = "S03", s04 = "S04", s05 = "S05", s06 = "S06"
    var id: String { rawValue }

    var accessibilityName: String {
        switch self {
        case .s01: return "Float"
        case .s02: return "Silver minnow"
        case .s03: return "Capsule"
        case .s04: return "Pearl"
        case .s05: return "Fishing rod"
        case .s06: return "Bass"
        }
    }
}

enum CastReceiptStatus: String, Codable {
    /// Balance already committed; result not yet shown to the user.
    case committed
    /// Result shown to the user.
    case presented
}

/// Durable record of one Lucky Cast. Created atomically with the balance change, before any animation.
struct CastReceipt: Codable, Equatable, Identifiable {
    let id: UUID
    /// rows × columns (3 × 5) of symbols.
    let matrix: [[CastSymbol]]
    let parts: Int
    let createdAt: Date
    var status: CastReceiptStatus
}

/// A crafted collectible (L01–L04). Collectibles never become real lures.
struct CollectibleRecord: Codable, Equatable, Identifiable {
    let id: String
    let craftedAt: Date
}

struct CollectibleDefinition: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let costParts: Int
}
