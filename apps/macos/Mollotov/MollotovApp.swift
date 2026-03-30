import SwiftUI

@main
struct MollotovApp: App {
    @StateObject private var browserState = BrowserState()
    @StateObject private var serverState = ServerState()
    @StateObject private var rendererState = RendererState()

    var body: some Scene {
        WindowGroup {
            BrowserView(
                browserState: browserState,
                serverState: serverState,
                rendererState: rendererState
            )
            .onAppear { startServices() }
            .frame(minWidth: 800, minHeight: 600)
        }
    }

    private func startServices() {
        serverState.rendererState = rendererState
        serverState.startHTTPServer()
        serverState.startMDNS()
    }
}
