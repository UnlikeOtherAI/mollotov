import SwiftUI

/// Device viewport presets for window resizing.
enum DevicePreset: String, CaseIterable, Identifiable {
    case iphonePortrait = "iPhone P"
    case iphoneLandscape = "iPhone L"
    case tabletPortrait = "Tablet P"
    case tabletLandscape = "Tablet L"
    case laptop = "Laptop"

    var id: String { rawValue }

    var size: NSSize {
        switch self {
        case .iphonePortrait:  return NSSize(width: 393, height: 852)
        case .iphoneLandscape: return NSSize(width: 852, height: 393)
        case .tabletPortrait:  return NSSize(width: 820, height: 1180)
        case .tabletLandscape: return NSSize(width: 1180, height: 820)
        case .laptop:          return NSSize(width: 1280, height: 800)
        }
    }

    var icon: String {
        switch self {
        case .iphonePortrait:  return "iphone"
        case .iphoneLandscape: return "iphone.landscape"
        case .tabletPortrait:  return "ipad"
        case .tabletLandscape: return "ipad.landscape"
        case .laptop:          return "laptopcomputer"
        }
    }
}

/// URL bar with navigation buttons, URL field, renderer toggle, and device size selector.
struct URLBarView: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject var rendererState: RendererState
    let onNavigate: (String) -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onSwitchRenderer: (RendererState.Engine) -> Void

    @State private var urlText: String = ""
    @State private var selectedPreset: DevicePreset = .laptop

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

            // URL field — not focused on launch
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

            // Device size selector
            Picker("", selection: $selectedPreset) {
                ForEach(DevicePreset.allCases) { preset in
                    Image(systemName: preset.icon).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: selectedPreset) { _, preset in
                resizeWindow(to: preset.size)
            }
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

    private func resizeWindow(to size: NSSize) {
        guard let window = NSApplication.shared.keyWindow else { return }
        let origin = window.frame.origin
        let newFrame = NSRect(
            x: origin.x,
            y: origin.y + window.frame.height - size.height,
            width: size.width,
            height: size.height
        )
        window.setFrame(newFrame, display: true, animate: true)
    }
}
