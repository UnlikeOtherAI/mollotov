import SwiftUI

/// URL bar with navigation buttons, URL field, renderer toggle, and settings.
struct URLBarView: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject var rendererState: RendererState
    let onNavigate: (String) -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onSwitchRenderer: (RendererState.Engine) -> Void
    let onSettings: () -> Void

    @State private var urlText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!browserState.canGoBack)
            .buttonStyle(.borderless)

            Button(action: onForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!browserState.canGoForward)
            .buttonStyle(.borderless)

            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            // URL field
            TextField("URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { navigate() }

            // Renderer toggle
            Picker("", selection: Binding(
                get: { rendererState.activeEngine },
                set: { onSwitchRenderer($0) }
            )) {
                Image(systemName: "safari").tag(RendererState.Engine.webkit)
                Image(systemName: "globe").tag(RendererState.Engine.chromium)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .disabled(rendererState.isSwitching)

            // Settings
            Button(action: onSettings) {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear { urlText = browserState.currentURL }
        .onChange(of: browserState.currentURL) { _, newURL in
            urlText = newURL
        }
    }

    private func navigate() {
        var url = urlText.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        onNavigate(url)
    }
}
