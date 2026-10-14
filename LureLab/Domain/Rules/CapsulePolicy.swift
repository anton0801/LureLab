import Foundation

/// Free capsule rules: one capsule for the first new test saved after the cooldown, capped at `maxCapsules`.
struct CapsulePolicy {
    let cooldown: TimeInterval
    let maxCapsules: Int
    /// Tolerated backwards clock drift before the device clock is treated as rolled back.
    let clockTolerance: TimeInterval = 300

    init(rules: WorkshopRules) {
        cooldown = TimeInterval(rules.capsuleCooldownSeconds)
        maxCapsules = rules.maxCapsules
    }

    enum Decision: Equatable {
        case grant(nextEligibleAt: Date)
        /// Shelf is full: nothing accrues and the timer is not extended.
        case capped
        case coolingDown(until: Date)
        /// The device clock moved backwards; the stored cooldown is kept.
        case clockRolledBack(until: Date?)
    }

    func evaluate(state: WorkshopState, now: Date) -> Decision {
        if let lastSeen = state.lastSeenAt, now < lastSeen.addingTimeInterval(-clockTolerance) {
            return .clockRolledBack(until: state.nextEligibleAt)
        }
        if state.capsules >= maxCapsules {
            return .capped
        }
        if let next = state.nextEligibleAt, now < next {
            return .coolingDown(until: next)
        }
        return .grant(nextEligibleAt: now.addingTimeInterval(cooldown))
    }

    /// Applies a decision to the state; returns true when a capsule was granted.
    func apply(_ decision: Decision, to state: inout WorkshopState, now: Date) -> Bool {
        state.lastSeenAt = max(state.lastSeenAt ?? now, now)
        guard case let .grant(next) = decision else { return false }
        state.capsules += 1
        state.nextEligibleAt = next
        return true
    }
}

/// Outcome reported to the "Test Saved" screen.
enum CapsuleOutcome: Equatable {
    case earned
    case notEligible(nextAt: Date?)
    case shelfFull
    /// Edits and repeats of an existing record never grant again.
    case notApplicable
}
