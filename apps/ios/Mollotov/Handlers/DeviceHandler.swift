import UIKit
import WebKit

/// Handles getViewport, getDeviceInfo, getCapabilities.
struct DeviceHandler {
    let context: HandlerContext
    let deviceInfo: DeviceInfo

    func register(on router: Router) {
        router.register("get-viewport") { _ in await getViewport() }
        router.register("get-device-info") { _ in await getDeviceInfoResponse() }
        router.register("get-capabilities") { _ in getCapabilities() }
        router.register("set-orientation") { body in await setOrientation(body) }
        router.register("get-orientation") { _ in await getOrientation() }
    }

    @MainActor
    private func getViewport() async -> [String: Any] {
        guard let webView = context.webView else { return errorResponse(code: "NO_WEBVIEW", message: "No WebView") }
        let bounds = webView.bounds
        let scale = UIScreen.main.scale
        let orientation = UIDevice.current.orientation.isLandscape ? "landscape" : "portrait"
        return [
            "width": Int(bounds.width),
            "height": Int(bounds.height),
            "devicePixelRatio": scale,
            "platform": "ios",
            "deviceName": deviceInfo.name,
            "orientation": orientation,
        ]
    }

    private func getDeviceInfoResponse() async -> [String: Any] {
        let device = UIDevice.current
        let screen = await UIScreen.main
        return [
            "device": [
                "id": deviceInfo.id,
                "name": deviceInfo.name,
                "model": deviceInfo.model,
                "platform": "ios",
            ],
            "display": [
                "width": deviceInfo.width,
                "height": deviceInfo.height,
                "scale": await screen.scale,
            ],
            "network": ["ip": "0.0.0.0", "port": deviceInfo.port],
            "browser": ["engine": "WebKit", "version": device.systemVersion],
            "app": ["version": deviceInfo.version, "build": "1"],
            "system": ["os": "iOS", "osVersion": device.systemVersion],
        ]
    }

    @MainActor
    private func getOrientation() async -> [String: Any] {
        let isLandscape = UIDevice.current.orientation.isLandscape
        let lock = OrientationManager.shared.lock
        let locked: String? = switch lock {
        case .landscape, .landscapeLeft, .landscapeRight: "landscape"
        case .portrait, .portraitUpsideDown: "portrait"
        default: nil
        }
        return successResponse([
            "orientation": isLandscape ? "landscape" : "portrait",
            "locked": locked as Any,
        ])
    }

    @MainActor
    private func setOrientation(_ body: [String: Any]) async -> [String: Any] {
        guard let orientation = body["orientation"] as? String else {
            return errorResponse(code: "MISSING_PARAM", message: "orientation is required (portrait|landscape|auto)")
        }
        let manager = OrientationManager.shared
        switch orientation.lowercased() {
        case "landscape":
            manager.lock = .landscape
            // Request geometry update on the window scene
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        case "portrait":
            manager.lock = .portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        case "auto":
            manager.lock = .all
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        default:
            return errorResponse(code: "INVALID_PARAM", message: "orientation must be portrait, landscape, or auto")
        }
        return successResponse(["orientation": orientation])
    }

    private func getCapabilities() -> [String: Any] {
        [
            "cdp": false,
            "nativeAPIs": true,
            "bridgeScripts": true,
            "screenshot": true,
            "fullPageScreenshot": true,
            "cookies": true,
            "storage": true,
            "geolocation": false,
            "requestInterception": false,
            "consoleLogs": true,
            "networkLogs": false,
            "mutations": true,
            "shadowDOM": true,
            "clipboard": true,
            "keyboard": true,
            "tabs": true,
            "iframes": true,
            "dialogs": true,
        ]
    }
}
