package com.kelpie.browser.browser

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.kelpie.browser.handlers.ConsoleHandler
import com.kelpie.browser.handlers.WebSocketHandler

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewContainer(
    browserState: BrowserState,
    dialogState: DialogState,
    handlerContext: com.kelpie.browser.handlers.HandlerContext? = null,
    modifier: Modifier = Modifier,
    onWebViewCreated: (WebView) -> Unit = {},
) {
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.loadWithOverviewMode = true
                settings.useWideViewPort = true
                settings.setSupportMultipleWindows(false)
                settings.mediaPlaybackRequiresUserGesture = false
                settings.userAgentString = "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Version/131.0.0.0 Mobile Safari/537.36"

                // Add JS bridge for console + network capture
                addJavascriptInterface(JsBridge(handlerContext), "KelpieBridge")
                WebSocketHandler.installBridge(this)

                webViewClient =
                    object : WebViewClient() {
                        private var documentNavigationUrl: String? = null
                        private var didCaptureDocumentForNavigation = false

                        override fun onPageStarted(
                            view: WebView,
                            url: String,
                            favicon: Bitmap?,
                        ) {
                            dialogState.dismissPending()
                            browserState.updateUrl(url)
                            browserState.updateLoading(true)
                            handlerContext?.mark3DInspectorInactive()
                            documentNavigationUrl = url
                            didCaptureDocumentForNavigation = false
                        }

                        override fun onPageFinished(
                            view: WebView,
                            url: String,
                        ) {
                            browserState.updateUrl(url)
                            browserState.updateLoading(false)
                            browserState.updateCanGoBack(view.canGoBack())
                            browserState.updateCanGoForward(view.canGoForward())

                            // Inject bridge scripts after page load
                            view.evaluateJavascript(ConsoleHandler.BRIDGE_SCRIPT, null)
                            view.evaluateJavascript(JsBridge.NETWORK_BRIDGE_SCRIPT, null)
                            if (!WebSocketHandler.isDocumentStartSupported) {
                                view.evaluateJavascript(WebSocketHandler.BRIDGE_SCRIPT, null)
                            }

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

                webChromeClient =
                    object : WebChromeClient() {
                        override fun onReceivedTitle(
                            view: WebView,
                            title: String?,
                        ) {
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
                            dialogState.enqueue(
                                DialogState.PendingDialog(
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
                            dialogState.enqueue(
                                DialogState.PendingDialog(
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
                            dialogState.enqueue(
                                DialogState.PendingDialog(
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

                browserState.webView = this
                onWebViewCreated(this)

                loadUrl(browserState.currentUrl.value)
            }
        },
        modifier = modifier,
    )
}
