#if DEBUG
import Foundation

/// DEBUG-only screenshot harness. Launch with LURELAB_SCENARIO=<id> to open a screen on an
/// in-memory store seeded with the mockup fixtures. Never touches the on-disk journal and is
/// compiled out of Release builds.
enum DebugScenario {
    static var name: String? { ProcessInfo.processInfo.environment["LURELAB_SCENARIO"] }
    static var hook: String? { ProcessInfo.processInfo.environment["LURELAB_HOOK"] }

    static func isHook(_ value: String) -> Bool { hook == value }

    @MainActor
    static func makeModel(rules: WorkshopRules) throws -> AppModel? {
        guard let name else { return nil }
        let stack = try CoreDataStack(store: .inMemory)
        let store = CoreDataStore(stack: stack, rules: rules)
        let photoDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("DebugPhotos-\(UUID().uuidString)")
        let photos = FilePhotoStore(directory: photoDirectory)
        try store.replaceAll(with: snapshot(for: name))
        let clock = SystemClock()
        let backup = BackupService(snapshots: store, workshop: store, photos: photos, rules: rules, clock: clock)
        return AppModel(rules: rules, photoStore: photos, lures: store, tests: store, workshop: store,
                        drafts: store, settings: store, backup: backup, clock: clock)
    }

    /// Tab and stack to open for a scenario id (matches design/screens numbering).
    static func navigation(for name: String) -> (AppTab, [Route]) {
        switch name {
        case "06": return (.journal, [.journal(TestFilter())])
        case "07": return (.journal, [.journal(TestFilter())])
        case "08", "09", "37": return (.lures, [])
        case "10": return (.lures, [.lureDetail(Fixtures.silverMinnow)])
        case "11", "12", "41": return (.lures, [.lureEditor(nil)])
        case "13", "14", "35", "38", "39", "40": return (.journal, [.testEditor(.new(lureID: nil))])
        case "15": return (.journal, [.testDetail(Fixtures.test1)])
        case "16": return (.journal, [.testSaved(TestSavedSummary(testID: Fixtures.test1, capsule: .earned))])
        case "17", "18": return (.compare, [])
        case "19": return (.workshop, [])
        case "20", "21", "22", "23", "44": return (.workshop, [.luckyCast])
        case "24", "25", "42": return (.workshop, [.showcase])
        case "26", "27", "28": return (.workshop, [.showcase, .collectible("L01")])
        case "29": return (.journal, [.settings])
        case "30", "32", "33": return (.journal, [.settings, .data])
        case "34": return (.workshop, [.workshopGuide])
        case "36": return (.journal, [.settings, .data, .archived])
        case "43": return (.workshop, [.workshopGuide, .rewardDetails])
        case "45": return (.journal, [.settings, .units])
        case "46": return (.journal, [.settings, .about])
        default: return (.journal, [])
        }
    }

    enum Fixtures {
        static let silverMinnow = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        static let copperSpinner = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        static let reedTail = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
        static let test1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
    }

