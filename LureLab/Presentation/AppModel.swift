import SwiftUI

/// Presentation store: loads snapshots from the repositories and exposes the use cases to views.
/// Data volumes are small, so every committed change simply reloads the snapshot.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var lures: [Lure] = []
    @Published private(set) var tests: [TestEntry] = []
    @Published private(set) var workshop = WorkshopSnapshot(state: WorkshopState(), receipts: [], collectibles: [], ledger: [])
    @Published private(set) var settings = AppSettings()
    @Published private(set) var drafts: [Draft] = []
    /// Validated backup waiting for "Replace Local Data".
    @Published var preparedImport: PreparedImport?

    let rules: WorkshopRules
    let photos: PhotoLibrary
    private let lureUseCases: LureUseCases
    private let testUseCases: TestUseCases
    private let workshopUseCases: WorkshopUseCases
    let backup: BackupServicing
    private let lureRepository: LureRepository
    private let testRepository: TestRepository
    private let workshopRepository: WorkshopRepository
    private let draftRepository: DraftRepository
    private let settingsRepository: SettingsRepository
    private let clock: Clock

    init(rules: WorkshopRules,
         photoStore: PhotoStore,
         lures: LureRepository,
         tests: TestRepository,
         workshop: WorkshopRepository,
         drafts: DraftRepository,
         settings: SettingsRepository,
         backup: BackupServicing,
         clock: Clock = SystemClock()) {
        self.rules = rules
        self.photos = PhotoLibrary(store: photoStore)
        self.lureRepository = lures
        self.testRepository = tests
        self.workshopRepository = workshop
        self.draftRepository = drafts
        self.settingsRepository = settings
        self.backup = backup
        self.clock = clock
        lureUseCases = LureUseCases(lures: lures, tests: tests, photos: photoStore, clock: clock)
        testUseCases = TestUseCases(tests: tests, settings: settings, policy: CapsulePolicy(rules: rules), clock: clock)
        workshopUseCases = WorkshopUseCases(repository: workshop, rules: rules, clock: clock)
        reload()
        workshopUseCases.recordClock()
        cleanOrphanPhotos(store: photoStore)
    }

    func reload() {
        lures = (try? lureRepository.fetchLures()) ?? []
        tests = ((try? testRepository.fetchTests()) ?? []).sortedForJournal()
        if let snapshot = try? workshopRepository.fetchWorkshop() { workshop = snapshot }
        settings = (try? settingsRepository.fetchSettings()) ?? AppSettings()
        drafts = (try? draftRepository.fetchDrafts()) ?? []
    }

    /// Photos written before a crash but never committed to the database.
    private func cleanOrphanPhotos(store: PhotoStore) {
        // Only when the catalogue was read successfully; never on a failed read.
        guard let current = try? lureRepository.fetchLures() else { return }
        let referenced = Set(current.compactMap(\.photoPath))
        for path in store.storedPaths() where !referenced.contains(path) {
            store.deletePhoto(path)
        }
    }

    var now: Date { clock.now() }

    // MARK: Queries

    /// Most recently used first: latest test or edit, then name.
    var activeLures: [Lure] {
        var lastActivity: [UUID: Date] = [:]
        for test in tests { lastActivity[test.lureID] = max(lastActivity[test.lureID] ?? .distantPast, test.occurredAt) }
        return lures.filter { !$0.isArchived }.sorted { first, second in
            let a = max(lastActivity[first.id] ?? .distantPast, first.updatedAt)
            let b = max(lastActivity[second.id] ?? .distantPast, second.updatedAt)
            if a != b { return a > b }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    var archivedLures: [Lure] {
        lures.filter(\.isArchived).sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func lure(_ id: UUID?) -> Lure? {
        guard let id else { return nil }
        return lures.first { $0.id == id }
    }

    func test(_ id: UUID) -> TestEntry? { tests.first { $0.id == id } }

    func tests(for lureID: UUID) -> [TestEntry] { tests.filter { $0.lureID == lureID } }

    func testCount(for lureID: UUID) -> Int { tests.reduce(0) { $0 + ($1.lureID == lureID ? 1 : 0) } }

    /// Name shown for a test: the current lure name when it still exists, else the historical snapshot.
    func displayLureName(for test: TestEntry) -> String {
        lure(test.lureID)?.name ?? test.lureNameSnapshot
    }

    /// Home bench: last chosen active lure, else the most recently updated active lure.
    var benchLure: Lure? {
        if let selected = lure(settings.lastSelectedLureID), !selected.isArchived { return selected }
        if let latest = tests.first, let fromTest = lure(latest.lureID), !fromTest.isArchived { return fromTest }
        return lures.filter { !$0.isArchived }.max { $0.updatedAt < $1.updatedAt }
    }

    var latestTest: TestEntry? { tests.first }

    var capsuleState: WorkshopState { workshop.state }

    var craftedIDs: Set<String> { Set(workshop.collectibles.map(\.id)) }

    func crafted(_ id: String) -> CollectibleRecord? { workshop.collectibles.first { $0.id == id } }

    var testDraft: Draft? {
        drafts.filter { $0.kind == .test }.max { $0.updatedAt < $1.updatedAt }
    }

    // MARK: Lures

    @discardableResult
    func saveLure(id: UUID, fields: ValidatedLureFields, photo: PhotoChange) throws -> Lure {
        defer { reload() }
        let lure = try lureUseCases.saveLure(id: id, fields: fields, photo: photo)
        if case .replaced = photo { photos.clear() }
        return lure
    }

    func archiveLure(_ id: UUID) throws {
        defer { reload() }
        try lureUseCases.archive(id: id)
    }

    func restoreLure(_ id: UUID) throws {
        defer { reload() }
        try lureUseCases.restore(id: id)
    }

    func deleteLure(_ id: UUID) throws {
        defer { reload() }
        try lureUseCases.delete(id: id)
    }

    // MARK: Tests

    func saveTest(id: UUID, fields: ValidatedTestFields) throws -> TestSaveResult {
        defer { reload() }
        let result = try testUseCases.saveTest(id: id, fields: fields)
        try? draftRepository.deleteDraft(id: id)
        return result
    }

    func deleteTest(_ id: UUID) throws {
        defer { reload() }
        try testUseCases.delete(id: id)
    }

    // MARK: Drafts

    func saveDraft(_ draft: Draft) {
        try? draftRepository.saveDraft(draft)
        drafts = (try? draftRepository.fetchDrafts()) ?? drafts
    }

    func deleteDraft(_ id: UUID) {
        try? draftRepository.deleteDraft(id: id)
        drafts = (try? draftRepository.fetchDrafts()) ?? drafts
    }

    // MARK: Workshop

    func cast() throws -> CastReceipt {
        defer { reload() }
        return try workshopUseCases.cast().receipt
    }

    func markPresented(_ receiptID: UUID) {
        try? workshopUseCases.markPresented(receiptID)
        reload()
    }

    func craft(_ id: String) throws -> CraftResult {
        defer { reload() }
        return try workshopUseCases.craft(id)
    }

    func recordClock() {
        workshopUseCases.recordClock()
    }

    // MARK: Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        try? settingsRepository.saveSettings(updated)
    }

    // MARK: Backup

    /// Call after `BackupServicing.applyImport` succeeded for `preparedImport`.
    func finishImport() {
        preparedImport = nil
        photos.clear()
        reload()
    }

    func discardPreparedImport() {
        if let prepared = preparedImport { backup.discard(prepared) }
        preparedImport = nil
    }

    func deleteAllData() throws {
        defer { reload() }
        try backup.deleteAllData()
        photos.clear()
    }
}
