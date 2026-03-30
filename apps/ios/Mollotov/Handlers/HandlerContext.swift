import WebKit

/// Shared context providing access to the WebView for all handlers.
@MainActor
final class HandlerContext: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    var consoleMessages: [[String: Any]] = []

    nonisolated override init() { super.init() }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mollotovConsole",
              let body = message.body as? [String: Any] else { return }
        consoleMessages.append(body)
        if consoleMessages.count > 5000 { consoleMessages.removeFirst() }
    }

    func evaluateJS(_ script: String) async throws -> Any? {
        guard let webView else { throw HandlerError.noWebView }
        return try await webView.evaluateJavaScript(script)
    }

    func evaluateJSReturningString(_ script: String) async throws -> String {
        let result = try await evaluateJS(script)
        return result as? String ?? String(describing: result ?? "null")
    }

    func evaluateJSReturningJSON(_ script: String) async throws -> [String: Any] {
        let wrapped = "JSON.stringify((\(script)))"
        let jsonString = try await evaluateJSReturningString(wrapped)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}

enum HandlerError: Error {
    case noWebView
    case elementNotFound(String)
    case timeout
    case platformNotSupported(String)
}

func errorResponse(code: String, message: String) -> [String: Any] {
    ["success": false, "error": ["code": code, "message": message]]
}

func successResponse(_ data: [String: Any] = [:]) -> [String: Any] {
    var result: [String: Any] = ["success": true]
    for (key, value) in data { result[key] = value }
    return result
}
