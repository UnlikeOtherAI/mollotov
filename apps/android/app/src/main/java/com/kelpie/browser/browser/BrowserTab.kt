package com.kelpie.browser.browser

import android.webkit.WebView
import java.util.UUID

/** A single browser tab. Owns a WebView and tracks its page state. */
class BrowserTab(
    val id: String = UUID.randomUUID().toString(),
    val webView: WebView,
    var isStartPage: Boolean = true,
) {
    var currentUrl: String = ""
    var pageTitle: String = ""
}
