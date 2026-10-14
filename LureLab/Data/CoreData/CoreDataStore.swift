import CoreData
import Foundation

/// Core Data implementation of every repository. All work runs serially on one private-queue
/// context; each write ends with a single `save()`, which SQLite commits as one transaction.
final class CoreDataStore {
    private let stack: CoreDataStack
    private var context: NSManagedObjectContext { stack.context }
    private let rules: WorkshopRules

    /// Test hook: makes the next write fail before committing (simulates a full disk).
    var failNextWrite = false

    init(stack: CoreDataStack, rules: WorkshopRules) {
        self.stack = stack
        self.rules = rules
    }

    // MARK: - Plumbing

    private func read<T>(_ body: (NSManagedObjectContext) throws -> T) throws -> T {
        var result: Result<T, Error> = .failure(DomainError.storage("Could not read data."))
        context.performAndWait {
            result = Result { try body(context) }
        }
        return try result.get()
    }

    private func write<T>(_ body: (NSManagedObjectContext) throws -> T) throws -> T {
        var result: Result<T, Error> = .failure(DomainError.storage("Could not save."))
        context.performAndWait {
            do {
                let value = try body(context)
                if failNextWrite {
                    failNextWrite = false
                    throw DomainError.storage("Could not save.")
                }
                if context.hasChanges { try context.save() }
                result = .success(value)
            } catch {
                context.rollback()
                result = .failure(error)
            }
        }
        return try result.get()
    }

    private func fetch(_ entity: String, _ predicate: NSPredicate? = nil, in context: NSManagedObjectContext) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.returnsObjectsAsFaults = false
        return try context.fetch(request)
    }

    private func object(_ entity: String, id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        try fetch(entity, NSPredicate(format: "id == %@", id as CVarArg), in: context).first
    }

    private func insert(_ entity: String, in context: NSManagedObjectContext) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private func workshopObject(in context: NSManagedObjectContext) throws -> NSManagedObject {
        if let existing = try fetch("WorkshopRecord", NSPredicate(format: "key == %@", "main"), in: context).first {
            return existing
        }
        let created = insert("WorkshopRecord", in: context)
        created.setValue("main", forKey: "key")
        created.setValue(0, forKey: "capsules")
        created.setValue(0, forKey: "parts")
        return created
    }

    private func settingsObject(in context: NSManagedObjectContext) throws -> NSManagedObject {
        if let existing = try fetch("SettingsRecord", NSPredicate(format: "key == %@", "main"), in: context).first {
            return existing
        }
        let created = insert("SettingsRecord", in: context)
        created.setValue("main", forKey: "key")
        return created
    }

    private func deleteAll(_ entity: String, in context: NSManagedObjectContext) throws {
        for object in try fetch(entity, in: context) { context.delete(object) }
    }
}

// MARK: - Mapping

private extension NSManagedObject {
    func uuid(_ key: String) -> UUID? { value(forKey: key) as? UUID }
    func string(_ key: String) -> String? { value(forKey: key) as? String }
    func date(_ key: String) -> Date? { value(forKey: key) as? Date }
    func int(_ key: String) -> Int? { (value(forKey: key) as? NSNumber)?.intValue }
    func bool(_ key: String) -> Bool { (value(forKey: key) as? NSNumber)?.boolValue ?? false }
    func decimal(_ key: String) -> Decimal? { (value(forKey: key) as? NSDecimalNumber)?.decimalValue }
}

extension CoreDataStore {
    fileprivate func lure(from object: NSManagedObject) -> Lure? {
        guard let id = object.uuid("id"), let name = object.string("name"),
              let type = object.string("type").flatMap(LureType.init(rawValue:)),
              let createdAt = object.date("createdAt"), let updatedAt = object.date("updatedAt")
        else { return nil }
        return Lure(id: id, name: name, type: type,
                    lengthCm: object.decimal("lengthCm"), weightG: object.decimal("weightG"),
                    color: object.string("color"), brand: object.string("brand"),
                    notes: object.string("notes") ?? "", photoPath: object.string("photoPath"),
                    createdAt: createdAt, updatedAt: updatedAt, archivedAt: object.date("archivedAt"))
    }

