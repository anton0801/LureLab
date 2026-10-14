import Foundation

/// A backup that passed every check and is staged on disk, waiting for an explicit "Replace".
struct PreparedImport: Identifiable, Equatable {
    let id: UUID
    let manifest: BackupManifest
    let snapshot: DatabaseSnapshot
    /// Photo name inside the backup → staged file.
    let stagedPhotos: [String: URL]
    let stagingDirectory: URL

    var lureCount: Int { snapshot.lures.count }
    var testCount: Int { snapshot.tests.count }
    var photoCount: Int { stagedPhotos.count }
}

/// Backup, restore, CSV and full reset. Implemented in the Data layer (files, ZIP, Core Data).
protocol BackupServicing: AnyObject {
    /// Writes a ZIP (manifest.json, database.json, photos/) to a temporary file and returns it.
    func exportBackup() throws -> URL
    /// Validates the file completely and stages it. Nothing local changes.
    func prepareImport(from url: URL) throws -> PreparedImport
    /// Keeps a copy of the current data, then replaces everything atomically.
    func applyImport(_ prepared: PreparedImport) throws
    func discard(_ prepared: PreparedImport)
    /// UTF-8 CSV of all tests.
    func exportCSV() throws -> URL
    /// Explicit reset of journal, photos and collection.
    func deleteAllData() throws
}