    private static func date(_ day: Int, _ hour: Int = 10) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func snapshot(for name: String) -> DatabaseSnapshot {
        var snapshot = DatabaseSnapshot()
        snapshot.settings.onboardingCompleted = !["01", "02", "03", "e2e"].contains(name)
        if ["01", "02", "03", "05", "09", "18", "e2e"].contains(name) { return snapshot }

        let created = date(1)
        let silver = Lure(id: Fixtures.silverMinnow, name: "Silver Minnow", type: .minnow, lengthCm: 9, weightG: 12,
                          color: "Silver / blue", brand: nil, notes: "Shallow-running lure. Replaced rear hook in October.",
                          photoPath: nil, createdAt: created, updatedAt: created, archivedAt: nil)
        let copper = Lure(id: Fixtures.copperSpinner, name: "Copper Spinner", type: .spinner, lengthCm: nil, weightG: 7,
                          color: nil, brand: nil, notes: "", photoPath: nil, createdAt: created, updatedAt: created, archivedAt: nil)
        let reed = Lure(id: Fixtures.reedTail, name: "Reed Tail", type: .softBait, lengthCm: 8, weightG: nil,
                        color: nil, brand: nil, notes: "", photoPath: nil, createdAt: created, updatedAt: created, archivedAt: nil)
        snapshot.lures = [silver, copper, reed]
        if name == "36" {
            snapshot.lures[0].archivedAt = date(11)
            snapshot.lures[1].archivedAt = date(9)
        }
        snapshot.settings.lastSelectedLureID = silver.id

        func test(_ id: UUID, _ lure: Lure, _ place: String, _ day: Int, _ minutes: Int, _ bites: Int?, _ catches: Int?) -> TestEntry {
            TestEntry(id: id, lureID: lure.id, lureNameSnapshot: lure.name, lureTypeSnapshot: lure.type, placeName: place,
                      occurredAt: date(day), durationMinutes: minutes, bites: bites, catches: catches,
                      waterType: .coast, clarity: .clear, retrieve: .slow, weatherNote: "Light breeze",
                      notes: "Steady retrieve near the rocks. Two catches released.", createdAt: date(day), updatedAt: date(day))
        }
        if name != "07" {
            snapshot.tests = [
                test(Fixtures.test1, silver, "North Pier", 12, 45, 6, 2),
                test(UUID(), silver, "Willow Lake", 10, 30, 0, 0),
                test(UUID(), silver, "North Pier", 8, 60, nil, 1),
                test(UUID(), silver, "Stone Bay", 2, 45, 5, 3),
                test(UUID(), copper, "Willow Lake", 9, 60, 3, 1),
                test(UUID(), copper, "North Pier", 5, 60, 2, 1)
            ]
        }

        // Workshop fixtures per state.
        var workshop = WorkshopState(capsules: 1, parts: 3, nextEligibleAt: nil, lastSeenAt: nil)
        switch name {
        case "23": workshop = WorkshopState(capsules: 0, parts: 1)
        case "44": workshop = WorkshopState(capsules: 0, parts: 1, nextEligibleAt: Date().addingTimeInterval(20 * 3600))
        case "27": workshop.parts = 1
        case "31": workshop = WorkshopState() // backups must be ledger-consistent
        default: break
        }
        if name == "22" {
            workshop.capsules = 0
            workshop.parts = 5
            snapshot.castReceipts = [CastReceipt(id: UUID(), matrix: [
                [.s01, .s02, .s03, .s04, .s05],
                [.s06, .s06, .s06, .s01, .s02],
                [.s03, .s05, .s04, .s02, .s06]
            ], parts: 2, createdAt: Date(), status: .committed)]
        }
        snapshot.workshop = workshop
        switch name {
        case "24": snapshot.collectibles = [CollectibleRecord(id: "L01", craftedAt: date(11)), CollectibleRecord(id: "L02", craftedAt: date(12))]
        case "42": snapshot.collectibles = ["L01", "L02", "L03", "L04"].map { CollectibleRecord(id: $0, craftedAt: date(12)) }
        default: break
        }

        // Drafts that reproduce the filled forms of screens 11 and 13.
        if ["11", "12", "41"].contains(name) {
            let payload = LureDraftPayload(isEditing: false, name: "Silver Minnow", type: .minnow, lengthText: "9", weightText: "12",
                                           color: "Silver / blue", brand: "", notes: "Shallow-running lure. Replaced rear hook in October.")
            snapshot.drafts = [Draft(id: UUID(), kind: .lure, payload: (try? JSONEncoder().encode(payload)) ?? Data(), updatedAt: Date())]
        }
        if ["13", "14", "35", "38", "39", "40"].contains(name) {
            let payload = TestDraftPayload(isEditing: false, lureID: silver.id, placeName: "North Pier", occurredAt: date(13, 9),
                                           durationText: name == "40" ? "" : "45", bites: 6, catches: name == "40" ? 8 : 2,
                                           waterType: .coast, clarity: .clear, retrieve: .slow, weatherNote: "Light breeze",
                                           notes: "Steady retrieve near the rocks.")
            snapshot.drafts = [Draft(id: UUID(), kind: .test, payload: (try? JSONEncoder().encode(payload)) ?? Data(), updatedAt: Date())]
        }
        return snapshot
    }
}
#endif