    fileprivate func apply(_ lure: Lure, to object: NSManagedObject) {
        object.setValue(lure.id, forKey: "id")
        object.setValue(lure.name, forKey: "name")
        object.setValue(lure.type.rawValue, forKey: "type")
        object.setValue(lure.lengthCm.map { NSDecimalNumber(decimal: $0) }, forKey: "lengthCm")
        object.setValue(lure.weightG.map { NSDecimalNumber(decimal: $0) }, forKey: "weightG")
        object.setValue(lure.color, forKey: "color")
        object.setValue(lure.brand, forKey: "brand")
        object.setValue(lure.notes, forKey: "notes")
        object.setValue(lure.photoPath, forKey: "photoPath")
        object.setValue(lure.createdAt, forKey: "createdAt")
        object.setValue(lure.updatedAt, forKey: "updatedAt")
        object.setValue(lure.archivedAt, forKey: "archivedAt")
    }

    fileprivate func test(from object: NSManagedObject) -> TestEntry? {
        guard let id = object.uuid("id"), let lureID = object.uuid("lureID"),
              let snapshotName = object.string("lureNameSnapshot"),
              let snapshotType = object.string("lureTypeSnapshot").flatMap(LureType.init(rawValue:)),
              let place = object.string("placeName"), let occurredAt = object.date("occurredAt"),
              let duration = object.int("durationMinutes"),
              let createdAt = object.date("createdAt"), let updatedAt = object.date("updatedAt")
        else { return nil }
        return TestEntry(id: id, lureID: lureID, lureNameSnapshot: snapshotName, lureTypeSnapshot: snapshotType,
                         placeName: place, occurredAt: occurredAt, durationMinutes: duration,
                         bites: object.int("bites"), catches: object.int("catches"),
                         waterType: object.string("waterType").flatMap(WaterType.init(rawValue:)),
                         clarity: object.string("clarity").flatMap(WaterClarity.init(rawValue:)),
                         retrieve: object.string("retrieve").flatMap(RetrieveStyle.init(rawValue:)),
                         weatherNote: object.string("weatherNote") ?? "", notes: object.string("notes") ?? "",
                         createdAt: createdAt, updatedAt: updatedAt, completed: object.bool("completed"))
    }

    fileprivate func apply(_ test: TestEntry, to object: NSManagedObject) {
        object.setValue(test.id, forKey: "id")
        object.setValue(test.lureID, forKey: "lureID")
        object.setValue(test.lureNameSnapshot, forKey: "lureNameSnapshot")
        object.setValue(test.lureTypeSnapshot.rawValue, forKey: "lureTypeSnapshot")
        object.setValue(test.placeName, forKey: "placeName")
        object.setValue(test.occurredAt, forKey: "occurredAt")
        object.setValue(test.durationMinutes, forKey: "durationMinutes")
        object.setValue(test.bites.map { NSNumber(value: $0) }, forKey: "bites")
        object.setValue(test.catches.map { NSNumber(value: $0) }, forKey: "catches")
        object.setValue(test.waterType?.rawValue, forKey: "waterType")
        object.setValue(test.clarity?.rawValue, forKey: "clarity")
        object.setValue(test.retrieve?.rawValue, forKey: "retrieve")
        object.setValue(test.weatherNote, forKey: "weatherNote")
        object.setValue(test.notes, forKey: "notes")
        object.setValue(test.createdAt, forKey: "createdAt")
        object.setValue(test.updatedAt, forKey: "updatedAt")
        object.setValue(test.completed, forKey: "completed")
    }

    fileprivate func workshopState(from object: NSManagedObject) -> WorkshopState {
        WorkshopState(capsules: object.int("capsules") ?? 0, parts: object.int("parts") ?? 0,
                      nextEligibleAt: object.date("nextEligibleAt"), lastSeenAt: object.date("lastSeenAt"))
    }

    fileprivate func apply(_ state: WorkshopState, to object: NSManagedObject) {
        object.setValue(state.capsules, forKey: "capsules")
        object.setValue(state.parts, forKey: "parts")
        object.setValue(state.nextEligibleAt, forKey: "nextEligibleAt")
        object.setValue(state.lastSeenAt, forKey: "lastSeenAt")
    }

    fileprivate static func encodeMatrix(_ matrix: [[CastSymbol]]) -> String {
        matrix.map { row in row.map(\.rawValue).joined(separator: ",") }.joined(separator: ";")
    }

    fileprivate static func decodeMatrix(_ text: String) -> [[CastSymbol]]? {
        let rows = text.split(separator: ";").map { row in row.split(separator: ",").compactMap { CastSymbol(rawValue: String($0)) } }
        return rows.isEmpty ? nil : rows
    }

