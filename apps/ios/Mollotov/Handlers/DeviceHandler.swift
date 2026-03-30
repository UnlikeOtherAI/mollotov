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
