import SwiftUI

/// Settings panel showing connection info and server status.
struct SettingsView: View {
    @ObservedObject var serverState: ServerState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("debugOverlay") private var debugOverlay = false
    let onShowWelcome: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section("Device") {
                    row("Name", serverState.deviceInfo.name)
                    row("Model", serverState.deviceInfo.model)
                    row("ID", serverState.deviceInfo.id)
                    row("Platform", serverState.deviceInfo.platform)
                    row("Resolution", "\(serverState.deviceInfo.width)×\(serverState.deviceInfo.height)")
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

                Section("Debug") {
                    Toggle("Debug Overlay", isOn: $debugOverlay)
                }

                Section("Help") {
                    Button("Show Welcome Screen") {
                        dismiss()
                        onShowWelcome()
                    }

                    Button("Open Mollotov Website") {
                        openHelpURL("https://unlikeotherai.github.io/mollotov")
                    }

                    Button("Open GitHub Repository") {
                        openHelpURL("https://github.com/UnlikeOtherAI/mollotov")
                    }

                    Button("Open UnlikeOtherAI") {
                        openHelpURL("https://unlikeotherai.com")
                    }
                }

                Section("App") {
                    row("Version", serverState.deviceInfo.version)
                    #if DEBUG
                    row("Build", "Debug")
                    row("AppReveal", "Active")
                    #else
                    row("Build", "Release")
                    #endif
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
    }

    private func openHelpURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        openURL(url)
    }
}
