import UIKit

final class ProfilePhotoStore {
    static let shared = ProfilePhotoStore()

    private let fileManager = FileManager.default
    private init() {}

    func image(for profileID: UUID?) -> UIImage? {
        guard let profileID,
              let data = try? Data(contentsOf: fileURL(for: profileID)) else { return nil }
        return UIImage(data: data)
    }

    func save(_ image: UIImage, for profileID: UUID) throws {
        guard let data = image.resized(maxDimension: 1_200).jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: profileID), options: .atomic)
    }

    func delete(for profileID: UUID?) {
        guard let profileID else { return }
        try? fileManager.removeItem(at: fileURL(for: profileID))
    }

    private var directoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ProfilePhotos", isDirectory: true)
    }

    private func fileURL(for profileID: UUID) -> URL {
        directoryURL.appendingPathComponent(profileID.uuidString).appendingPathExtension("jpg")
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let scale = maxDimension / largest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
