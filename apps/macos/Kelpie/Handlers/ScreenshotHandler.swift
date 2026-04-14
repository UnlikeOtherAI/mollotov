import AppKit

enum ScreenshotResolution: String {
    case native
    case viewport

    static func parse(_ raw: Any?) -> Self? {
        guard let raw else { return .native }
        guard let value = raw as? String else { return nil }
        return Self(rawValue: value)
    }
}

struct ScreenshotViewportMetrics {
    let viewportWidth: Int
    let viewportHeight: Int
    let devicePixelRatio: Double

    func metadata(
        imageWidth: Int,
        imageHeight: Int,
        format: String,
        resolution: ScreenshotResolution
    ) -> [String: Any] {
        let scaleX = viewportWidth > 0 ? Double(imageWidth) / Double(viewportWidth) : 1
        let scaleY = viewportHeight > 0 ? Double(imageHeight) / Double(viewportHeight) : 1
        return [
            "width": imageWidth,
            "height": imageHeight,
            "format": format,
            "resolution": resolution.rawValue,
            "coordinateSpace": "viewport-css-pixels",
            "viewportWidth": viewportWidth,
            "viewportHeight": viewportHeight,
            "devicePixelRatio": devicePixelRatio,
            "imageScaleX": scaleX,
            "imageScaleY": scaleY
        ]
    }
}

func bitmapRepresentation(of image: NSImage) -> NSBitmapImageRep? {
    if let data = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: data) {
        return bitmap
    }
    return nil
}

func scaledBitmapRepresentation(
    from image: NSImage,
    to resolution: ScreenshotResolution,
    using viewport: ScreenshotViewportMetrics
) -> NSBitmapImageRep? {
    guard let bitmap = bitmapRepresentation(of: image) else {
        return nil
    }
    guard resolution == .viewport else {
        return bitmap
    }
    let targetWidth = max(Int(round(Double(bitmap.pixelsWide) / max(viewport.devicePixelRatio, 1.0))), 1)
    let targetHeight = max(Int(round(Double(bitmap.pixelsHigh) / max(viewport.devicePixelRatio, 1.0))), 1)
    guard targetWidth != bitmap.pixelsWide || targetHeight != bitmap.pixelsHigh else {
        return bitmap
    }
    guard let scaled = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetWidth,
        pixelsHigh: targetHeight,
        bitsPerSample: bitmap.bitsPerSample,
        samplesPerPixel: bitmap.samplesPerPixel,
        hasAlpha: bitmap.hasAlpha,
        isPlanar: false,
        colorSpaceName: bitmap.colorSpaceName ?? .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return bitmap
    }
    scaled.size = NSSize(width: targetWidth, height: targetHeight)
    let source = NSImage(size: NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
    source.addRepresentation(bitmap)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: scaled) else {
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
        from: NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return scaled
}

/// Handles screenshot (viewport and full-page).
struct ScreenshotHandler {
    let context: HandlerContext

    func register(on router: Router) {
        router.register("screenshot") { body in await screenshot(body) }
    }

    @MainActor
    private func screenshot(_ body: [String: Any]) async -> [String: Any] {
        let tabId = HandlerContext.tabId(from: body)
        let format = body["format"] as? String ?? "png"
        guard let resolution = ScreenshotResolution.parse(body["resolution"]) else {
            return errorResponse(code: "INVALID_PARAMS", message: "resolution must be 'native' or 'viewport'")
        }

        do {
            _ = try context.resolveRenderer(tabId: tabId)
            let image = try await context.takeSnapshot(tabId: tabId)
            let quality = ((body["quality"] as? NSNumber)?.doubleValue ?? 80) / 100.0
            return successResponse(
                try await context.screenshotPayload(
                    from: image,
                    format: format,
                    quality: quality,
                    resolution: resolution,
                    tabId: tabId
                )
            )
        } catch {
            if let tabError = tabErrorResponse(from: error) { return tabError }
            return errorResponse(code: "SCREENSHOT_FAILED", message: error.localizedDescription)
        }
    }
}
