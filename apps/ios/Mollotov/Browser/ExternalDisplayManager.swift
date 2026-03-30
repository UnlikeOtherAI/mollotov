import UIKit
import SwiftUI

/// Manages an external display (Apple TV via AirPlay).
/// When a screen connects, spins up a WKWebView window with its own HTTP server and mDNS.
@MainActor
final class ExternalDisplayManager {
    static let shared = ExternalDisplayManager()

    private(set) var isConnected = false

    private var externalWindow: UIWindow?
    private var serverState: ServerState?
    private var browserState: BrowserState?

    private let externalPort: UInt16 = 8421

    private init() {}

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in self?.attach(to: screen) }
        }
        NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.detach() }
        }

        // If an external screen is already connected at launch, attach immediately.
        if UIScreen.screens.count > 1, let screen = UIScreen.screens.last {
            attach(to: screen)
        }
    }

    private func attach(to screen: UIScreen) {
        guard externalWindow == nil else { return }

        let info = DeviceInfo.externalDisplay(
            port: Int(externalPort),
            screenSize: screen.bounds.size,
            scale: screen.scale
        )
        let bs = BrowserState()
        let ss = ServerState(deviceInfo: info)
        browserState = bs
        serverState = ss

        let view = ExternalBrowserView(browserState: bs, serverState: ss)
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .black

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        window.rootViewController = hostingController
        window.isHidden = false
        externalWindow = window

        ss.startHTTPServer()
        ss.startMDNS()
        isConnected = true

        print("[ExternalDisplay] Attached to \(screen.bounds.size), port \(externalPort)")
    }

    private func detach() {
        serverState?.stop()
        externalWindow?.isHidden = true
        externalWindow = nil
        serverState = nil
        browserState = nil
        isConnected = false

        print("[ExternalDisplay] Detached")
    }
}
