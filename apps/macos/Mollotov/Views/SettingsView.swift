import SwiftUI
import AppKit

/// Settings panel showing connection info, server status, and renderer info.
struct SettingsView: View {
    @ObservedObject var serverState: ServerState
    @ObservedObject var rendererState: RendererState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Form {
                Section("Device") {
                    row("Name", serverState.deviceInfo.name)
                    row("Model", serverState.deviceInfo.model)
                    row("ID", serverState.deviceInfo.id)
                    row("Platform", serverState.deviceInfo.platform)
                    row("Resolution", "\(serverState.deviceInfo.width) x \(serverState.deviceInfo.height)")
                }

                Section("Renderer") {
                    row("Active Engine", rendererState.activeEngine.displayName)
                    row("Available", RendererState.Engine.allCases.map(\.rawValue).joined(separator: ", "))
                }

                Section("Network") {
                    row("IP Address", serverState.ipAddress)
                    row("Port", String(serverState.deviceInfo.port))
                    row("HTTP Server", serverState.isServerRunning ? "Running" : "Stopped")
                    row("mDNS", serverState.isMDNSAdvertising ? "Advertising" : "Stopped")
                }

                Section("Connect") {
                    let url = "http://\(serverState.ipAddress):\(serverState.deviceInfo.port)"
                    Text(url)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }

                Section("App") {
                    row("Version", serverState.deviceInfo.version)
                    #if DEBUG
                    row("Build", "Debug")
                    #else
                    row("Build", "Release")
                    #endif
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                AppKitSettingsDoneButton(action: dismiss.callAsFunction)
                    .frame(width: 92, height: 34)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
    }
}

private struct AppKitSettingsDoneButton: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Done", target: context.coordinator, action: #selector(Coordinator.handlePress))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        button.keyEquivalentModifierMask = []
        button.focusRingType = .none
        button.setAccessibilityIdentifier("settings.done")
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = "Done"
    }

    final class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc
        func handlePress() {
            action()
        }
    }
}

/// Lets sheet content accept the first click after focus moves away from the browser renderer.
struct AppKitFirstMouseSheetContainer<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> FirstMouseHostingView<Content> {
        FirstMouseHostingView(rootView: content)
    }

    func updateNSView(_ nsView: FirstMouseHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
