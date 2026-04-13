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
    private var lastHistoryURL: String = ""
    private var lastHistoryTitle: String = ""
    private var lastObservedHistoryClearGeneration = HistoryStore.shared.clearGeneration

    init(webView: WKWebView, isStartPage: Bool = true) {
        self.webView = webView
        self.isStartPage = isStartPage
        setupObservations()
    }

    private func setupObservations() {
        observations.append(webView.observe(\.url) { [weak self] wv, _ in
            Task { @MainActor in
                guard let self else { return }
                let nextURL = wv.url?.absoluteString ?? ""
                self.currentURL = nextURL
                self.recordHistoryIfNeeded(url: nextURL)
            }
        })
        observations.append(webView.observe(\.title) { [weak self] wv, _ in
            Task { @MainActor in
                guard let self else { return }
                let nextTitle = wv.title ?? ""
                self.pageTitle = nextTitle
                self.updateHistoryTitleIfNeeded(title: nextTitle)
            }
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

    private func recordHistoryIfNeeded(url: String) {
        syncHistoryTrackingIfNeeded()
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, trimmedURL != lastHistoryURL else { return }

        lastHistoryURL = trimmedURL
        lastHistoryTitle = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        HistoryStore.shared.record(url: trimmedURL, title: pageTitle)
    }

    private func updateHistoryTitleIfNeeded(title: String) {
        syncHistoryTrackingIfNeeded()
        let trimmedURL = currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedTitle.isEmpty else { return }
        guard trimmedURL == lastHistoryURL, trimmedTitle != lastHistoryTitle else { return }

        lastHistoryTitle = trimmedTitle
        HistoryStore.shared.updateLatestTitle(for: trimmedURL, title: trimmedTitle)
    }

    private func syncHistoryTrackingIfNeeded() {
        let currentGeneration = HistoryStore.shared.clearGeneration
        guard currentGeneration != lastObservedHistoryClearGeneration else { return }
        lastObservedHistoryClearGeneration = currentGeneration
        lastHistoryURL = ""
        lastHistoryTitle = ""
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