    fileprivate func receipt(from object: NSManagedObject) -> CastReceipt? {
        guard let id = object.uuid("id"), let matrixText = object.string("matrix"),
              let matrix = Self.decodeMatrix(matrixText), let parts = object.int("parts"),
              let createdAt = object.date("createdAt"),
              let status = object.string("status").flatMap(CastReceiptStatus.init(rawValue:))
        else { return nil }
        return CastReceipt(id: id, matrix: matrix, parts: parts, createdAt: createdAt, status: status)
    }

    fileprivate func apply(_ receipt: CastReceipt, to object: NSManagedObject) {
        object.setValue(receipt.id, forKey: "id")
        object.setValue(Self.encodeMatrix(receipt.matrix), forKey: "matrix")
        object.setValue(receipt.parts, forKey: "parts")
        object.setValue(receipt.createdAt, forKey: "createdAt")
        object.setValue(receipt.status.rawValue, forKey: "status")
    }

    fileprivate func award(from object: NSManagedObject) -> CapsuleAward? {
        guard let id = object.uuid("id"), let testID = object.uuid("testID"), let grantedAt = object.date("grantedAt") else { return nil }
        return CapsuleAward(id: id, testID: testID, grantedAt: grantedAt, delta: object.int("delta") ?? 1)
    }

    fileprivate func apply(_ award: CapsuleAward, to object: NSManagedObject) {
        object.setValue(award.id, forKey: "id")
        object.setValue(award.testID, forKey: "testID")
        object.setValue(award.grantedAt, forKey: "grantedAt")
        object.setValue(award.delta, forKey: "delta")
    }

    fileprivate func collectible(from object: NSManagedObject) -> CollectibleRecord? {
        guard let id = object.string("id"), let craftedAt = object.date("craftedAt") else { return nil }
        return CollectibleRecord(id: id, craftedAt: craftedAt)
    }

    fileprivate func draft(from object: NSManagedObject) -> Draft? {
        guard let id = object.uuid("id"), let kind = object.string("kind").flatMap(DraftKind.init(rawValue:)),
              let payload = object.value(forKey: "payload") as? Data, let updatedAt = object.date("updatedAt")
        else { return nil }
        return Draft(id: id, kind: kind, payload: payload, updatedAt: updatedAt)
    }

    fileprivate func apply(_ draft: Draft, to object: NSManagedObject) {
        object.setValue(draft.id, forKey: "id")
        object.setValue(draft.kind.rawValue, forKey: "kind")
        object.setValue(draft.payload, forKey: "payload")
        object.setValue(draft.updatedAt, forKey: "updatedAt")
    }

    fileprivate func settings(from object: NSManagedObject) -> AppSettings {
        AppSettings(hapticsEnabled: object.bool("hapticsEnabled"),
                    reduceMotion: object.bool("reduceMotion"),
                    units: object.string("units").flatMap(UnitSystem.init(rawValue:)) ?? .metric,
                    onboardingCompleted: object.bool("onboardingCompleted"),
                    lastSelectedLureID: object.uuid("lastSelectedLureID"))
    }

    fileprivate func apply(_ settings: AppSettings, to object: NSManagedObject) {
        object.setValue(settings.hapticsEnabled, forKey: "hapticsEnabled")
        object.setValue(settings.reduceMotion, forKey: "reduceMotion")
        object.setValue(settings.units.rawValue, forKey: "units")
        object.setValue(settings.onboardingCompleted, forKey: "onboardingCompleted")
        object.setValue(settings.lastSelectedLureID, forKey: "lastSelectedLureID")
    }
}

// MARK: - Repositories

extension CoreDataStore: LureRepository {
    func fetchLures() throws -> [Lure] {
        try read { context in try fetch("LureRecord", in: context).compactMap(lure(from:)) }
    }

    func upsertLure(_ lure: Lure) throws {
        try write { context in
            let object = try object("LureRecord", id: lure.id, in: context) ?? insert("LureRecord", in: context)
            apply(lure, to: object)
        }
    }

    func deleteLure(id: UUID) throws {
        try write { context in
            let linked = try fetch("TestRecord", NSPredicate(format: "lureID == %@", id as CVarArg), in: context)
            guard linked.isEmpty else { throw DomainError.lureHasTests }
            if let object = try object("LureRecord", id: id, in: context) { context.delete(object) }
            // Keep Home pointing at an existing lure.
            let settingsObject = try settingsObject(in: context)
            if settingsObject.uuid("lastSelectedLureID") == id {
                settingsObject.setValue(nil, forKey: "lastSelectedLureID")
            }
        }
    }
}

