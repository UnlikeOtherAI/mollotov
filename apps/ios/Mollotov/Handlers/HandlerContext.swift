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

    /// Show a blue touch indicator at viewport coordinates with a ripple animation.
    func showTouchIndicator(x: Double, y: Double) async {
        let js = """
        (function() {
            var dot = document.createElement('div');
            dot.style.cssText = 'position:fixed;left:\(x)px;top:\(y)px;width:36px;height:36px;' +
                'margin-left:-18px;margin-top:-18px;border-radius:50%;' +
                'background:rgba(59,130,246,0.3);pointer-events:none;z-index:2147483647;' +
                'transition:transform 0.4s ease-out, opacity 0.4s ease-out;transform:scale(1);opacity:1;';
            document.body.appendChild(dot);
            var ripple = document.createElement('div');
            ripple.style.cssText = 'position:fixed;left:\(x)px;top:\(y)px;width:36px;height:36px;' +
                'margin-left:-18px;margin-top:-18px;border-radius:50%;' +
                'border:2px solid rgba(59,130,246,0.3);pointer-events:none;z-index:2147483647;' +
                'transition:transform 0.5s ease-out, opacity 0.5s ease-out;transform:scale(1);opacity:1;';
            document.body.appendChild(ripple);
            requestAnimationFrame(function() {
                ripple.style.transform = 'scale(3)';
                ripple.style.opacity = '0';
            });
            setTimeout(function() {
                dot.style.transform = 'scale(0.5)';
                dot.style.opacity = '0';
            }, 300);
            setTimeout(function() {
                dot.remove();
                ripple.remove();
            }, 600);
        })();
        """
        try? await evaluateJS(js)
    }

    /// Show touch indicator at an element's center by selector.
    func showTouchIndicatorForElement(_ selector: String) async {
        let js = """
        (function() {
            var el = document.querySelector('\(selector.replacingOccurrences(of: "'", with: "\\'"))');
            if (!el) return JSON.stringify(null);
            var r = el.getBoundingClientRect();
            return JSON.stringify({x: r.left + r.width/2, y: r.top + r.height/2});
        })()
        """
        if let result = try? await evaluateJSReturningString(js),
           let data = result.data(using: .utf8),
           let pos = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
           let x = pos["x"], let y = pos["y"] {
            await showTouchIndicator(x: x, y: y)
        }
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
