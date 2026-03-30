import SwiftUI

/// Settings panel showing connection info, server status, renderer info, and window controls.
struct SettingsView: View {
    @ObservedObject var serverState: ServerState
    @ObservedObject var rendererState: RendererState
    @Environment(\.dismiss) private var dismiss

    @State private var windowWidth: String = ""
    @State private var windowHeight: String = ""

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

                Section("Window Size") {
                    HStack {
                        TextField("Width", text: $windowWidth)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("x")
                            .foregroundColor(.secondary)
                        TextField("Height", text: $windowHeight)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Button("Resize") {
                            resizeWindow()
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(presetSizes, id: \.label) { preset in
                            Button(preset.label) {
                                applySize(width: preset.width, height: preset.height)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
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
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 580)
        .onAppear {
            if let window = NSApplication.shared.keyWindow {
                windowWidth = String(Int(window.frame.width))
                windowHeight = String(Int(window.frame.height))
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

    private func resizeWindow() {
        guard let w = Int(windowWidth), let h = Int(windowHeight), w > 0, h > 0 else { return }
        applySize(width: CGFloat(w), height: CGFloat(h))
    }

    private func applySize(width: CGFloat, height: CGFloat) {
        guard let window = NSApplication.shared.keyWindow else { return }
        let origin = window.frame.origin
        let newFrame = NSRect(x: origin.x, y: origin.y + window.frame.height - height,
                              width: width, height: height)
        window.setFrame(newFrame, display: true, animate: true)
        windowWidth = String(Int(width))
        windowHeight = String(Int(height))
    }

    private var presetSizes: [(label: String, width: CGFloat, height: CGFloat)] {
        [
            ("iPhone SE", 375, 667),
            ("iPhone 15", 393, 852),
            ("iPad", 1024, 768),
            ("1280x800", 1280, 800),
            ("1920x1080", 1920, 1080),
        ]
    }
}
