import SwiftUI

/// Safari-style bottom bar with tab strip + URL field.
/// Collapses to a minimal pill when scrolling down; expands on scroll up or tap.
struct BottomBarView: View {
    @ObservedObject var tabStore: TabStore
    @ObservedObject var browserState: BrowserState
    let onNavigate: (String) -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    @Binding var isCollapsed: Bool

    @State private var urlText: String = ""
    private let barHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if isCollapsed {
                collapsedPill
                    .transition(.opacity)
            } else {
                expandedBar
                    .transition(.opacity)
            }
        }
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
        .onAppear { urlText = browserState.currentURL }
        .onChange(of: browserState.currentURL) { newURL in urlText = newURL }
    }

    // MARK: - Expanded

    @ViewBuilder
    private var expandedBar: some View {
        if tabStore.tabs.count > 1 {
            tabStrip
        }

        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("browser.nav.back")
            .disabled(!browserState.canGoBack)

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("browser.nav.forward")
            .disabled(!browserState.canGoForward)

            TextField("URL", text: $urlText)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .accessibilityIdentifier("browser.url.field")
                .onSubmit { navigate() }

            tabCountButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - BrowserTab Strip

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabStore.tabs) { tab in
                        tabPill(tab)
                            .id(tab.id)
                    }

                    Button {
                        tabStore.addBrowserTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("browser.tabs.add")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .onChange(of: tabStore.activeBrowserTabID) { newID in
                if let newID {
                    withAnimation { proxy.scrollTo(newID) }
                }
            }
        }
    }

    private func tabPill(_ tab: BrowserTab) -> some View {
        let isActive = tab.id == tabStore.activeBrowserTabID
        return HStack(spacing: 4) {
            if tab.isStartPage {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(tabTitle(tab))
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: 120)

            if tabStore.tabs.count > 1 {
                Button {
                    tabStore.closeBrowserTab(id: tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Color(.systemGray4))
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("browser.tabs.close.\(tab.id)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color(.systemGray4) : Color(.systemGray6))
        .clipShape(Capsule())
        .onTapGesture {
            tabStore.selectBrowserTab(id: tab.id)
        }
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        Button {
            isCollapsed = false
        } label: {
            Text(domain(from: browserState.currentURL))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 6)
        .accessibilityIdentifier("browser.bottom-bar.collapsed")
    }

    // MARK: - BrowserTab Count Button

    private var tabCountButton: some View {
        Button {
            tabStore.addBrowserTab()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                Text("\(tabStore.tabs.count)")
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(width: 36, height: 36)
        }
        .accessibilityIdentifier("browser.tabs.count")
    }

    // MARK: - Helpers

    private func navigate() {
        var url = urlText.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        onNavigate(url)
    }

    private func tabTitle(_ tab: BrowserTab) -> String {
        if tab.isStartPage { return "Start Page" }
        if !tab.pageTitle.isEmpty { return tab.pageTitle }
        return domain(from: tab.currentURL)
    }

    private func domain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString.isEmpty ? "New BrowserTab" : urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
