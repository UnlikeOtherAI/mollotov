import Foundation
import WebKit

/// Manages the set of open browser tabs. Creates configured WKWebViews for new tabs.
@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var activeBrowserTabID: UUID?

    var activeBrowserTab: BrowserTab? { tabs.first { $0.id == activeBrowserTabID } }

    private weak var handlerContext: HandlerContext?

    init(handlerContext: HandlerContext?) {
        self.handlerContext = handlerContext
        let showStartPage = !UserDefaults.standard.bool(forKey: "hideWelcomeCard")
        let tab = createBrowserTab(isStartPage: showStartPage)
        tabs = [tab]
        activeBrowserTabID = tab.id
        if !showStartPage {
            let homeURL = UserDefaults.standard.string(forKey: "homeURL") ?? defaultHomeURL
            if let url = URL(string: homeURL) {
                tab.webView.load(URLRequest(url: url))
            }
        }
    }

    @discardableResult
    func addBrowserTab(url: String? = nil) -> BrowserTab {
        let tab = createBrowserTab()
        tabs.append(tab)
        activeBrowserTabID = tab.id
        if let url, let parsed = URL(string: url) {
            tab.isStartPage = false
            tab.webView.load(URLRequest(url: parsed))
        }
        return tab
    }

    func closeBrowserTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs.remove(at: index)
        tab.invalidate()
        if activeBrowserTabID == id {
            activeBrowserTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func selectBrowserTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeBrowserTabID = id
    }

    private func createBrowserTab(isStartPage: Bool = true) -> BrowserTab {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = WebViewDefaults.sharedWebsiteDataStore

        if let handlerContext {
            let ucc = config.userContentController
            ucc.addUserScript(NetworkBridge.bridgeScript)
            ucc.add(handlerContext, name: "kelpieNetwork")
            ucc.addUserScript(ConsoleHandler.bridgeScript)
            ucc.add(handlerContext, name: "kelpieConsole")
            ucc.add(handlerContext, name: "kelpie3DSnapshot")
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = WebViewDefaults.sharedUserAgent

        return BrowserTab(webView: webView, isStartPage: isStartPage)
    }
}
