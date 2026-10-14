import XCTest
@testable import LureLab

/// Transactional behaviour against the real Core Data store (in-memory SQLite).
final class JournalIntegrationTests: XCTestCase {
    func testFirstLaunchIsEmpty() throws {
        let env = try TestEnvironment()
        let snapshot = try env.store.exportSnapshot()
        XCTAssertTrue(snapshot.lures.isEmpty)
        XCTAssertTrue(snapshot.tests.isEmpty)
        XCTAssertEqual(snapshot.workshop.capsules, 0, "no demo bonus capsules")
        XCTAssertEqual(snapshot.workshop.parts, 0)
        XCTAssertFalse(snapshot.settings.onboardingCompleted)
    }

    func testCreateEditAndRepeatedSaveKeepOneRecordPerUUID() throws {
        let env = try TestEnvironment()
        let id = UUID()
        _ = try env.lureUseCases.saveLure(id: id, fields: env.lureFields(name: "First"), photo: .unchanged)
        _ = try env.lureUseCases.saveLure(id: id, fields: env.lureFields(name: "First"), photo: .unchanged)
        _ = try env.lureUseCases.saveLure(id: id, fields: env.lureFields(name: "Renamed"), photo: .unchanged)
        let lures = try env.store.fetchLures()
        XCTAssertEqual(lures.count, 1)
        XCTAssertEqual(lures.first?.name, "Renamed")

        let lure = lures[0]
        let testID = UUID()
        let first = try env.logTest(lure, id: testID)
        let retry = try env.logTest(lure, id: testID, minutes: 50)
        XCTAssertTrue(first.wasInserted)
        XCTAssertFalse(retry.wasInserted, "double tap / retry with the same UUID must not duplicate")
        XCTAssertEqual(retry.capsule, .notApplicable, "editing never grants again")
        let tests = try env.store.fetchTests()
        XCTAssertEqual(tests.count, 1)
        XCTAssertEqual(tests.first?.durationMinutes, 50)
        XCTAssertEqual(try env.store.fetchWorkshop().state.capsules, 1)
    }

