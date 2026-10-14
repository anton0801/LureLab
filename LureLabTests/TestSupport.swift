import UIKit
import XCTest
@testable import LureLab

final class TestClock: Clock {
    var current: Date
    init(_ date: Date = Date(timeIntervalSince1970: 1_791_000_000)) { current = date }
    func now() -> Date { current }
    func advance(hours: Double) { current = current.addingTimeInterval(hours * 3600) }
}

/// In-memory SQLite Core Data store + temporary photo directory, wired like the app.
final class TestEnvironment {
    let rules = WorkshopRules.fallback
    let clock = TestClock()
    let store: CoreDataStore
    let photos: FilePhotoStore
    let photoDirectory: URL
    lazy var lureUseCases = LureUseCases(lures: store, tests: store, photos: photos, clock: clock)
    lazy var testUseCases = TestUseCases(tests: store, settings: store, policy: CapsulePolicy(rules: rules), clock: clock)
    lazy var workshop = WorkshopUseCases(repository: store, rules: rules, clock: clock)
    lazy var backup = BackupService(snapshots: store, workshop: store, photos: photos, rules: rules, clock: clock, appVersion: "1.0")

    init() throws {
        store = CoreDataStore(stack: try CoreDataStack(store: .inMemory), rules: rules)
        photoDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("LureLabTests-\(UUID().uuidString)")
        photos = FilePhotoStore(directory: photoDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: photoDirectory)
    }

    func lureFields(name: String = "Silver Minnow", type: LureType = .minnow) -> ValidatedLureFields {
        ValidatedLureFields(name: name, type: type, lengthCm: 9, weightG: 12, color: nil, brand: nil, notes: "")
    }

    @discardableResult
    func addLure(name: String = "Silver Minnow", photo: PhotoChange = .unchanged) throws -> Lure {
        try lureUseCases.saveLure(id: UUID(), fields: lureFields(name: name), photo: photo)
    }

    func testFields(lure: Lure, minutes: Int = 45, bites: Int? = 6, catches: Int? = 2, place: String = "North Pier") -> ValidatedTestFields {
        ValidatedTestFields(lure: lure, placeName: place, occurredAt: clock.now().addingTimeInterval(-600), durationMinutes: minutes,
                            bites: bites, catches: catches, waterType: .coast, clarity: .clear, retrieve: .slow,
                            weatherNote: "", notes: "")
    }

    @discardableResult
    func logTest(_ lure: Lure, id: UUID = UUID(), minutes: Int = 45, bites: Int? = 6, catches: Int? = 2) throws -> TestSaveResult {
        try testUseCases.saveTest(id: id, fields: testFields(lure: lure, minutes: minutes, bites: bites, catches: catches))
    }

    static func samplePNG(color: UIColor = .systemTeal) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30))
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }
}
