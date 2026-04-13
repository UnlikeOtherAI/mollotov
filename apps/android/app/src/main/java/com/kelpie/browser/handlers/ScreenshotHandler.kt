package com.kelpie.browser.handlers

import com.kelpie.browser.network.Router
import com.kelpie.browser.network.errorResponse
import com.kelpie.browser.network.successResponse

enum class ScreenshotResolution(
    val wireValue: String,
) {
    NATIVE("native"),
    VIEWPORT("viewport"),
    ;

    companion object {
        fun parse(raw: Any?): ScreenshotResolution? =
            when (raw) {
                null -> NATIVE
                is String -> entries.firstOrNull { it.wireValue == raw }
                else -> null
            }
    }
}

data class ScreenshotViewportMetrics(
    val viewportWidth: Int,
    val viewportHeight: Int,
    val devicePixelRatio: Double,
) {
    fun metadata(
        imageWidth: Int,
        imageHeight: Int,
        format: String,
        resolution: ScreenshotResolution,
    ): Map<String, Any> {
        val scaleX = if (viewportWidth > 0) imageWidth.toDouble() / viewportWidth.toDouble() else 1.0
        val scaleY = if (viewportHeight > 0) imageHeight.toDouble() / viewportHeight.toDouble() else 1.0
        return mapOf(
            "width" to imageWidth,
            "height" to imageHeight,
            "format" to format,
            "resolution" to resolution.wireValue,
            "coordinateSpace" to "viewport-css-pixels",
            "viewportWidth" to viewportWidth,
            "viewportHeight" to viewportHeight,
            "devicePixelRatio" to devicePixelRatio,
            "imageScaleX" to scaleX,
            "imageScaleY" to scaleY,
        )
    }
}

class ScreenshotHandler(
    private val ctx: HandlerContext,
) {
    fun register(router: Router) {
        router.register("screenshot") { screenshot(it) }
    }

    private suspend fun screenshot(body: Map<String, Any?>): Map<String, Any?> {
        val format = body["format"] as? String ?: "png"
        val quality = (body["quality"] as? Int) ?: 80
        val resolution =
            ScreenshotResolution.parse(body["resolution"])
                ?: return errorResponse("INVALID_PARAMS", "resolution must be 'native' or 'viewport'")
        val payload =
            ctx.captureScreenshotPayload(format, quality, resolution)
                ?: return errorResponse("SCREENSHOT_FAILED", "Failed to capture screenshot")
        return successResponse(payload)
    }
}
