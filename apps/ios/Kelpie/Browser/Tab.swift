import Foundation
import WebKit

/// A single browser tab. Owns a WKWebView and observes its state via KVO.
@MainActor
final class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView

    @Published var currentURL: String = ""
    @Published var pageTitle: String = ""
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isStartPage: Bool

    private var observations: [NSKeyValueObservation] = []

    init(webView: WKWebView, isStartPage: Bool = true) {
        self.webView = webView
        self.isStartPage = isStartPage
        setupObservations()
    }

    private func setupObservations() {
        observations.append(webView.observe(\.url) { [weak self] wv, _ in
            Task { @MainActor in self?.currentURL = wv.url?.absoluteString ?? "" }
        })
        observations.append(webView.observe(\.title) { [weak self] wv, _ in
            Task { @MainActor in self?.pageTitle = wv.title ?? "" }
        })
        observations.append(webView.observe(\.isLoading) { [weak self] wv, _ in
            Task { @MainActor in self?.isLoading = wv.isLoading }
        })
        observations.append(webView.observe(\.estimatedProgress) { [weak self] wv, _ in
            Task { @MainActor in self?.progress = wv.estimatedProgress }
        })
        observations.append(webView.observe(\.canGoBack) { [weak self] wv, _ in
            Task { @MainActor in self?.canGoBack = wv.canGoBack }
        })
        observations.append(webView.observe(\.canGoForward) { [weak self] wv, _ in
            Task { @MainActor in self?.canGoForward = wv.canGoForward }
        })
    }

    /// Break WKUserContentController retain cycles before deallocation.
    func invalidate() {
        observations.removeAll()
        let ucc = webView.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "kelpieNetwork")
        ucc.removeScriptMessageHandler(forName: "kelpieConsole")
        ucc.removeScriptMessageHandler(forName: "kelpie3DSnapshot")
    }
}
