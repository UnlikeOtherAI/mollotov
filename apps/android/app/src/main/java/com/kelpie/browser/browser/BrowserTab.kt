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
    var isLoading: Boolean = false

    private var lastHistoryUrl: String = ""
    private var lastHistoryTitle: String = ""
    private var lastObservedHistoryClearGeneration: Int = HistoryStore.clearGeneration

    fun recordHistoryIfNeeded(url: String) {
        syncHistoryTrackingIfNeeded()
        val trimmedUrl = url.trim()
        if (trimmedUrl.isEmpty() || trimmedUrl == lastHistoryUrl) {
            return
        }

        lastHistoryUrl = trimmedUrl
        lastHistoryTitle = pageTitle.trim()
        HistoryStore.record(trimmedUrl, pageTitle)
    }

    fun updateHistoryTitleIfNeeded(title: String) {
        syncHistoryTrackingIfNeeded()
        val trimmedUrl = currentUrl.trim()
        val trimmedTitle = title.trim()
        if (trimmedUrl.isEmpty() || trimmedTitle.isEmpty()) {
            return
        }
        if (trimmedUrl != lastHistoryUrl || trimmedTitle == lastHistoryTitle) {
            return
        }

        lastHistoryTitle = trimmedTitle
        HistoryStore.updateLatestTitle(trimmedUrl, trimmedTitle)
    }

    private fun syncHistoryTrackingIfNeeded() {
        val currentGeneration = HistoryStore.clearGeneration
        if (currentGeneration == lastObservedHistoryClearGeneration) {
            return
        }
        lastObservedHistoryClearGeneration = currentGeneration
        lastHistoryUrl = ""
        lastHistoryTitle = ""
    }
}
