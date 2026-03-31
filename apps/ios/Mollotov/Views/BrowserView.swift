import SwiftUI
import WebKit

/// Main browser screen: URL bar + WKWebView + floating action menu.
struct BrowserView: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject var serverState: ServerState
    @State private var showSettings = false
    @State private var showBookmarks = false
    @State private var showHistory = false
    @State private var showNetworkInspector = false
    @AppStorage("hideWelcomeCard") private var hideWelcome = false
    @State private var showWelcome = true
    @State private var webView: WKWebView?
    @AppStorage("debugOverlay") private var debugOverlayEnabled = false
    @State private var debugText = ""
    private let safariAuth = SafariAuthHelper()
    private let debugTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Loading progress bar
                if browserState.isLoading {
                    ProgressView(value: browserState.progress)
                        .progressViewStyle(.linear)
                }

                // URL bar
                URLBarView(
                    browserState: browserState,
                    onNavigate: { url in
                        guard let webView, let urlObj = URL(string: url) else { return }
                        webView.load(URLRequest(url: urlObj))
                    },
                    onBack: { webView?.goBack() },
                    onForward: { webView?.goForward() }
                )

                // WebView
                WebViewContainer(browserState: browserState, handlerContext: serverState.handlerContext) { wv in
                    webView = wv
                    serverState.webView = wv
                    serverState.handlerContext.webView = wv
                }
            }

            if showWelcome && !hideWelcome {
                WelcomeCardView { showWelcome = false }
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Floating action menu overlay
            FloatingMenuView(
                onReload: { webView?.reload() },
                onSafariAuth: {
                    guard let webView, let url = webView.url else { return }
                    safariAuth.authenticate(url: url, webView: webView)
                },
                onSettings: { showSettings = true },
                onBookmarks: { showBookmarks = true },
                onHistory: { showHistory = true },
                onNetworkInspector: { showNetworkInspector = true }
            )
        }
        .overlay(alignment: .bottomLeading) {
            if debugOverlayEnabled {
                Text(debugText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.75))
                    .cornerRadius(6)
                    .padding(8)
            }
        }
        .onReceive(debugTimer) { _ in if debugOverlayEnabled { updateDebug() } }
        .onChange(of: debugOverlayEnabled) { enabled in if enabled { updateDebug() } }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: browserState.currentURL) { newURL in
            HistoryStore.shared.record(url: newURL, title: browserState.pageTitle)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(serverState: serverState)
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(
                currentTitle: browserState.pageTitle,
                currentURL: browserState.currentURL,
                onNavigate: { url in
                    guard let webView, let urlObj = URL(string: url) else { return }
                    webView.load(URLRequest(url: urlObj))
                }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(onNavigate: { url in
                guard let webView, let urlObj = URL(string: url) else { return }
                webView.load(URLRequest(url: urlObj))
            })
        }
        .sheet(isPresented: $showNetworkInspector) {
            NetworkInspectorView()
        }
    }

    private func updateDebug() {
        let screens = UIScreen.screens
        let mgr = ExternalDisplayManager.shared
        var lines: [String] = []

        // Screens
        for (i, s) in screens.enumerated() {
            let o = s.bounds.origin
            lines.append("scr[\(i)] \(Int(o.x)),\(Int(o.y)) \(Int(s.bounds.width))x\(Int(s.bounds.height)) @\(Int(s.scale))x nat=\(Int(s.nativeScale))x mir=\(s.mirrored != nil)")
        }

        // External display state
        lines.append("ext: \(mgr.isConnected ? "ON" : "off") path=\(mgr.attachPath ?? "nil")")

        // External window + webview layout
        if let win = mgr.externalWindow {
            let wf = win.frame
            let wb = win.bounds
            lines.append("win: (\(Int(wf.origin.x)),\(Int(wf.origin.y))) \(Int(wf.width))x\(Int(wf.height)) bounds=\(Int(wb.width))x\(Int(wb.height))")
        }
        if let wv = mgr.serverState?.handlerContext.webView {
            let f = wv.frame
            let b = wv.bounds
            lines.append("wv: (\(Int(f.origin.x)),\(Int(f.origin.y))) \(Int(f.width))x\(Int(f.height)) bounds=\(Int(b.width))x\(Int(b.height))")
            lines.append("wv: zoom=\(String(format: "%.2f", wv.pageZoom)) csf=\(String(format: "%.1f", wv.contentScaleFactor))")
            let sv = wv.scrollView
            lines.append("sv: content=\(Int(sv.contentSize.width))x\(Int(sv.contentSize.height)) offset=(\(Int(sv.contentOffset.x)),\(Int(sv.contentOffset.y)))")
        }

        lines.append("phone: port \(serverState.deviceInfo.port)")
        debugText = lines.joined(separator: "\n")
    }
}
