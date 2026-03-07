import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    func load(url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }

        // Deduplicate in-flight requests
        if let existing = activeTasks[url.absoluteString] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let img = UIImage(data: data) else { return nil }
                store(img, for: url)
                return img
            } catch {
                return nil
            }
        }
        activeTasks[url.absoluteString] = task
        let result = await task.value
        activeTasks.removeValue(forKey: url.absoluteString)
        return result
    }

    func prefetch(urls: [URL]) {
        for url in urls {
            guard image(for: url) == nil else { continue }
            Task.detached(priority: .background) { [weak self] in
                _ = await self?.load(url: url)
            }
        }
    }
}