    func testTestWithoutCatchIsSavedAndEarnsCapsule() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        let result = try env.logTest(lure, bites: 0, catches: 0)
        XCTAssertEqual(result.capsule, .earned)
        let unknown = try env.logTest(lure, bites: nil, catches: nil)
        XCTAssertEqual(unknown.test.catches, nil)
        XCTAssertEqual(unknown.capsule, .notEligible(nextAt: env.clock.now().addingTimeInterval(86_400)))
    }

    func testAwardCooldownAndLedger() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        XCTAssertEqual(try env.logTest(lure).capsule, .earned)
        env.clock.advance(hours: 23)
        if case .notEligible = try env.logTest(lure).capsule {} else { XCTFail("cooldown must block") }
        env.clock.advance(hours: 1)
        XCTAssertEqual(try env.logTest(lure).capsule, .earned)
        let workshop = try env.store.fetchWorkshop()
        XCTAssertEqual(workshop.state.capsules, 2)
        XCTAssertEqual(workshop.ledger.count, 2)
        XCTAssertEqual(workshop.state.nextEligibleAt, env.clock.now().addingTimeInterval(86_400))
    }

    func testBalanceCapAtSeven() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        for _ in 0..<7 {
            XCTAssertEqual(try env.logTest(lure).capsule, .earned)
            env.clock.advance(hours: 25)
        }
        let nextBefore = try env.store.fetchWorkshop().state.nextEligibleAt
        XCTAssertEqual(try env.logTest(lure).capsule, .shelfFull)
        let workshop = try env.store.fetchWorkshop()
        XCTAssertEqual(workshop.state.capsules, 7)
        XCTAssertEqual(workshop.ledger.count, 7)
        XCTAssertEqual(workshop.state.nextEligibleAt, nextBefore, "timer is not extended while capped")
    }

    func testDeletingTestKeepsRewardLedgerAndRecomputesStatistics() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        let saved = try env.logTest(lure)
        try env.testUseCases.delete(id: saved.test.id)
        XCTAssertTrue(try env.store.fetchTests().isEmpty)
        let workshop = try env.store.fetchWorkshop()
        XCTAssertEqual(workshop.ledger.count, 1)
        XCTAssertEqual(workshop.state.capsules, 1, "deleting does not revoke a granted capsule")
        XCTAssertNil(RateCalculator.summarize(try env.store.fetchTests(), metric: .catches).ratePerHour)
    }

    func testArchiveKeepsHistoryAndDeleteRequiresNoTests() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        try env.logTest(lure)
        XCTAssertThrowsError(try env.lureUseCases.delete(id: lure.id)) { error in
            XCTAssertEqual(error as? DomainError, .lureHasTests)
        }
        let archived = try env.lureUseCases.archive(id: lure.id)
        XCTAssertNotNil(archived.archivedAt)
        let again = try env.lureUseCases.archive(id: lure.id)
        XCTAssertEqual(again.archivedAt, archived.archivedAt, "archive is idempotent")
        XCTAssertEqual(try env.store.fetchTests().count, 1, "history stays")
        _ = try env.lureUseCases.restore(id: lure.id)
        _ = try env.lureUseCases.restore(id: lure.id)
        XCTAssertNil(try env.store.fetchLures().first?.archivedAt)

        let spare = try env.addLure(name: "Spare")
        try env.lureUseCases.delete(id: spare.id)
        XCTAssertEqual(try env.store.fetchLures().count, 1)
    }

    func testRenamingLureKeepsTestSnapshot() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure(name: "Old Name")
        try env.logTest(lure)
        _ = try env.lureUseCases.saveLure(id: lure.id, fields: env.lureFields(name: "New Name"), photo: .unchanged)
        XCTAssertEqual(try env.store.fetchTests().first?.lureNameSnapshot, "Old Name")
    }

    func testPhotoIsStoredReplacedAndRemoved() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure(photo: .replaced(TestEnvironment.samplePNG()))
        let firstPath = try XCTUnwrap(lure.photoPath)
        XCTAssertNotNil(env.photos.url(for: firstPath))
        XCTAssertTrue(firstPath.hasSuffix(".jpg"), "photos are re-encoded (no EXIF/location)")

        let replaced = try env.lureUseCases.saveLure(id: lure.id, fields: env.lureFields(), photo: .replaced(TestEnvironment.samplePNG(color: .red)))
        XCTAssertNotEqual(replaced.photoPath, firstPath)
        XCTAssertNil(env.photos.url(for: firstPath), "old photo file is removed after the new reference commits")

        let removed = try env.lureUseCases.saveLure(id: lure.id, fields: env.lureFields(), photo: .removed)
        XCTAssertNil(removed.photoPath)
        XCTAssertTrue(env.photos.storedPaths().isEmpty)
    }

    func testFailedSaveLeavesNoOrphanPhotoAndNoRecord() throws {
        let env = try TestEnvironment()
        env.store.failNextWrite = true
        XCTAssertThrowsError(try env.lureUseCases.saveLure(id: UUID(), fields: env.lureFields(), photo: .replaced(TestEnvironment.samplePNG())))
        XCTAssertTrue(try env.store.fetchLures().isEmpty)
        XCTAssertTrue(env.photos.storedPaths().isEmpty)
    }

    func testFailedTestSaveGrantsNothing() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        env.store.failNextWrite = true
        XCTAssertThrowsError(try env.logTest(lure))
        XCTAssertTrue(try env.store.fetchTests().isEmpty)
        XCTAssertEqual(try env.store.fetchWorkshop().state.capsules, 0)
        XCTAssertTrue(try env.store.fetchWorkshop().ledger.isEmpty)
    }

    func testDraftsPersistAndAreSeparateFromStatistics() throws {
        let env = try TestEnvironment()
        let payload = TestDraftPayload(isEditing: false, lureID: nil, placeName: "Bay", occurredAt: Date(), durationText: "30",
                                       bites: nil, catches: nil, waterType: nil, clarity: nil, retrieve: nil, weatherNote: "", notes: "")
        let draft = Draft(id: UUID(), kind: .test, payload: try JSONEncoder().encode(payload), updatedAt: Date())
        try env.store.saveDraft(draft)
        try env.store.saveDraft(draft)
        XCTAssertEqual(try env.store.fetchDrafts().count, 1)
        XCTAssertTrue(try env.store.fetchTests().isEmpty)
        try env.store.deleteDraft(id: draft.id)
        XCTAssertTrue(try env.store.fetchDrafts().isEmpty)
    }
}

final class WorkshopIntegrationTests: XCTestCase {
    private func environmentWithCapsule() throws -> TestEnvironment {
        let env = try TestEnvironment()
        try env.logTest(try env.addLure())
        return env
    }

    func testCastCommitsReceiptBeforeAnimationAndSpendsExactlyOneCapsule() throws {
        let env = try environmentWithCapsule()
        let (receipt, state) = try env.workshop.cast()
        XCTAssertEqual(state.capsules, 0)
        XCTAssertEqual(state.parts, receipt.parts)
        XCTAssertEqual(receipt.parts, CastEngine(rules: env.rules).evaluate(matrix: receipt.matrix).parts)
        let stored = try env.store.fetchWorkshop()
        XCTAssertEqual(stored.pendingReceipt?.id, receipt.id, "committed, not yet presented")
        XCTAssertThrowsError(try env.workshop.cast(), "no capsule and a pending receipt: nothing happens")
        XCTAssertEqual(try env.store.fetchWorkshop().state.parts, receipt.parts)
    }

