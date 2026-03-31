import UIKit
import WebKit

/// Manages an external display (Apple TV via AirPlay).
/// Uses UIScreen notifications to detect AirPlay, then scans connected scenes
/// for the external display UIWindowScene and creates a fullscreen WKWebView on it.
@MainActor
final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()

    var isConnected = false
    let externalPort: UInt16 = 8421
    var attachPath: String?

    var serverState: ServerState?
    var browserState: BrowserState?
    var externalWindow: UIWindow?

    private init() {}

    func startMonitoring() {
        scanForExternalScene()

        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scanForExternalScene() }
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.detach() }
        }
    }

    private func scanForExternalScene() {
        guard !isConnected else { return }

        for scene in UIApplication.shared.connectedScenes {
            if scene.session.role == .windowExternalDisplayNonInteractive,
               let windowScene = scene as? UIWindowScene {
                attach(to: windowScene)
                return
            }
        }
    }

    private func attach(to windowScene: UIWindowScene) {
        let screen = windowScene.screen
        let screenBounds = screen.bounds

        let info = DeviceInfo.externalDisplay(
            port: Int(externalPort),
            screenSize: screenBounds.size,
            scale: screen.scale
        )
        let bs = BrowserState()
        let ss = ServerState(deviceInfo: info)

        // Build WKWebView directly in UIKit — avoids SwiftUI layout confusion
        // about which screen's coordinate space to use.
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        // Inject bridge scripts
        let ucc = config.userContentController
        ucc.addUserScript(NetworkBridge.bridgeScript)
        ucc.add(ss.handlerContext, name: "mollotovNetwork")
        ucc.addUserScript(ConsoleHandler.bridgeScript)
        ucc.add(ss.handlerContext, name: "mollotovConsole")

        // Create the WebView at half the screen size (1920x1080 for 4K TV).
        // This gives a natural 1920px CSS viewport — desktop-width layout.
        // contentScaleFactor=2 makes WebKit render at 3840x2160 pixels (4K).
        // The 2x transform fills the full screen with pixel-perfect quality.
        let cssSize = CGSize(width: screenBounds.width / 2, height: screenBounds.height / 2)

        let vc = UIViewController()
        vc.view.frame = screenBounds
        vc.view.backgroundColor = .black

        let webView = WKWebView(frame: CGRect(origin: .zero, size: cssSize), configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/604.1"
        webView.contentScaleFactor = 2
        webView.layer.anchorPoint = .zero
        webView.layer.position = .zero
        webView.transform = CGAffineTransform(scaleX: 2, y: 2)
        vc.view.addSubview(webView)

        let window = UIWindow(windowScene: windowScene)
        window.frame = screenBounds
        window.rootViewController = vc
        window.makeKeyAndVisible()

        // Load home page
        if let url = URL(string: bs.currentURL) {
            webView.load(URLRequest(url: url))
        }

        // Wire up server state
        ss.webView = webView
        ss.handlerContext.webView = webView

        browserState = bs
        serverState = ss
        externalWindow = window
        isConnected = true
        attachPath = "scene-scan"

        ss.startHTTPServer()
        ss.startMDNS()

        // Track navigation changes for history
        let coordinator = TVWebViewObserver(browserState: bs)
        webView.navigationDelegate = coordinator
        objc_setAssociatedObject(webView, &tvObserverKey, coordinator, .OBJC_ASSOCIATION_RETAIN)
    }

    func detach() {
        guard isConnected else { return }
        serverState?.stop()
        externalWindow?.isHidden = true
        externalWindow = nil
        serverState = nil
        browserState = nil
        isConnected = false
        attachPath = nil
    }
}

private var tvObserverKey: UInt8 = 0

/// Minimal WKNavigationDelegate to sync BrowserState for the TV WebView.
private class TVWebViewObserver: NSObject, WKNavigationDelegate {
    let browserState: BrowserState

    init(browserState: BrowserState) {
        self.browserState = browserState
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            browserState.currentURL = webView.url?.absoluteString ?? ""
            browserState.pageTitle = webView.title ?? ""
            browserState.isLoading = false
            HistoryStore.shared.record(url: browserState.currentURL, title: browserState.pageTitle)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            browserState.isLoading = true
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Task { @MainActor in
            browserState.currentURL = webView.url?.absoluteString ?? ""
            browserState.pageTitle = webView.title ?? ""
        }
    }
}
