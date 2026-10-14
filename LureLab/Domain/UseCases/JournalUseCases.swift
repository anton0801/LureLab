import Foundation

enum PhotoChange: Equatable {
    case unchanged
    case removed
    case replaced(Data)
}

/// Lure catalogue use cases. Photos are written before the reference is committed and cleaned up on failure.
final class LureUseCases {
    private let lures: LureRepository
    private let tests: TestRepository
    private let photos: PhotoStore
    private let clock: Clock

    init(lures: LureRepository, tests: TestRepository, photos: PhotoStore, clock: Clock) {
        self.lures = lures
        self.tests = tests
        self.photos = photos
        self.clock = clock
    }

    /// Creates or updates the lure with the given id. Retrying with the same id never duplicates.
    @discardableResult
    func saveLure(id: UUID, fields: ValidatedLureFields, photo: PhotoChange) throws -> Lure {
        let existing = try lures.fetchLures().first { $0.id == id }
        var newPath: String?
        if case let .replaced(data) = photo {
            newPath = try photos.storeImage(data: data)
        }
        let now = clock.now()
        let photoPath: String?
        switch photo {
        case .unchanged: photoPath = existing?.photoPath
        case .removed: photoPath = nil
        case .replaced: photoPath = newPath
        }
        let lure = Lure(
            id: id,
            name: fields.name,
            type: fields.type,
            lengthCm: fields.lengthCm,
            weightG: fields.weightG,
            color: fields.color,
            brand: fields.brand,
            notes: fields.notes,
            photoPath: photoPath,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            archivedAt: existing?.archivedAt
        )
        do {
            try lures.upsertLure(lure)
        } catch {
            if let newPath { photos.deletePhoto(newPath) }
            throw error
        }
        if let old = existing?.photoPath, old != lure.photoPath {
            photos.deletePhoto(old)
        }
        return lure
    }

    /// Archive hides the lure from new selections and keeps its history. Idempotent.
    @discardableResult
    func archive(id: UUID) throws -> Lure {
        guard var lure = try lures.fetchLures().first(where: { $0.id == id }) else { throw DomainError.notFound }
        guard lure.archivedAt == nil else { return lure }
        lure.archivedAt = clock.now()
        lure.updatedAt = lure.archivedAt!
        try lures.upsertLure(lure)
        return lure
    }

    /// Restore returns the lure to the active catalogue. Idempotent.
    @discardableResult
    func restore(id: UUID) throws -> Lure {
        guard var lure = try lures.fetchLures().first(where: { $0.id == id }) else { throw DomainError.notFound }
        guard lure.archivedAt != nil else { return lure }
        lure.archivedAt = nil
        lure.updatedAt = clock.now()
        try lures.upsertLure(lure)
        return lure
    }

    /// Only lures without tests can be deleted; otherwise archive is offered.
    func delete(id: UUID) throws {
        guard let lure = try lures.fetchLures().first(where: { $0.id == id }) else { return }
        if try tests.fetchTests().contains(where: { $0.lureID == id }) {
            throw DomainError.lureHasTests
        }
        try lures.deleteLure(id: id)
        if let path = lure.photoPath { photos.deletePhoto(path) }
    }
}

/// Test journal use cases. A new test and its capsule award are one transaction.
final class TestUseCases {
    private let tests: TestRepository
    private let settings: SettingsRepository
    private let policy: CapsulePolicy
    private let clock: Clock

    init(tests: TestRepository, settings: SettingsRepository, policy: CapsulePolicy, clock: Clock) {
        self.tests = tests
        self.settings = settings
        self.policy = policy
        self.clock = clock
    }

    /// Saves a new or edited test under a stable UUID. Edits never grant a capsule.
    func saveTest(id: UUID, fields: ValidatedTestFields) throws -> TestSaveResult {
        let now = clock.now()
        let existing = try tests.fetchTests().first { $0.id == id }
        let keepsSnapshot = existing?.lureID == fields.lure.id
        let test = TestEntry(
            id: id,
            lureID: fields.lure.id,
            lureNameSnapshot: keepsSnapshot ? existing!.lureNameSnapshot : fields.lure.name,
            lureTypeSnapshot: keepsSnapshot ? existing!.lureTypeSnapshot : fields.lure.type,
            placeName: fields.placeName,
            occurredAt: fields.occurredAt,
            durationMinutes: fields.durationMinutes,
            bites: fields.bites,
            catches: fields.catches,
            waterType: fields.waterType,
            clarity: fields.clarity,
            retrieve: fields.retrieve,
            weatherNote: fields.weatherNote,
            notes: fields.notes,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            completed: true
        )
        let result = try tests.saveTest(test, policy: existing == nil ? policy : nil, now: now)
        // Remember the lure for the Home bench; not critical to the commit above.
        if var current = try? settings.fetchSettings(), current.lastSelectedLureID != fields.lure.id {
            current.lastSelectedLureID = fields.lure.id
            try? settings.saveSettings(current)
        }
        return result
    }

    /// Deleting a test never revokes a capsule granted earlier; statistics are recomputed from the journal.
    func delete(id: UUID) throws {
        try tests.deleteTest(id: id)
    }
}

/// Workshop use cases: Lucky Cast and crafting. Results are committed before any animation.
final class WorkshopUseCases {
    private let repository: WorkshopRepository
    private let rules: WorkshopRules
    private let clock: Clock
    private let engine: CastEngine

    init(repository: WorkshopRepository, rules: WorkshopRules, clock: Clock) {
        self.repository = repository
        self.rules = rules
        self.clock = clock
        engine = CastEngine(rules: rules)
    }

    func snapshot() throws -> WorkshopSnapshot {
        try repository.fetchWorkshop()
    }

    /// Generates and durably commits one cast. The caller animates only after this returns.
    func cast<G: RandomNumberGenerator>(using generator: inout G) throws -> (receipt: CastReceipt, state: WorkshopState) {
        let snapshot = try repository.fetchWorkshop()
        if snapshot.pendingReceipt != nil { throw DomainError.castAlreadyPending }
        guard snapshot.state.capsules >= 1 else { throw DomainError.notEnoughCapsules }
        let matrix = engine.spin(using: &generator)
        let evaluation = engine.evaluate(matrix: matrix)
        let receipt = CastReceipt(id: UUID(), matrix: matrix, parts: evaluation.parts, createdAt: clock.now(), status: .committed)
        let state = try repository.commitCast(receipt)
        return (receipt, state)
    }

    func cast() throws -> (receipt: CastReceipt, state: WorkshopState) {
        var generator = SystemRandomNumberGenerator()
        return try cast(using: &generator)
    }

    func markPresented(_ receiptID: UUID) throws {
        try repository.markReceiptPresented(id: receiptID)
    }

    func craft(_ collectibleID: String) throws -> CraftResult {
        guard let definition = rules.collectible(collectibleID) else { throw DomainError.unknownCollectible }
        return try repository.commitCraft(collectibleID: definition.id, cost: definition.costParts, now: clock.now())
    }

    func recordClock() {
        try? repository.recordClock(now: clock.now())
    }
}