extension CoreDataStore: TestRepository {
    func fetchTests() throws -> [TestEntry] {
        try read { context in try fetch("TestRecord", in: context).compactMap(test(from:)) }
    }

    func saveTest(_ test: TestEntry, policy: CapsulePolicy?, now: Date) throws -> TestSaveResult {
        try write { context in
            let workshopObject = try workshopObject(in: context)
            var state = workshopState(from: workshopObject)
            if let existing = try object("TestRecord", id: test.id, in: context) {
                // Same UUID again (edit, double tap or retry after success): update only, never reward twice.
                var updated = test
                if let storedCreatedAt = existing.date("createdAt") {
                    updated = TestEntry(
                        id: test.id, lureID: test.lureID,
                        lureNameSnapshot: test.lureNameSnapshot, lureTypeSnapshot: test.lureTypeSnapshot,
                        placeName: test.placeName, occurredAt: test.occurredAt, durationMinutes: test.durationMinutes,
                        bites: test.bites, catches: test.catches,
                        waterType: test.waterType, clarity: test.clarity, retrieve: test.retrieve,
                        weatherNote: test.weatherNote, notes: test.notes,
                        createdAt: storedCreatedAt, updatedAt: test.updatedAt, completed: true
                    )
                }
                apply(updated, to: existing)
                return TestSaveResult(test: updated, wasInserted: false, capsule: .notApplicable, workshop: state)
            }
            let object = insert("TestRecord", in: context)
            apply(test, to: object)
            guard let policy else {
                return TestSaveResult(test: test, wasInserted: true, capsule: .notApplicable, workshop: state)
            }
            let decision = policy.evaluate(state: state, now: now)
            let granted = policy.apply(decision, to: &state, now: now)
            apply(state, to: workshopObject)
            let outcome: CapsuleOutcome
            if granted {
                let award = CapsuleAward(id: UUID(), testID: test.id, grantedAt: now, delta: 1)
                apply(award, to: insert("AwardRecord", in: context))
                outcome = .earned
            } else if case .capped = decision {
                outcome = .shelfFull
            } else {
                outcome = .notEligible(nextAt: state.nextEligibleAt)
            }
            return TestSaveResult(test: test, wasInserted: true, capsule: outcome, workshop: state)
        }
    }

    func deleteTest(id: UUID) throws {
        try write { context in
            if let object = try object("TestRecord", id: id, in: context) { context.delete(object) }
        }
    }
}

extension CoreDataStore: WorkshopRepository {
    func fetchWorkshop() throws -> WorkshopSnapshot {
        try read { context in
            let stateObject = try fetch("WorkshopRecord", NSPredicate(format: "key == %@", "main"), in: context).first
            return WorkshopSnapshot(
                state: stateObject.map(workshopState(from:)) ?? WorkshopState(),
                receipts: try fetch("ReceiptRecord", in: context).compactMap(receipt(from:)),
                collectibles: try fetch("CollectibleRecord", in: context).compactMap(collectible(from:)),
                ledger: try fetch("AwardRecord", in: context).compactMap(award(from:))
            )
        }
    }

    func commitCast(_ receipt: CastReceipt) throws -> WorkshopState {
        try write { context in
            let workshopObject = try workshopObject(in: context)
            var state = workshopState(from: workshopObject)
            if try object("ReceiptRecord", id: receipt.id, in: context) != nil {
                return state
            }
            let pending = try fetch("ReceiptRecord", NSPredicate(format: "status == %@", CastReceiptStatus.committed.rawValue), in: context)
            guard pending.isEmpty else { throw DomainError.castAlreadyPending }
            guard state.capsules >= 1 else { throw DomainError.notEnoughCapsules }
            state.capsules -= 1
            state.parts += receipt.parts
            state.lastSeenAt = max(state.lastSeenAt ?? receipt.createdAt, receipt.createdAt)
            apply(state, to: workshopObject)
            var committed = receipt
            committed.status = .committed
            apply(committed, to: insert("ReceiptRecord", in: context))
            return state
        }
    }

    func markReceiptPresented(id: UUID) throws {
        try write { context in
            guard let object = try object("ReceiptRecord", id: id, in: context) else { return }
            object.setValue(CastReceiptStatus.presented.rawValue, forKey: "status")
        }
    }

