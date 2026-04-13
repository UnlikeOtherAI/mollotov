package com.kelpie.browser.handlers

object JSEscape {
    private const val DEFAULT_OVERLAY_RGB = "59,130,246"

    fun string(value: String): String =
        value
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")

    fun hexToRGB(hex: String?): String {
        val normalized = hex?.removePrefix("#") ?: return DEFAULT_OVERLAY_RGB
        if (normalized.length != 6) return DEFAULT_OVERLAY_RGB
        return try {
            val red = normalized.substring(0, 2).toInt(16)
            val green = normalized.substring(2, 4).toInt(16)
            val blue = normalized.substring(4, 6).toInt(16)
            "$red,$green,$blue"
        } catch (_: NumberFormatException) {
            DEFAULT_OVERLAY_RGB
        }
    }
}
