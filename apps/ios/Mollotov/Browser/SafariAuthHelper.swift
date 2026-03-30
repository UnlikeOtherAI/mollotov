import UIKit
import WebKit

/// Opens the current page URL in Safari so the user can authenticate
/// with Safari's saved passwords, then reloads the page on return.
@MainActor
final class SafariAuthHelper {
    private weak var webView: WKWebView?
    private var needsReloadOnReturn = false

    func authenticate(url: URL, webView: WKWebView) {
        self.webView = webView
        self.needsReloadOnReturn = true
        UIApplication.shared.open(url)
    }

    /// Called when the app returns to foreground — reload the page
    /// so any cookies set in Safari (via universal links / shared
    /// credential store) take effect.
    func onAppDidBecomeActive() {
        guard needsReloadOnReturn, let webView else { return }
        needsReloadOnReturn = false
        webView.reload()
    }
}
