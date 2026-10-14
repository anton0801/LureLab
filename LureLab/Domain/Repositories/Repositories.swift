import Foundation

enum DomainError: Error, Equatable, LocalizedError {
    case notFound
    case lureHasTests
    case notEnoughCapsules
    case castAlreadyPending
    case notEnoughParts
    case unknownCollectible
    case pendingReceiptBlocksImport
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "This item no longer exists."
        case .lureHasTests: return "This lure has saved tests. Archive it to keep its history."
        case .notEnoughCapsules: return "No capsules available."
        case .castAlreadyPending: return "Finish the current Lucky Cast first."
        case .notEnoughParts: return "Not enough Parts yet."
        case .unknownCollectible: return "Unknown collectible."
        case .pendingReceiptBlocksImport: return "Open Lucky Cast to finish the current result before importing."
        case let .storage(message): return message
        }
    }
}

/// Everything persisted, in the backup `database.json` shape (schema v1).
struct DatabaseSnapshot: Codable, Equatable {
    var lures: [Lure] = []
    var tests: [TestEntry] = []
    var drafts: [Draft] = []
    var ledger: [CapsuleAward] = []
    var castReceipts: [CastReceipt] = []
    var collectibles: [CollectibleRecord] = []
    var settings: AppSettings = AppSettings()
    var workshop: WorkshopState = WorkshopState()
}

struct WorkshopSnapshot: Equatable {
    var state: WorkshopState
    var receipts: [CastReceipt]
    var collectibles: [CollectibleRecord]
    var ledger: [CapsuleAward]

    var pendingReceipt: CastReceipt? {
        receipts.filter { $0.status == .committed }.max { $0.createdAt < $1.createdAt }
    }
}

struct TestSaveResult: Equatable {
    let test: TestEntry
    let wasInserted: Bool
    let capsule: CapsuleOutcome
    let workshop: WorkshopState
}

enum CraftResult: Equatable {
    case crafted(CollectibleRecord)
    /// Idempotent repeat: already crafted, nothing spent.
    case alreadyCrafted(CollectibleRecord)
}

protocol LureRepository: AnyObject {
    func fetchLures() throws -> [Lure]
    /// Insert or update by id (idempotent).
    func upsertLure(_ lure: Lure) throws
    /// Fails with `.lureHasTests` when tests reference the lure.
    func deleteLure(id: UUID) throws
}

protocol TestRepository: AnyObject {
    func fetchTests() throws -> [TestEntry]
    /// Inserts or updates a test. When `policy` is given and the id is new, the capsule
    /// decision and ledger row are committed in the same transaction as the test.
    func saveTest(_ test: TestEntry, policy: CapsulePolicy?, now: Date) throws -> TestSaveResult
    func deleteTest(id: UUID) throws
}

protocol WorkshopRepository: AnyObject {
    func fetchWorkshop() throws -> WorkshopSnapshot
    /// Atomically: balance ≥ 1, no other pending receipt, spend 1 capsule, add parts, store receipt.
    /// Re-committing the same receipt id is a no-op.
    func commitCast(_ receipt: CastReceipt) throws -> WorkshopState
    func markReceiptPresented(id: UUID) throws
    /// Atomically: not yet crafted, parts ≥ cost, spend cost, store record.
    func commitCraft(collectibleID: String, cost: Int, now: Date) throws -> CraftResult
    func recordClock(now: Date) throws
}

protocol DraftRepository: AnyObject {
    func fetchDrafts() throws -> [Draft]
    func saveDraft(_ draft: Draft) throws
    func deleteDraft(id: UUID) throws
}

protocol SettingsRepository: AnyObject {
    func fetchSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

protocol SnapshotRepository: AnyObject {
    func exportSnapshot() throws -> DatabaseSnapshot
    /// Replaces the whole database in one transaction; on failure nothing changes.
    func replaceAll(with snapshot: DatabaseSnapshot) throws
}

/// Managed photo files (Application Support, file protection, relative names).
protocol PhotoStore: AnyObject {
    /// Re-encodes the image (drops EXIF/location) and stores it under a new unique name.
    func storeImage(data: Data) throws -> String
    /// Stores already-validated bytes under a new unique name with the given extension.
    func storeRaw(data: Data, fileExtension: String) throws -> String
    func url(for path: String) -> URL?
    func data(for path: String) throws -> Data
    func deletePhoto(_ path: String)
    func storedPaths() -> [String]
}

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