    func testPendingReceiptRestoresWithoutRegranting() throws {
        let env = try environmentWithCapsule()
        let (receipt, _) = try env.workshop.cast()
        // Simulated relaunch: a second store view sees the same committed receipt.
        let restored = try env.store.fetchWorkshop()
        XCTAssertEqual(restored.pendingReceipt?.matrix, receipt.matrix)
        XCTAssertEqual(restored.state.parts, receipt.parts)
        // Re-committing the same receipt id (e.g. retry after a crash) is a no-op.
        XCTAssertEqual(try env.store.commitCast(receipt).parts, receipt.parts)
        try env.workshop.markPresented(receipt.id)
        try env.workshop.markPresented(receipt.id)
        let after = try env.store.fetchWorkshop()
        XCTAssertNil(after.pendingReceipt)
        XCTAssertEqual(after.receipts.count, 1)
        XCTAssertEqual(after.state.parts, receipt.parts)
    }

    func testCastWithoutCapsuleFails() throws {
        let env = try TestEnvironment()
        XCTAssertThrowsError(try env.workshop.cast()) { error in
            XCTAssertEqual(error as? DomainError, .notEnoughCapsules)
        }
        XCTAssertTrue(try env.store.fetchWorkshop().receipts.isEmpty)
    }

    func testCraftDoubleTapSpendsOnce() throws {
        let env = try TestEnvironment()
        var snapshot = try env.store.exportSnapshot()
        snapshot.workshop.parts = 7
        try env.store.replaceAll(with: snapshot)
        let first = try env.workshop.craft("L01")
        let second = try env.workshop.craft("L01")
        guard case .crafted = first, case .alreadyCrafted = second else { return XCTFail("expected crafted then alreadyCrafted") }
        let workshop = try env.store.fetchWorkshop()
        XCTAssertEqual(workshop.state.parts, 4)
        XCTAssertEqual(workshop.collectibles.map(\.id), ["L01"])
    }

    func testCraftNeedsThreeParts() throws {
        let env = try TestEnvironment()
        var snapshot = try env.store.exportSnapshot()
        snapshot.workshop.parts = 2
        try env.store.replaceAll(with: snapshot)
        XCTAssertThrowsError(try env.workshop.craft("L02")) { error in
            XCTAssertEqual(error as? DomainError, .notEnoughParts)
        }
        XCTAssertEqual(try env.store.fetchWorkshop().state.parts, 2)
        XCTAssertTrue(try env.store.fetchWorkshop().collectibles.isEmpty)
    }
}

final class BackupIntegrationTests: XCTestCase {
    func testFullBackupAndRestoreRoundTrip() throws {
        let source = try TestEnvironment()
        let lure = try source.addLure(photo: .replaced(TestEnvironment.samplePNG()))
        try source.logTest(lure, bites: nil, catches: 0)
        _ = try source.workshop.cast()
        let exported = try source.backup.exportBackup()
        defer { try? FileManager.default.removeItem(at: exported) }
        let original = try source.store.exportSnapshot()

        let target = try TestEnvironment()
        try target.addLure(name: "Will be replaced")
        let prepared = try target.backup.prepareImport(from: exported)
        XCTAssertEqual(prepared.lureCount, 1)
        XCTAssertEqual(prepared.testCount, 1)
        XCTAssertEqual(prepared.photoCount, 1)
        // Pending receipt in the backup is fine; the target has none, so import may proceed.
        try target.backup.applyImport(prepared)

        let restored = try target.store.exportSnapshot()
        XCTAssertEqual(restored.lures.map(\.id), original.lures.map(\.id))
        XCTAssertEqual(restored.tests.map(\.id), original.tests.map(\.id))
        XCTAssertEqual(restored.tests.first?.bites, nil, "unknown stays unknown after restore")
        XCTAssertEqual(restored.tests.first?.catches, 0)
        XCTAssertEqual(restored.workshop.parts, original.workshop.parts)
        XCTAssertEqual(restored.castReceipts.count, 1)
        let photoPath = try XCTUnwrap(restored.lures.first?.photoPath)
        XCTAssertNotNil(target.photos.url(for: photoPath))
        XCTAssertEqual(target.photos.storedPaths().count, 1, "photos of replaced data are removed")
    }

