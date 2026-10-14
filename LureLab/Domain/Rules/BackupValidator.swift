import Foundation

struct BackupManifest: Codable, Equatable {
    let schemaVersion: Int
    let exportID: UUID
    let createdAt: Date
    let appVersion: String
}

enum BackupError: Error, Equatable, LocalizedError {
    case unreadableArchive
    case unsafeEntry
    case duplicateEntry
    case tooLarge
    case tooManyPhotos
    case missingManifest
    case unsupportedVersion
    case invalidDatabase(String)
    case invalidPhoto
    case pendingReceipt

    /// Human-readable reason; the UI always adds that current data is unchanged.
    var errorDescription: String? {
        switch self {
        case .unreadableArchive: return "The file is incomplete or unsupported."
        case .unsafeEntry: return "The file contains entries that cannot be opened safely."
        case .duplicateEntry: return "The file contains duplicate entries."
        case .tooLarge: return "The backup is larger than this app can import."
        case .tooManyPhotos: return "The backup contains too many photos."
        case .missingManifest: return "The file is not a Lure Lab backup."
        case .unsupportedVersion: return "The backup was made by a newer version of Lure Lab."
        case let .invalidDatabase(reason): return reason
        case .invalidPhoto: return "A photo in the backup could not be read."
        case .pendingReceipt: return "Open Lucky Cast to finish the current result first."
        }
    }
}

/// Validates an imported database before anything is replaced. Never executes or trusts backup text.
enum BackupValidator {
    static let schemaVersion = 1
    static let maxDatabaseBytes = 20 * 1024 * 1024
    static let maxTotalBytes = 250 * 1024 * 1024
    static let maxPhotoBytes = 20 * 1024 * 1024
    static let maxPhotos = 5000

    /// Expected photo file name inside `photos/`: "<UUID>.jpg|jpeg|png".
    static func isValidPhotoName(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, UUID(uuidString: String(parts[0])) != nil else { return false }
        return ["jpg", "jpeg", "png"].contains(parts[1].lowercased())
    }

    /// - Parameter photoNames: names of photo entries present in the archive.
    static func validate(_ snapshot: DatabaseSnapshot, manifest: BackupManifest, photoNames: Set<String>, rules: WorkshopRules, now: Date) throws -> DatabaseSnapshot {
        guard manifest.schemaVersion == schemaVersion else { throw BackupError.unsupportedVersion }
        func fail(_ reason: String) -> BackupError { .invalidDatabase(reason) }

        guard Set(snapshot.lures.map(\.id)).count == snapshot.lures.count,
              Set(snapshot.tests.map(\.id)).count == snapshot.tests.count,
              Set(snapshot.drafts.map(\.id)).count == snapshot.drafts.count,
              Set(snapshot.ledger.map(\.id)).count == snapshot.ledger.count,
              Set(snapshot.castReceipts.map(\.id)).count == snapshot.castReceipts.count,
              Set(snapshot.collectibles.map(\.id)).count == snapshot.collectibles.count
        else { throw fail("The backup contains repeated records.") }

        let lureIDs = Set(snapshot.lures.map(\.id))
        for lure in snapshot.lures {
            let name = lure.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= Lure.Limits.name.upperBound,
                  lure.lengthCm.map(Lure.Limits.length.contains) ?? true,
                  lure.weightG.map(Lure.Limits.weight.contains) ?? true,
                  (lure.color?.count ?? 0) <= Lure.Limits.shortText,
                  (lure.brand?.count ?? 0) <= Lure.Limits.shortText,
                  lure.notes.count <= Lure.Limits.notes
            else { throw fail("A lure in the backup has values outside the allowed range.") }
            if let path = lure.photoPath {
                guard isValidPhotoName(path), photoNames.contains(path) else { throw fail("A lure refers to a missing photo.") }
            }
        }

        let latestAllowed = now.addingTimeInterval(86_400)
        for test in snapshot.tests {
            guard lureIDs.contains(test.lureID) else { throw fail("A test refers to a missing lure.") }
            let place = test.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !place.isEmpty, place.count <= TestEntry.Limits.place.upperBound,
                  !test.lureNameSnapshot.isEmpty, test.lureNameSnapshot.count <= Lure.Limits.name.upperBound,
                  TestEntry.Limits.duration.contains(test.durationMinutes),
                  test.bites.map(TestEntry.Limits.count.contains) ?? true,
                  test.catches.map(TestEntry.Limits.count.contains) ?? true,
                  test.weatherNote.count <= TestEntry.Limits.weatherNote,
                  test.notes.count <= TestEntry.Limits.notes,
                  test.occurredAt <= latestAllowed,
                  test.completed
            else { throw fail("A test in the backup has values outside the allowed range.") }
            if let bites = test.bites, let catches = test.catches, catches > bites {
                throw fail("A test records more catches than bites.")
            }
        }

        for draft in snapshot.drafts where draft.payload.count > 1_000_000 {
            _ = draft
            throw fail("A draft in the backup is too large.")
        }

        let engine = CastEngine(rules: rules)
        for receipt in snapshot.castReceipts {
            guard receipt.matrix.count == rules.rows,
                  receipt.matrix.allSatisfy({ $0.count == rules.columns }),
                  engine.evaluate(matrix: receipt.matrix).parts == receipt.parts
            else { throw fail("A Lucky Cast record in the backup is not valid.") }
        }
        if snapshot.castReceipts.filter({ $0.status == .committed }).count > 1 {
            throw fail("The backup contains more than one unfinished Lucky Cast.")
        }

        var craftedCost = 0
        for record in snapshot.collectibles {
            guard let definition = rules.collectible(record.id) else { throw fail("The backup contains an unknown collectible.") }
            craftedCost += definition.costParts
        }

        guard snapshot.ledger.allSatisfy({ $0.delta == 1 }) else { throw fail("The workshop history in the backup is not valid.") }
        let expectedCapsules = snapshot.ledger.reduce(0) { $0 + $1.delta } - snapshot.castReceipts.count
        let expectedParts = snapshot.castReceipts.reduce(0) { $0 + $1.parts } - craftedCost
        let workshop = snapshot.workshop
        guard workshop.capsules >= 0, workshop.capsules <= rules.maxCapsules, workshop.parts >= 0,
              workshop.capsules == expectedCapsules, workshop.parts == expectedParts
        else { throw fail("The workshop balance in the backup does not match its history.") }

        var sanitized = snapshot
        if let selected = sanitized.settings.lastSelectedLureID, !lureIDs.contains(selected) {
            sanitized.settings.lastSelectedLureID = nil
        }
        return sanitized
    }
}
