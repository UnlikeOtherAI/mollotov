import UIKit
import SwiftUI

/// Scene delegate for the Apple TV / external display window scene.
/// The system creates a scene with role `.windowExternalDisplayNonInteractive`
/// when AirPlay connects to an Apple TV. AppDelegate routes it here.
class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let screen = windowScene.screen
        let manager = ExternalDisplayManager.shared

        let info = DeviceInfo.externalDisplay(
            port: Int(manager.externalPort),
            screenSize: screen.bounds.size,
            scale: screen.scale
        )
        let bs = BrowserState()
        let ss = ServerState(deviceInfo: info)

        let view = ExternalBrowserView(browserState: bs, serverState: ss)
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .black

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        self.window = window

        manager.didAttach(browserState: bs, serverState: ss, window: window)
        ss.startHTTPServer()
        ss.startMDNS()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        ExternalDisplayManager.shared.didDetach()
        window = nil
    }
}

/// Manages state for the external display (Apple TV via AirPlay).
/// Lifecycle is driven by ExternalDisplaySceneDelegate — no polling or notifications.
final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()

    private(set) var isConnected = false
    let externalPort: UInt16 = 8421

    private var serverState: ServerState?
    private var browserState: BrowserState?
    private var externalWindow: UIWindow?

    private init() {}

    func didAttach(browserState: BrowserState, serverState: ServerState, window: UIWindow) {
        self.browserState = browserState
        self.serverState = serverState
        self.externalWindow = window
        isConnected = true
        print("[ExternalDisplay] Attached, port \(externalPort)")
    }

    func didDetach() {
        serverState?.stop()
        externalWindow = nil
        serverState = nil
        browserState = nil
        isConnected = false
        print("[ExternalDisplay] Detached")
    }
}
