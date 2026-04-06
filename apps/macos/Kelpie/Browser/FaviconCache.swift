import Foundation
import AppKit

/// Centralised, per-hostname favicon cache.
///
/// Uses the site's own `/favicon.ico` as primary source so private hosts never leak.
/// Falls back to Google Favicon API only for public internet hosts. Results are
/// persisted to the Caches directory so they survive across launches.
@MainActor
final class FaviconCache: ObservableObject {
    static let shared = FaviconCache()

    @Published private(set) var images: [String: NSImage] = [:]

    private let cacheDir: URL
    private var pending: [String: Task<Void, Never>] = [:]

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        cacheDir = base.appendingPathComponent("Favicons", isDirectory: true)
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        loadDiskCache()
    }

    /// Kicks off a fetch if the image is not already cached or in-flight.
    /// Safe to call repeatedly — duplicate calls are no-ops.
    func image(forHost host: String) {
        let key = normalizedKey(host)
        guard images[key] == nil, pending[key] == nil else { return }
        let task = Task {
            await fetchAndCache(forHost: key)
        }
        pending[key] = task
    }

    /// Synchronously reads the cached image. Must be called from the main actor.
    func cachedImage(forHost host: String) -> NSImage? {
        images[normalizedKey(host)]
    }

    /// Force-refresh: cancels any in-flight fetch, evicts the cache entry, and
    /// re-fetches from the network.
    func refresh(forHost host: String) {
        let key = normalizedKey(host)
        images[key] = nil
        pending[key]?.cancel()
        pending[key] = nil
        image(forHost: host)
    }

    /// Evicts and deletes all cached entries.
    func clearAll() {
        images.removeAll()
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Private

    /// Loads all cached images from disk before `init` returns.
    private func loadDiskCache() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            guard let data = try? Data(contentsOf: url),
                  let img = decodeImage(data: data, url: url) else { continue }
            let key = url.deletingPathExtension().lastPathComponent
            images[key] = img
        }
    }

    /// Fetches, caches, and cleans up the pending entry on every exit path.
    private func fetchAndCache(forHost host: String) async {
        defer { pending[host] = nil }

        // Site origin is always tried first — avoids leaking private hosts.
        if let img = await fetchFromSite(host: host) {
            cache(img, forKey: host)
            return
        }
        // Only send public hosts to Google.
        if !isPrivateHost(host), let img = await fetchFromGoogle(host: host) {
            cache(img, forKey: host)
        }
    }

    private func cache(_ img: NSImage, forKey key: String) {
        images[key] = img
        let keyCopy = key, imgCopy = img, dir = cacheDir
        Task.detached(priority: .utility) {
            guard let tiff = imgCopy.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            let file = dir.appendingPathComponent("\(keyCopy).png")
            try? png.write(to: file)
        }
    }

    private func fetchFromSite(host: String) async -> NSImage? {
        guard let url = URL(string: "https://\(host)/favicon.ico") else { return nil }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            return decodeImage(data: data, url: url, response: response)
        } catch {
            return nil
        }
    }

    private func fetchFromGoogle(host: String) async -> NSImage? {
        guard let url = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            return decodeImage(data: data, url: url, response: response)
        } catch {
            return nil
        }
    }

    /// True for localhost, bare local names, and RFC-1918 private addresses.
    private func isPrivateHost(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "localhost"
            || h.hasSuffix(".local")
            || h.hasSuffix(".lan")
            || h.hasPrefix("192.168.")
            || h.hasPrefix("10.")
            || h.hasPrefix("172.16.")
            || h.hasPrefix("172.17.")
            || h.hasPrefix("172.18.")
            || h.hasPrefix("172.19.")
            || h.hasPrefix("172.20.")
            || h.hasPrefix("172.21.")
            || h.hasPrefix("172.22.")
            || h.hasPrefix("172.23.")
            || h.hasPrefix("172.24.")
            || h.hasPrefix("172.25.")
            || h.hasPrefix("172.26.")
            || h.hasPrefix("172.27.")
            || h.hasPrefix("172.28.")
            || h.hasPrefix("172.29.")
            || h.hasPrefix("172.30.")
            || h.hasPrefix("172.31.")
            || h.hasPrefix("127.")
            || h.hasPrefix("0.")
    }

    private func decodeImage(data: Data, url: URL, response: URLResponse? = nil) -> NSImage? {
        let isSVG = (response as? HTTPURLResponse)?.mimeType?.contains("svg") == true
            || url.pathExtension.lowercased() == "svg"
        if isSVG {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".svg")
            do {
                try data.write(to: tmp)
                let img = NSImage(contentsOf: tmp)
                try? FileManager.default.removeItem(at: tmp)
                return img
            } catch {
                return nil
            }
        }
        return NSImage(data: data)
    }

    private func normalizedKey(_ host: String) -> String {
        host.lowercased()
    }
}
