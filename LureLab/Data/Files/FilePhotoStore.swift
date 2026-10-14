import Foundation
import ImageIO
import UIKit

/// Stores user photos in Application Support with file protection, addressed by relative file names.
final class FilePhotoStore: PhotoStore {
    let directory: URL
    private let fileManager = FileManager.default
    private let maxPixelSize: CGFloat = 2048

    init(directory: URL = FilePhotoStore.defaultDirectory()) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                         attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LureLab", isDirectory: true).appendingPathComponent("Photos", isDirectory: true)
    }

    func storeImage(data: Data) throws -> String {
        guard let jpeg = Self.normalizedJPEG(from: data, maxPixelSize: maxPixelSize) else {
            throw DomainError.storage("This photo could not be read.")
        }
        return try storeRaw(data: jpeg, fileExtension: "jpg")
    }

    func storeRaw(data: Data, fileExtension: String) throws -> String {
        let name = "\(UUID().uuidString).\(fileExtension.lowercased())"
        let url = directory.appendingPathComponent(name)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            throw DomainError.storage("Could not save the photo. Free some storage and try again.")
        }
        return name
    }

    func url(for path: String) -> URL? {
        guard BackupValidator.isValidPhotoName(path) else { return nil }
        let url = directory.appendingPathComponent(path)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func data(for path: String) throws -> Data {
        guard let url = url(for: path) else { throw DomainError.notFound }
        return try Data(contentsOf: url)
    }

    func deletePhoto(_ path: String) {
        guard BackupValidator.isValidPhotoName(path) else { return }
        try? fileManager.removeItem(at: directory.appendingPathComponent(path))
    }

    func storedPaths() -> [String] {
        ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []).filter(BackupValidator.isValidPhotoName)
    }

    /// Decodes, applies orientation, downsizes and re-encodes as JPEG. Metadata (EXIF / GPS) is not copied.
    static func normalizedJPEG(from data: Data, maxPixelSize: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }

    /// True when the bytes are a decodable JPEG or PNG of the claimed type.
    static func isDecodableImage(_ data: Data, fileExtension: String) -> Bool {
        let bytes = [UInt8](data.prefix(8))
        let isPNG = bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let isJPEG = bytes.starts(with: [0xFF, 0xD8, 0xFF])
        switch fileExtension.lowercased() {
        case "png": guard isPNG else { return false }
        case "jpg", "jpeg": guard isJPEG else { return false }
        default: return false
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width * height <= 100_000_000
        else { return false }
        return true
    }
}