    func testInvalidImportRollsBackAndKeepsCurrentData() throws {
        let env = try TestEnvironment()
        let lure = try env.addLure()
        try env.logTest(lure)
        let before = try env.store.exportSnapshot()

        // 1. Not a ZIP at all.
        let garbage = FileManager.default.temporaryDirectory.appendingPathComponent("garbage-\(UUID()).zip")
        try Data("not a zip".utf8).write(to: garbage)
        XCTAssertThrowsError(try env.backup.prepareImport(from: garbage))

        // 2. Valid ZIP with a test that references a missing lure.
        var broken = before
        broken.lures = []
        let brokenURL = try makeArchive(snapshot: broken)
        XCTAssertThrowsError(try env.backup.prepareImport(from: brokenURL)) { error in
            guard case .invalidDatabase = error as? BackupError else { return XCTFail("expected invalid database, got \(error)") }
        }

        // 3. Path traversal entry.
        let traversal = FileManager.default.temporaryDirectory.appendingPathComponent("traversal-\(UUID()).zip")
        let writer = try ZipWriter(url: traversal)
        try writer.add(path: "manifest.json", data: try BackupCoding.encoder().encode(manifest()), compress: false)
        try writer.add(path: "../evil.json", data: Data("{}".utf8), compress: false)
        try writer.finish()
        XCTAssertThrowsError(try env.backup.prepareImport(from: traversal)) { error in
            XCTAssertEqual(error as? BackupError, .unsafeEntry)
        }

        // 4. Balance that does not match the ledger.
        var inflated = before
        inflated.workshop.parts = 99
        XCTAssertThrowsError(try env.backup.prepareImport(from: try makeArchive(snapshot: inflated)))

        // 5. A failure while replacing leaves the database untouched.
        let good = try env.backup.prepareImport(from: try makeArchive(snapshot: before))
        env.store.failNextWrite = true
        XCTAssertThrowsError(try env.backup.applyImport(good))

        XCTAssertEqual(try env.store.exportSnapshot(), before, "current data is unchanged after every failure")
        [garbage, brokenURL, traversal].forEach { try? FileManager.default.removeItem(at: $0) }
    }

    func testPendingReceiptBlocksImport() throws {
        let env = try TestEnvironment()
        try env.logTest(try env.addLure())
        let exported = try env.backup.exportBackup()
        let prepared = try env.backup.prepareImport(from: exported)
        _ = try env.workshop.cast()
        XCTAssertThrowsError(try env.backup.applyImport(prepared)) { error in
            XCTAssertEqual(error as? BackupError, .pendingReceipt)
        }
    }

    func testDeleteAllDataResetsJournalAndCollection() throws {
        let env = try TestEnvironment()
        try env.logTest(try env.addLure(photo: .replaced(TestEnvironment.samplePNG())))
        var settings = try env.store.fetchSettings()
        settings.onboardingCompleted = true
        settings.units = .imperial
        try env.store.saveSettings(settings)
        try env.backup.deleteAllData()
        let snapshot = try env.store.exportSnapshot()
        XCTAssertTrue(snapshot.lures.isEmpty && snapshot.tests.isEmpty && snapshot.ledger.isEmpty && snapshot.collectibles.isEmpty)
        XCTAssertEqual(snapshot.workshop.capsules, 0)
        XCTAssertTrue(env.photos.storedPaths().isEmpty)
        XCTAssertEqual(snapshot.settings.units, .imperial, "preferences survive")
    }

    // MARK: Helpers

    private func manifest() -> BackupManifest {
        BackupManifest(schemaVersion: 1, exportID: UUID(), createdAt: Date(), appVersion: "1.0")
    }

    private func makeArchive(snapshot: DatabaseSnapshot) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID()).zip")
        let writer = try ZipWriter(url: url)
        try writer.add(path: "manifest.json", data: try BackupCoding.encoder().encode(manifest()), compress: true)
        try writer.add(path: "database.json", data: try BackupCoding.encoder().encode(snapshot), compress: true)
        try writer.finish()
        return url
    }
}

final class ZipTests: XCTestCase {
    func testRoundTripStoreAndDeflate() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = Data(String(repeating: "lure lab ", count: 500).utf8)
        let binary = TestEnvironment.samplePNG()
        let writer = try ZipWriter(url: url)
        try writer.add(path: "a.json", data: text, compress: true)
        try writer.add(path: "photos/b.png", data: binary, compress: false)
        try writer.finish()
        let reader = try ZipReader(url: url, maxEntries: 10, maxTotalSize: 1_000_000)
        XCTAssertEqual(reader.entries["a.json"]?.method, 8)
        XCTAssertEqual(try reader.extract(XCTUnwrap(reader.entries["a.json"]), maxSize: 100_000), text)
        XCTAssertEqual(try reader.extract(XCTUnwrap(reader.entries["photos/b.png"]), maxSize: 100_000), binary)
    }

    func testUnsafePaths() {
        for name in ["/etc/passwd", "../x", "a/../../b", "a\\b", "./a"] {
            XCTAssertThrowsError(try ZipReader.checkSafePath(name), name)
        }
        XCTAssertNoThrow(try ZipReader.checkSafePath("photos/1.jpg"))
    }
}
