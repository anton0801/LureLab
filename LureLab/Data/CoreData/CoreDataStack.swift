import CoreData
import Foundation

/// Programmatic Core Data model (no .xcdatamodeld) so the schema lives next to the mappers.
enum LureLabModel {
    static let shared: NSManagedObjectModel = build()

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        if let defaultValue { attribute.defaultValue = defaultValue }
        return attribute
    }

    /// Uniqueness is enforced by the store's fetch-then-upsert writes, so a full replace
    /// (delete + re-insert of the same ids) can happen inside one transaction.
    private static func entity(_ name: String, _ attributes: [NSAttributeDescription], unique: String? = nil) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = attributes
        if let unique, let attribute = attributes.first(where: { $0.name == unique }) {
            let index = NSFetchIndexDescription(name: "\(name)_\(unique)", elements: [NSFetchIndexElementDescription(property: attribute, collationType: .binary)])
            entity.indexes = [index]
        }
        return entity
    }

    private static func build() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity("LureRecord", [
                attribute("id", .UUIDAttributeType),
                attribute("name", .stringAttributeType),
                attribute("type", .stringAttributeType),
                attribute("lengthCm", .decimalAttributeType, optional: true),
                attribute("weightG", .decimalAttributeType, optional: true),
                attribute("color", .stringAttributeType, optional: true),
                attribute("brand", .stringAttributeType, optional: true),
                attribute("notes", .stringAttributeType, defaultValue: ""),
                attribute("photoPath", .stringAttributeType, optional: true),
                attribute("createdAt", .dateAttributeType),
                attribute("updatedAt", .dateAttributeType),
                attribute("archivedAt", .dateAttributeType, optional: true)
            ], unique: "id"),
            entity("TestRecord", [
                attribute("id", .UUIDAttributeType),
                attribute("lureID", .UUIDAttributeType),
                attribute("lureNameSnapshot", .stringAttributeType),
                attribute("lureTypeSnapshot", .stringAttributeType),
                attribute("placeName", .stringAttributeType),
                attribute("occurredAt", .dateAttributeType),
                attribute("durationMinutes", .integer32AttributeType, defaultValue: 0),
                attribute("bites", .integer32AttributeType, optional: true),
                attribute("catches", .integer32AttributeType, optional: true),
                attribute("waterType", .stringAttributeType, optional: true),
                attribute("clarity", .stringAttributeType, optional: true),
                attribute("retrieve", .stringAttributeType, optional: true),
                attribute("weatherNote", .stringAttributeType, defaultValue: ""),
                attribute("notes", .stringAttributeType, defaultValue: ""),
                attribute("createdAt", .dateAttributeType),
                attribute("updatedAt", .dateAttributeType),
                attribute("completed", .booleanAttributeType, defaultValue: true)
            ], unique: "id"),
            entity("DraftRecord", [
                attribute("id", .UUIDAttributeType),
                attribute("kind", .stringAttributeType),
                attribute("payload", .binaryDataAttributeType),
                attribute("updatedAt", .dateAttributeType)
            ], unique: "id"),
            entity("AwardRecord", [
                attribute("id", .UUIDAttributeType),
                attribute("testID", .UUIDAttributeType),
                attribute("grantedAt", .dateAttributeType),
                attribute("delta", .integer32AttributeType, defaultValue: 1)
            ], unique: "id"),
            entity("ReceiptRecord", [
                attribute("id", .UUIDAttributeType),
                attribute("matrix", .stringAttributeType),
                attribute("parts", .integer32AttributeType, defaultValue: 1),
                attribute("createdAt", .dateAttributeType),
                attribute("status", .stringAttributeType)
            ], unique: "id"),
            entity("CollectibleRecord", [
                attribute("id", .stringAttributeType),
                attribute("craftedAt", .dateAttributeType)
            ], unique: "id"),
            entity("WorkshopRecord", [
                attribute("key", .stringAttributeType),
                attribute("capsules", .integer32AttributeType, defaultValue: 0),
                attribute("parts", .integer32AttributeType, defaultValue: 0),
                attribute("nextEligibleAt", .dateAttributeType, optional: true),
                attribute("lastSeenAt", .dateAttributeType, optional: true)
            ], unique: "key"),
            entity("SettingsRecord", [
                attribute("key", .stringAttributeType),
                attribute("hapticsEnabled", .booleanAttributeType, defaultValue: true),
                attribute("reduceMotion", .booleanAttributeType, defaultValue: false),
                attribute("units", .stringAttributeType, defaultValue: "metric"),
                attribute("onboardingCompleted", .booleanAttributeType, defaultValue: false),
                attribute("lastSelectedLureID", .UUIDAttributeType, optional: true)
            ], unique: "key")
        ]
        return model
    }
}

/// Owns the persistent container. Production uses an SQLite file with file protection; tests use an in-memory SQLite store.
final class CoreDataStack {
    let container: NSPersistentContainer
    let context: NSManagedObjectContext

    enum StoreKind {
        case onDisk(URL)
        case inMemory
    }

    init(store: StoreKind) throws {
        container = NSPersistentContainer(name: "LureLab", managedObjectModel: LureLabModel.shared)
        let description: NSPersistentStoreDescription
        switch store {
        case let .onDisk(url):
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            description = NSPersistentStoreDescription(url: url)
            description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        case .inMemory:
            description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        }
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
    }

    static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LureLab", isDirectory: true).appendingPathComponent("LureLab.sqlite")
    }
}
