import AppKit
import WebKit

/// Abstraction over WKWebView and CEF. All handlers interact with the browser
/// engine exclusively through this protocol via HandlerContext.
@MainActor
protocol RendererEngine: AnyObject {
    /// The engine identifier used in API responses and mDNS TXT records.
    var engineName: String { get }

    // MARK: - Navigation state
    var currentURL: URL? { get }
    var currentTitle: String { get }
    var isLoading: Bool { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var estimatedProgress: Double { get }

    // MARK: - Navigation actions
    func load(url: URL)
    func goBack()
    func goForward()
    func reload()

    // MARK: - JavaScript
    /// Evaluate JS and return the result. Equivalent to WKWebView.evaluateJavaScript.
    func evaluateJS(_ script: String) async throws -> Any?

    // MARK: - Cookies
    func allCookies() async -> [HTTPCookie]
    func setCookies(_ cookies: [HTTPCookie]) async
    func deleteCookie(_ cookie: HTTPCookie) async
    func deleteAllCookies() async

    // MARK: - Screenshot
    func takeSnapshot() async throws -> NSImage

    // MARK: - View
    /// Returns the NSView to embed in SwiftUI via NSViewRepresentable.
    func makeView() -> NSView

    // MARK: - Lifecycle callbacks
    /// Called by BrowserView when navigation state changes. Used to sync BrowserState.
    var onStateChange: (() -> Void)? { get set }

    // MARK: - Script message handling (for console/network bridge)
    /// Register a callback for messages from injected bridge scripts.
    var onScriptMessage: ((_ name: String, _ body: [String: Any]) -> Void)? { get set }
}
