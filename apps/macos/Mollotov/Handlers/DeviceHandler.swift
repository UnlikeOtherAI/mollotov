import AppKit

/// Handles getViewport, getDeviceInfo, getCapabilities.
struct DeviceHandler {
    let context: HandlerContext
    let deviceInfo: DeviceInfo
    let rendererState: RendererState

    func register(on router: Router) {
        router.register("get-viewport") { _ in await getViewport() }
        router.register("get-device-info") { _ in await getDeviceInfoResponse() }
        router.register("get-capabilities") { _ in await getCapabilities() }
        router.register("set-orientation") { _ in
            errorResponse(code: "PLATFORM_NOT_SUPPORTED", message: "Orientation is not supported on macOS")
        }
        router.register("get-orientation") { _ in
            successResponse(["orientation": "landscape", "locked": NSNull()])
        }
    }

    @MainActor
    private func getViewport() async -> [String: Any] {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let scale = screen.backingScaleFactor
        return [
            "width": Int(screen.frame.width),
            "height": Int(screen.frame.height),
            "devicePixelRatio": scale,
            "platform": "macos",
            "deviceName": deviceInfo.name,
            "orientation": "landscape",
        ]
    }

    @MainActor
    private func getDeviceInfoResponse() async -> [String: Any] {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        return [
            "device": [
                "id": deviceInfo.id,
                "name": deviceInfo.name,
                "model": deviceInfo.model,
                "platform": "macos",
            ],
            "display": [
                "width": deviceInfo.width,
                "height": deviceInfo.height,
                "scale": screen.backingScaleFactor,
            ],
            "network": ["ip": "0.0.0.0", "port": deviceInfo.port],
            "browser": [
                "engine": rendererState.activeEngine.rawValue,
                "version": ProcessInfo.processInfo.operatingSystemVersionString,
            ],
            "app": ["version": deviceInfo.version, "build": "1"],
            "system": [
                "os": "macOS",
                "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            ],
        ]
    }

    @MainActor
    private func getCapabilities() async -> [String: Any] {
        [
            "cdp": rendererState.activeEngine == .chromium,
            "nativeAPIs": true,
            "bridgeScripts": true,
            "screenshot": true,
            "fullPageScreenshot": true,
            "cookies": true,
            "storage": true,
            "geolocation": false,
            "requestInterception": rendererState.activeEngine == .chromium,
            "consoleLogs": true,
            "networkLogs": true,
            "mutations": true,
            "shadowDOM": true,
            "clipboard": true,
            "keyboard": false,
            "tabs": true,
            "iframes": true,
            "dialogs": true,
            "rendererSwitching": true,
        ]
    }
}