    func commitCraft(collectibleID: String, cost: Int, now: Date) throws -> CraftResult {
        try write { context in
            if let existing = try fetch("CollectibleRecord", NSPredicate(format: "id == %@", collectibleID), in: context).first,
               let record = collectible(from: existing) {
                return .alreadyCrafted(record)
            }
            let workshopObject = try workshopObject(in: context)
            var state = workshopState(from: workshopObject)
            guard state.parts >= cost else { throw DomainError.notEnoughParts }
            state.parts -= cost
            apply(state, to: workshopObject)
            let record = CollectibleRecord(id: collectibleID, craftedAt: now)
            let object = insert("CollectibleRecord", in: context)
            object.setValue(record.id, forKey: "id")
            object.setValue(record.craftedAt, forKey: "craftedAt")
            return .crafted(record)
        }
    }

    func recordClock(now: Date) throws {
        try write { context in
            let object = try workshopObject(in: context)
            var state = workshopState(from: object)
            if let last = state.lastSeenAt, last >= now { return }
            state.lastSeenAt = now
            apply(state, to: object)
        }
    }
}

extension CoreDataStore: DraftRepository {
    func fetchDrafts() throws -> [Draft] {
        try read { context in try fetch("DraftRecord", in: context).compactMap(draft(from:)) }
    }

    func saveDraft(_ draft: Draft) throws {
        try write { context in
            let object = try object("DraftRecord", id: draft.id, in: context) ?? insert("DraftRecord", in: context)
            apply(draft, to: object)
        }
    }

    func deleteDraft(id: UUID) throws {
        try write { context in
            if let object = try object("DraftRecord", id: id, in: context) { context.delete(object) }
        }
    }
}

extension CoreDataStore: SettingsRepository {
    func fetchSettings() throws -> AppSettings {
        try read { context in
            guard let object = try fetch("SettingsRecord", NSPredicate(format: "key == %@", "main"), in: context).first else {
                return AppSettings()
            }
            return settings(from: object)
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        try write { context in
            apply(settings, to: try settingsObject(in: context))
        }
    }
}

extension CoreDataStore: SnapshotRepository {
    func exportSnapshot() throws -> DatabaseSnapshot {
        try read { context in
            let workshop = try fetch("WorkshopRecord", NSPredicate(format: "key == %@", "main"), in: context).first
            let settingsObject = try fetch("SettingsRecord", NSPredicate(format: "key == %@", "main"), in: context).first
            return DatabaseSnapshot(
                lures: try fetch("LureRecord", in: context).compactMap(lure(from:)),
                tests: try fetch("TestRecord", in: context).compactMap(test(from:)),
                drafts: try fetch("DraftRecord", in: context).compactMap(draft(from:)),
                ledger: try fetch("AwardRecord", in: context).compactMap(award(from:)),
                castReceipts: try fetch("ReceiptRecord", in: context).compactMap(receipt(from:)),
                collectibles: try fetch("CollectibleRecord", in: context).compactMap(collectible(from:)),
                settings: settingsObject.map(settings(from:)) ?? AppSettings(),
                workshop: workshop.map(workshopState(from:)) ?? WorkshopState()
            )
        }
    }

    func replaceAll(with snapshot: DatabaseSnapshot) throws {
        try write { context in
            for entity in ["LureRecord", "TestRecord", "DraftRecord", "AwardRecord", "ReceiptRecord", "CollectibleRecord", "WorkshopRecord", "SettingsRecord"] {
                try deleteAll(entity, in: context)
            }
            for lure in snapshot.lures { apply(lure, to: insert("LureRecord", in: context)) }
            for test in snapshot.tests { apply(test, to: insert("TestRecord", in: context)) }
            for draft in snapshot.drafts { apply(draft, to: insert("DraftRecord", in: context)) }
            for award in snapshot.ledger { apply(award, to: insert("AwardRecord", in: context)) }
            for receipt in snapshot.castReceipts { apply(receipt, to: insert("ReceiptRecord", in: context)) }
            for record in snapshot.collectibles {
                let object = insert("CollectibleRecord", in: context)
                object.setValue(record.id, forKey: "id")
                object.setValue(record.craftedAt, forKey: "craftedAt")
            }
            let workshopObject = insert("WorkshopRecord", in: context)
            workshopObject.setValue("main", forKey: "key")
            apply(snapshot.workshop, to: workshopObject)
            let settingsObject = insert("SettingsRecord", in: context)
            settingsObject.setValue("main", forKey: "key")
            apply(snapshot.settings, to: settingsObject)
        }
    }
}
