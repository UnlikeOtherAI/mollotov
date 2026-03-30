import Foundation

/// Migrates cookies from one renderer engine to another.
/// Called during renderer switches to preserve login sessions.
@MainActor
struct CookieMigrator {
    static func migrate(from source: any RendererEngine, to target: any RendererEngine) async {
        let cookies = await source.allCookies()
        guard !cookies.isEmpty else { return }
        await target.setCookies(cookies)
    }
}
