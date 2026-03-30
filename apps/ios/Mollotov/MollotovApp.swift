import SwiftUI

/// Shared orientation lock controlled by the HTTP API.
final class OrientationManager {
    static let shared = OrientationManager()
    var lock: UIInterfaceOrientationMask = .all
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.lock
    }
}

@main
struct MollotovApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var browserState = BrowserState()
    @StateObject private var serverState = ServerState()

    var body: some Scene {
        WindowGroup {
            BrowserView(browserState: browserState, serverState: serverState)
                .onAppear { startServices() }
        }
    }

    private func startServices() {
        serverState.startHTTPServer()
        serverState.startMDNS()
        #if DEBUG
        AppRevealSetup.configure()
        #endif
    }
}
