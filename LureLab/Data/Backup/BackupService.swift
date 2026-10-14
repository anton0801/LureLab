import Foundation

enum BackupCoding {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = fractional.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
        return decoder
    }

    static func isoString(_ date: Date) -> String { plain.string(from: date) }
}

final class BackupService: BackupServicing {
    private let snapshots: SnapshotRepository
    private let workshop: WorkshopRepository
    private let photos: PhotoStore
    private let rules: WorkshopRules
    private let clock: Clock
    private let fileManager = FileManager.default
    private let appVersion: String

    init(snapshots: SnapshotRepository, workshop: WorkshopRepository, photos: PhotoStore, rules: WorkshopRules, clock: Clock,
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") {
        self.snapshots = snapshots
        self.workshop = workshop
        self.photos = photos
        self.rules = rules
        self.clock = clock
        self.appVersion = appVersion
    }

    private var exportDirectory: URL {
        fileManager.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
    }

    private static func autoBackupDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LureLab", isDirectory: true).appendingPathComponent("AutoBackups", isDirectory: true)
    }

    private func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    // MARK: Export

    func exportBackup() throws -> URL {
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let url = exportDirectory.appendingPathComponent("LureLab-Backup-\(dayStamp(clock.now())).zip")
        try? fileManager.removeItem(at: url)
        try writeBackup(to: url)
        return url
    }

    /// Writes the ZIP photo by photo (never all photos in memory) and refuses archives the importer would reject.
    private func writeBackup(to url: URL) throws {
        var snapshot = try snapshots.exportSnapshot()
        var photoFiles: [(name: String, url: URL)] = []
        var totalBytes = 0
        for index in snapshot.lures.indices {
            guard let path = snapshot.lures[index].photoPath else { continue }
            guard let fileURL = photos.url(for: path),
                  let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue,
                  size <= BackupValidator.maxPhotoBytes
            else {
                snapshot.lures[index].photoPath = nil
                continue
            }
            if !photoFiles.contains(where: { $0.name == path }) {
                photoFiles.append((path, fileURL))
                totalBytes += size
            }
        }
        let manifest = BackupManifest(schemaVersion: BackupValidator.schemaVersion, exportID: UUID(), createdAt: clock.now(), appVersion: appVersion)
        let encoder = BackupCoding.encoder()
        let database = try encoder.encode(snapshot)
        guard photoFiles.count <= BackupValidator.maxPhotos,
              database.count <= BackupValidator.maxDatabaseBytes,
              totalBytes + database.count <= BackupValidator.maxTotalBytes
        else {
            throw DomainError.storage("The journal is larger than a single backup can hold (250 MB or 5000 photos). Remove some photos and try again.")
        }
        do {
            let writer = try ZipWriter(url: url, date: manifest.createdAt)
            try writer.add(path: "manifest.json", data: try encoder.encode(manifest), compress: true)
            try writer.add(path: "database.json", data: database, compress: true)
            for photo in photoFiles {
                try autoreleasepool {
                    try writer.add(path: "photos/\(photo.name)", data: try Data(contentsOf: photo.url), compress: false)
                }
            }
            try writer.finish()
        } catch {
            try? fileManager.removeItem(at: url)
            throw DomainError.storage("Could not create the backup. Free some storage and try again.")
        }
    }

    // MARK: Import

    func prepareImport(from url: URL) throws -> PreparedImport {
        let reader = try ZipReader(url: url, maxEntries: BackupValidator.maxPhotos + 8, maxTotalSize: BackupValidator.maxTotalBytes)
        guard let manifestEntry = reader.entries["manifest.json"] else { throw BackupError.missingManifest }
        guard let databaseEntry = reader.entries["database.json"] else { throw BackupError.unreadableArchive }
        let decoder = BackupCoding.decoder()
        let manifest: BackupManifest
        do {
            manifest = try decoder.decode(BackupManifest.self, from: try reader.extract(manifestEntry, maxSize: 64 * 1024))
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.missingManifest
        }
        guard manifest.schemaVersion == BackupValidator.schemaVersion else { throw BackupError.unsupportedVersion }

        let snapshot: DatabaseSnapshot
        do {
            snapshot = try decoder.decode(DatabaseSnapshot.self, from: try reader.extract(databaseEntry, maxSize: BackupValidator.maxDatabaseBytes))
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidDatabase("The journal inside the backup could not be read.")
        }

        var photoEntries: [String: ZipReader.Entry] = [:]
        for (name, entry) in reader.entries where name.hasPrefix("photos/") {
            let fileName = String(name.dropFirst("photos/".count))
            guard BackupValidator.isValidPhotoName(fileName) else { throw BackupError.unsafeEntry }
            photoEntries[fileName] = entry
        }
        for name in reader.entries.keys where name != "manifest.json" && name != "database.json" && !name.hasPrefix("photos/") {
            _ = name
            throw BackupError.unsafeEntry
        }
        guard photoEntries.count <= BackupValidator.maxPhotos else { throw BackupError.tooManyPhotos }

        let validated = try BackupValidator.validate(snapshot, manifest: manifest, photoNames: Set(photoEntries.keys), rules: rules, now: clock.now())

        // Stage only referenced photos after verifying they decode as the declared type.
        let staging = fileManager.temporaryDirectory.appendingPathComponent("ImportStaging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        var staged: [String: URL] = [:]
        do {
            for lure in validated.lures {
                guard let name = lure.photoPath, staged[name] == nil, let entry = photoEntries[name] else { continue }
                let data = try reader.extract(entry, maxSize: BackupValidator.maxPhotoBytes)
                let fileExtension = (name as NSString).pathExtension
                guard FilePhotoStore.isDecodableImage(data, fileExtension: fileExtension) else { throw BackupError.invalidPhoto }
                let target = staging.appendingPathComponent(name)
                try data.write(to: target, options: .atomic)
                staged[name] = target
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            if let error = error as? BackupError { throw error }
            throw BackupError.unreadableArchive
        }
        return PreparedImport(id: UUID(), manifest: manifest, snapshot: validated, stagedPhotos: staged, stagingDirectory: staging)
    }

    func applyImport(_ prepared: PreparedImport) throws {
        if try workshop.fetchWorkshop().pendingReceipt != nil { throw BackupError.pendingReceipt }

        // 1. Safety copy of the current journal.
        let autoDirectory = Self.autoBackupDirectory()
        try fileManager.createDirectory(at: autoDirectory, withIntermediateDirectories: true)
        try writeBackup(to: autoDirectory.appendingPathComponent("Before-Import-\(dayStamp(clock.now()))-\(UUID().uuidString.prefix(4)).zip"))
        pruneAutoBackups(in: autoDirectory, keep: 3)

        // 2. Copy staged photos under fresh names; existing files are untouched.
        let previousPaths = Set(photos.storedPaths())
        var renamed: [String: String] = [:]
        var created: [String] = []
        do {
            for (name, url) in prepared.stagedPhotos {
                let data = try Data(contentsOf: url)
                let newName = try photos.storeRaw(data: data, fileExtension: (name as NSString).pathExtension)
                renamed[name] = newName
                created.append(newName)
            }
            var snapshot = prepared.snapshot
            for index in snapshot.lures.indices {
                snapshot.lures[index].photoPath = snapshot.lures[index].photoPath.flatMap { renamed[$0] }
            }
            // 3. One transaction replaces the database.
            try snapshots.replaceAll(with: snapshot)
        } catch {
            created.forEach(photos.deletePhoto)
            throw error
        }
        // 4. Remove photos that belonged only to the replaced data.
        let keep = Set(renamed.values)
        for path in previousPaths where !keep.contains(path) { photos.deletePhoto(path) }
        discard(prepared)
    }

    func discard(_ prepared: PreparedImport) {
        try? fileManager.removeItem(at: prepared.stagingDirectory)
    }

    private func pruneAutoBackups(in directory: URL, keep: Int) {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let sorted = files.sorted {
            let first = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return first > second
        }
        for file in sorted.dropFirst(keep) { try? fileManager.removeItem(at: file) }
    }

    // MARK: CSV

    func exportCSV() throws -> URL {
        let snapshot = try snapshots.exportSnapshot()
        let csv = CSVExporter.csv(tests: snapshot.tests.sortedForJournal(), lures: snapshot.lures)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let url = exportDirectory.appendingPathComponent("LureLab-Tests-\(dayStamp(clock.now())).csv")
        do {
            try Data(csv.utf8).write(to: url, options: .atomic)
        } catch {
            throw DomainError.storage("Could not create the CSV file. Free some storage and try again.")
        }
        return url
    }

    // MARK: Reset

    func deleteAllData() throws {
        let current = try snapshots.exportSnapshot()
        var settings = current.settings
        settings.lastSelectedLureID = nil
        var fresh = DatabaseSnapshot()
        fresh.settings = settings
        fresh.workshop = WorkshopState(capsules: 0, parts: 0, nextEligibleAt: nil, lastSeenAt: current.workshop.lastSeenAt)
        try snapshots.replaceAll(with: fresh)
        photos.storedPaths().forEach(photos.deletePhoto)
    }
}

enum CSVExporter {
    static let header = ["test_id", "occurred_at_utc", "lure_id", "lure_name", "lure_type", "place", "duration_minutes",
                         "bites", "catches", "water_type", "water_clarity", "retrieve", "weather_note", "notes"]

    static func csv(tests: [TestEntry], lures: [Lure]) -> String {
        var lines = [header.joined(separator: ",")]
        for test in tests {
            let row: [String] = [
                test.id.uuidString,
                BackupCoding.isoString(test.occurredAt),
                test.lureID.uuidString,
                escape(userText: test.lureNameSnapshot),
                test.lureTypeSnapshot.rawValue,
                escape(userText: test.placeName),
                String(test.durationMinutes),
                test.bites.map(String.init) ?? "",
                test.catches.map(String.init) ?? "",
                test.waterType?.rawValue ?? "",
                test.clarity?.rawValue ?? "",
                test.retrieve?.rawValue ?? "",
                escape(userText: test.weatherNote),
                escape(userText: test.notes)
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes when needed and neutralizes spreadsheet formulas (leading =, +, -, @, tab, CR).
    static func escape(userText: String) -> String {
        var value = userText
        if let first = value.first, ["=", "+", "-", "@", "\t", "\r"].contains(first) {
            value = "'" + value
        }
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) || value != value.trimmingCharacters(in: .whitespaces) {
            value = "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
