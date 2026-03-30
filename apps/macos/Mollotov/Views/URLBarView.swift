import SwiftUI

/// URL bar with navigation buttons, URL field, and renderer toggle.
struct URLBarView: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject var rendererState: RendererState
    let onNavigate: (String) -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onSwitchRenderer: (RendererState.Engine) -> Void

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

            // Renderer toggle — Font Awesome brand icons
            HStack(spacing: 0) {
                rendererButton(engine: .webkit, icon: FontAwesome.safari)
                rendererButton(engine: .chromium, icon: FontAwesome.chrome)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .disabled(rendererState.isSwitching)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear { urlText = browserState.currentURL }
        .onChange(of: browserState.currentURL) { _, newURL in
            urlText = newURL
        }
    }

    @ViewBuilder
    private func rendererButton(engine: RendererState.Engine, icon: String) -> some View {
        let isActive = rendererState.activeEngine == engine
        Button {
            onSwitchRenderer(engine)
        } label: {
            FAIcon(icon: icon, size: 14)
                .frame(width: 36, height: 24)
                .foregroundColor(isActive ? .white : .primary)
                .background(isActive ? Color.accentColor : Color.clear)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    private func navigate() {
        var url = urlText.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        onNavigate(url)
    }
}
