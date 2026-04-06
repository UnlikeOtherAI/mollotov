package com.kelpie.browser.ui

import android.graphics.Bitmap
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.kelpie.browser.browser.BrowserState
import com.kelpie.browser.browser.BrowserTab
import com.kelpie.browser.browser.JsBridge
import com.kelpie.browser.browser.NetworkTrafficStore
import com.kelpie.browser.browser.TabStore
import com.kelpie.browser.devtools.ConsoleHandler
import com.kelpie.browser.handlers.HandlerContext

/** Displays the active tab's WebView, handles WebView clients, and tracks scroll direction. */
@Composable
fun TabWebViewContent(
    tabStore: TabStore,
    browserState: BrowserState,
    handlerContext: HandlerContext,
    onScrollDirectionChange: (ScrollDirection) -> Unit,
    onWebViewReady: (WebView) -> Unit,
    modifier: Modifier = Modifier,
) {
    val tabs by tabStore.tabs.collectAsState()
    val activeTabId by tabStore.activeTabId.collectAsState()
    val installedWebViewRef = remember { mutableStateOf<WebView?>(null) }

    AndroidView(
        factory = { ctx -> FrameLayout(ctx) },
        update = { container ->
            val tab = tabs.firstOrNull { it.id == activeTabId } ?: return@AndroidView
            val wv = tab.webView

            if (wv === installedWebViewRef.value) return@AndroidView

            container.removeAllViews()
            (wv.parent as? ViewGroup)?.removeView(wv)

            installTabWebViewClients(wv, tab, browserState, handlerContext)

            container.addView(
                wv,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )

            wv.setOnScrollChangeListener { _, _, scrollY, _, oldScrollY ->
                val delta = scrollY - oldScrollY
                if (scrollY <= 0) {
                    onScrollDirectionChange(ScrollDirection.UP)
                } else if (delta > 12) {
                    onScrollDirectionChange(ScrollDirection.DOWN)
                } else if (delta < -12) {
                    onScrollDirectionChange(ScrollDirection.UP)
                }
            }

            syncBrowserStateFromWebView(wv, browserState)
            installedWebViewRef.value = wv
            onWebViewReady(wv)
        },
        modifier = modifier,
    )
}

private fun installTabWebViewClients(
    webView: WebView,
    tab: BrowserTab,
    browserState: BrowserState,
    handlerContext: HandlerContext,
) {
    webView.webViewClient =
        object : WebViewClient() {
            private var documentNavigationUrl: String? = null
            private var didCaptureDocumentForNavigation = false

            override fun onPageStarted(
                view: WebView,
                url: String,
                favicon: Bitmap?,
            ) {
                handlerContext.dialogState.dismissPending()
                tab.currentUrl = url
                browserState.updateUrl(url)
                browserState.updateLoading(true)
                handlerContext.mark3DInspectorInactive()
                documentNavigationUrl = url
                didCaptureDocumentForNavigation = false
            }

            override fun onPageFinished(
                view: WebView,
                url: String,
            ) {
                tab.currentUrl = url
                browserState.updateUrl(url)
                browserState.updateLoading(false)
                browserState.updateCanGoBack(view.canGoBack())
                browserState.updateCanGoForward(view.canGoForward())

                view.evaluateJavascript(ConsoleHandler.BRIDGE_SCRIPT, null)
                view.evaluateJavascript(JsBridge.NETWORK_BRIDGE_SCRIPT, null)

                if (!didCaptureDocumentForNavigation && documentNavigationUrl == url) {
                    didCaptureDocumentForNavigation = true
                    view.evaluateJavascript("(document.contentType || 'text/html')") { value ->
                        val contentType =
                            value
                                ?.trim()
                                ?.removePrefix("\"")
                                ?.removeSuffix("\"")
                                ?.takeIf { it.isNotEmpty() && it != "null" }
                                ?: "text/html"
                        NetworkTrafficStore.appendDocumentNavigation(
                            url = url,
                            statusCode = 0,
                            contentType = contentType,
                        )
                    }
                }
            }

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
            ): Boolean = false
        }

    webView.webChromeClient =
        object : WebChromeClient() {
            override fun onReceivedTitle(
                view: WebView,
                title: String?,
            ) {
                tab.pageTitle = title ?: ""
                browserState.updateTitle(title ?: "")
            }

            override fun onProgressChanged(
                view: WebView,
                newProgress: Int,
            ) {
                browserState.updateProgress(newProgress)
            }

            override fun onJsAlert(
                view: WebView,
                url: String?,
                message: String?,
                result: android.webkit.JsResult,
            ): Boolean {
                handlerContext.dialogState.enqueue(
                    com.kelpie.browser.browser.DialogState.PendingDialog(
                        type = "alert",
                        message = message.orEmpty(),
                        defaultText = null,
                        jsResult = result,
                        jsPromptResult = null,
                    ),
                )
                return true
            }

            override fun onJsConfirm(
                view: WebView,
                url: String?,
                message: String?,
                result: android.webkit.JsResult,
            ): Boolean {
                handlerContext.dialogState.enqueue(
                    com.kelpie.browser.browser.DialogState.PendingDialog(
                        type = "confirm",
                        message = message.orEmpty(),
                        defaultText = null,
                        jsResult = result,
                        jsPromptResult = null,
                    ),
                )
                return true
            }

            override fun onJsPrompt(
                view: WebView,
                url: String?,
                message: String?,
                defaultValue: String?,
                result: android.webkit.JsPromptResult,
            ): Boolean {
                handlerContext.dialogState.enqueue(
                    com.kelpie.browser.browser.DialogState.PendingDialog(
                        type = "prompt",
                        message = message.orEmpty(),
                        defaultText = defaultValue,
                        jsResult = null,
                        jsPromptResult = result,
                    ),
                )
                return true
            }
        }
}

private fun syncBrowserStateFromWebView(
    webView: WebView,
    browserState: BrowserState,
) {
    browserState.updateUrl(webView.url ?: "")
    browserState.updateTitle(webView.title ?: "")
    browserState.updateCanGoBack(webView.canGoBack())
    browserState.updateCanGoForward(webView.canGoForward())
    browserState.webView = webView
}
