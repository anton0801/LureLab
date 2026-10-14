import ImageIO
import SwiftUI
import UIKit

/// Decodes stored user photos for display, downsampled and cached.
final class PhotoLibrary: ObservableObject {
    private let store: PhotoStore
    private let cache = NSCache<NSString, UIImage>()
    private let maxPixelSize: CGFloat = 600

    init(store: PhotoStore) {
        self.store = store
        cache.countLimit = 200
    }

    func image(for path: String) -> UIImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        guard let url = store.url(for: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: path as NSString)
        return image
    }

    func clear() {
        cache.removeAllObjects()
        objectWillChange.send()
    }
}
