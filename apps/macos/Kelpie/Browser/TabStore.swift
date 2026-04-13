import Foundation
import AppKit
import Combine

@MainActor
final class Tab: ObservableObject, Identifiable {
    let id = UUID()
    let renderer: WKWebViewRenderer

    @Published var title: String = "Start Page"
    @Published var currentURL: String = ""
    @Published var isLoading: Bool = false
    @Published var favicon: NSImage?
    @Published var isStartPage: Bool = true

    private var lastHistoryURL: String = ""
    private var lastHistoryTitle: String = ""
    private var lastObservedHistoryClearGeneration = HistoryStore.shared.clearGeneration

    init() {
        self.renderer = WKWebViewRenderer()
    }

    deinit {
        // Break WKUserContentController retain cycle before the renderer is released.
        // Tab is always created and destroyed on the main actor.
        MainActor.assumeIsolated {
            renderer.invalidate()
        }
    }

    func recordHistoryIfNeeded(url: String, title: String) {
        syncHistoryTrackingIfNeeded()
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, trimmedURL != lastHistoryURL else { return }

        lastHistoryURL = trimmedURL
        lastHistoryTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        HistoryStore.shared.record(url: trimmedURL, title: title)
    }

    func updateHistoryTitleIfNeeded(url: String, title: String) {
        syncHistoryTrackingIfNeeded()
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

@MainActor
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabID: UUID?

    var activeTab: Tab? { tabs.first { $0.id == activeTabID } }

    // Keyed by tab ID so unbind() can cancel cleanly.
    private var tabSinks: [UUID: AnyCancellable] = [:]

    init() {
        if let session = SessionStore.load() {
            let restoredTabs = session.urls.compactMap { value -> Tab? in
                guard let url = URL(string: value) else { return nil }
                let tab = Tab()
                tab.isStartPage = false
                bind(tab)
                tab.renderer.load(url: url)
                return tab
            }
            if !restoredTabs.isEmpty {
                tabs = restoredTabs
                activeTabID = restoredTabs[min(session.activeIndex, restoredTabs.count - 1)].id
                return
            }
        }

        let initial = Tab()
        bind(initial)
        tabs = [initial]
        activeTabID = initial.id
    }

    @discardableResult
    func addTab() -> Tab {
        let tab = Tab()
        bind(tab)
        tabs.append(tab)
        activeTabID = tab.id
        persistSession()
        return tab
    }

    func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }

        if tabs.count == 1 {
            unbind(tabs[0])
            let replacement = Tab()
            bind(replacement)
            tabs = [replacement]
            activeTabID = replacement.id
            persistSession()
            return
        }

        unbind(tabs[idx])
        tabs.remove(at: idx)
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
        }
        persistSession()
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        persistSession()
    }

    private func bind(_ tab: Tab) {
        tab.renderer.onStateChange = { [weak tab, weak renderer = tab.renderer] in
            guard let tab, let renderer else { return }
            let nextTitle = renderer.currentTitle.isEmpty ? "Start Page" : renderer.currentTitle
            let nextURL = renderer.currentURL?.absoluteString ?? ""
            let rawTitle = renderer.currentTitle
            tab.title = nextTitle
            tab.currentURL = nextURL
            tab.isLoading = renderer.isLoading
            tab.recordHistoryIfNeeded(url: nextURL, title: rawTitle)
            tab.updateHistoryTitleIfNeeded(url: nextURL, title: rawTitle)
        }
        tabSinks[tab.id] = tab.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.persistSession()
            }
    }

    private func unbind(_ tab: Tab) {
        tab.renderer.onStateChange = nil
        tabSinks.removeValue(forKey: tab.id)
    }

    private func persistSession() {
        SessionStore.save(tabs: tabs, activeID: activeTabID)
    }
}
