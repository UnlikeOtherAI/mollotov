import WebKit

/// Handles screenshot (viewport and full-page).
struct ScreenshotHandler {
    let context: HandlerContext

    func register(on router: Router) {
        router.register("screenshot") { body in await screenshot(body) }
    }

    @MainActor
    private func screenshot(_ body: [String: Any]) async -> [String: Any] {
        guard let webView = context.webView else {
            return errorResponse(code: "NO_WEBVIEW", message: "No WebView")
        }

        let fullPage = body["fullPage"] as? Bool ?? false
        let format = body["format"] as? String ?? "png"
        guard let resolution = ScreenshotResolution.parse(body["resolution"]) else {
            return errorResponse(code: "INVALID_PARAMS", message: "resolution must be 'native' or 'viewport'")
        }

        let config = WKSnapshotConfiguration()
        if !fullPage {
            config.rect = webView.bounds
        }

        do {
            let image = try await webView.takeSnapshot(configuration: config)
            let quality = ((body["quality"] as? NSNumber)?.doubleValue ?? 80) / 100.0
            return successResponse(
                try await context.screenshotPayload(
                    from: image,
                    format: format,
                    quality: quality,
                    resolution: resolution
                )
            )
        } catch {
            return errorResponse(code: "SCREENSHOT_FAILED", message: error.localizedDescription)
        }
    }
}
