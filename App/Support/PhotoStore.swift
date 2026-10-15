import Foundation
import UIKit

enum JPEGEncoder {
    static func data(from image: UIImage, maxDimension: CGFloat = 1400) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > 0 ? min(1, maxDimension / longest) : 1
        let newSize = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaled.jpegData(compressionQuality: 0.78)
    }
}

struct PhotoStore {
    var store: SharedStore

    func save(_ data: Data, id: UUID) throws -> String {
        let filename = "\(id.uuidString).jpg"
        try FileManager.default.createDirectory(at: store.photosDirectory(), withIntermediateDirectories: true)
        try data.write(to: store.photoURL(named: filename), options: .atomic)
        return filename
    }

    func data(named filename: String?) -> Data? {
        guard let filename else { return nil }
        return try? Data(contentsOf: store.photoURL(named: filename))
    }

    func delete(named filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: store.photoURL(named: filename))
    }
}
