# Core Parity Gap: macOS → C++ Native

**Date:** 2026-04-06
**Status:** Draft

This document catalogues everything in the macOS Swift app that should live in the core C++ project (`native/`), either because it is already implemented in `native/` and the macOS app isn't using it, or because it is platform-agnostic and belongs in `native/` even if it isn't there yet.

---

## 1. Already in `native/`, Not Yet Wired in macOS Swift

The `engine-chromium-desktop` C++ module has complete handler implementations for most automation methods. The macOS Swift handlers below implement the same methods but with inferior or incomplete JS — the C++ versions should be the source of truth and the macOS app should call into them via the C API.

### 1.1 Interaction — `engine-chromium-desktop/src/handlers/interaction_handler.cpp`

**C++ status:** Complete (click, tap, fill, type, select-option, check, uncheck)
**macOS status:** `apps/macos/Kelpie/Handlers/InteractionHandler.swift` — same methods, different JS

**Gap:** The C++ implementation has all 7 methods. The macOS Swift version has the same 7. The macOS app is not calling into the C++ core. This means the macOS app is maintaining duplicate logic.

**Action:** Wire `InteractionHandler.swift` to call `kelpie_interaction_*` C API functions instead of executing JS directly. The JS that implements the interaction logic (native setters for `fill`, keyboard events for `type`, etc.) lives in the C++ source and can be extracted to a shared string constant in `core-automation`.

### 1.2 Scroll — `engine-chromium-desktop/src/handlers/scroll_handler.cpp`

**C++ status:** `scroll`, `scroll-to-top`, `scroll-to-bottom` implemented. `scroll2` and `scroll-to-y` return `UNSUPPORTED`.
**macOS status:** `apps/macos/Kelpie/Handlers/ScrollHandler.swift` — `scroll`, `scroll2`, `scroll-to-top`, `scroll-to-bottom`, `scroll-to-y` all implemented with full JS

**Gap:** The macOS app has `scroll2` (scroll element into view with position) and `scroll-to-y` (absolute Y scroll) which are absent from C++. The C++ version has only basic scroll methods.

**Action:** Port `scroll2` and `scroll-to-y` JS from Swift to C++. Then wire macOS to the C++ implementation.

### 1.3 Evaluate — `engine-chromium-desktop/src/handlers/evaluate_handler.cpp`

**C++ status:** `evaluate` and `wait-for-element` implemented.
**macOS status:** `apps/macos/Kelpie/Handlers/EvaluateHandler.swift` — same methods.

**Action:** Wire macOS `EvaluateHandler.swift` to C++. The `wait-for-element` polling loop pattern is reusable.

### 1.4 DOM — `engine-chromium-desktop/src/handlers/dom_handler.cpp`

**C++ status:** `query-selector`, `query-selector-all`, `get-element-text`, `get-attributes`, `get-dom` all implemented.
**macOS status:** `apps/macos/Kelpie/Handlers/DOMHandler.swift` — same methods.

**Action:** macOS Swift should call into C++ for DOM operations. The JS (querying `getBoundingClientRect`, `innerText`, attributes, etc.) is already in C++ and should not be duplicated in Swift.

### 1.5 Network (Performance API) — `engine-chromium-desktop/src/handlers/network_handler.cpp`

**C++ status:** `get-network-log` and `get-resource-timeline` implemented. Uses `performance.getEntriesByType('resource')` and `performance.getEntriesByType('navigation')`.
**macOS status:** `apps/macos/Kelpie/Handlers/NetworkHandler.swift` — same methods. The JS for `buildSummary()` is in Swift.

**Gap:** `buildSummary()` Swift logic (categorizing by content-type, filtering by method/status/url) is not in C++.

**Action:** Move `buildSummary()` logic to `core-automation`. macOS calls C++ for all network log operations.

### 1.6 Navigation — `engine-chromium-desktop/src/handlers/navigation_handler.cpp`

**C++ status:** `navigate`, `back`, `forward`, `reload`, `get-current-url`, `set-home`, `get-home` all implemented. Cookie migration on navigate is in C++.
**macOS status:** `apps/macos/Kelpie/Handlers/NavigationHandler.swift` — same methods plus `context.persistRendererCookiesToSharedJar()`.

**Gap:** Cookie migration (`persistRendererCookiesToSharedJar`) is in Swift. Should be in `core-automation`.

**Action:** Move cookie migration logic to `core-automation`. Wire macOS navigation to C++.

### 1.7 Console — `engine-chromium-desktop/src/handlers/console_handler.cpp`

**C++ status:** `get-console-messages`, `get-js-errors`, `clear-console` implemented. Uses the injected bridge script.
**macOS status:** `apps/macos/Kelpie/Handlers/ConsoleHandler.swift` — same methods. Bridge script (`bridgeScript`) is a static Swift string.

**Gap:** The console bridge JS intercepts `console.*` and `window.onerror`. The JS itself is portable. The injection mechanism (via `WKUserScript` or CDP `Page.addScriptToEvaluateOnNewDocument`) is platform-specific. The JS string constant should be in `core-automation`.

**Action:** Extract `bridgeScript` JS string to `core-automation/include/kelpie/bridge_scripts.h`. Platform code injects via its own mechanism.

### 1.8 Screenshot — `engine-chromium-desktop/src/handlers/screenshot_handler.cpp`

**C++ status:** `screenshot` implemented (PNG/JPEG via CDP `Page.captureScreenshot`).
**macOS status:** `apps/macos/Kelpie/Handlers/ScreenshotHandler.swift` — same method using `context.takeSnapshot()` and `NSBitmapImageRep`.

**Action:** Keep platform-specific capture (CEF uses CDP, WebKit uses `takeSnapshot()`). The response format (width/height/format/base64) is already consistent.

---

## 2. Not in `native/`, Should Be Added

These are macOS Swift components that are platform-agnostic and should be implemented in `native/`.

### 2.1 MutationHandler — `apps/macos/Kelpie/Handlers/MutationHandler.swift`

**What it does:** Injects a `MutationObserver` bridge script that buffers DOM mutations (childList, attributes, characterData) in `window.__kelpieMutations`. Provides `watch-mutations`, `get-mutations`, `stop-watching`.

**Why it belongs in core:** Uses the standard `MutationObserver` Web API — identical on all browser engines. The in-page JS (buffering, serialization, `observe()` configuration) is 100% portable. Only the injection mechanism differs (WKUserScript vs CDP `Page.addScriptToEvaluateOnNewDocument`).

**What to move:** The JS string constant (lines 24–67 of `MutationHandler.swift`) to `core-automation/include/kelpie/bridge_scripts.h`. The handler state management (`window.__kelpieMutations` watch tracking) stays in Swift or moves to `core-automation` as a C++ class.

### 2.2 ShadowDOMHandler — `apps/macos/Kelpie/Handlers/ShadowDOMHandler.swift`

**What it does:** Queries shadow DOM using `shadowRoot.querySelector()` recursively. Provides `query-shadow-dom`, `get-shadow-roots`.

**Why it belongs in core:** Pure JS evaluation using standard `shadowRoot` API. Identical on all engines.

**Action:** Implement in `core-automation`. JS is reusable as-is.

### 2.3 Snapshot3DBridge — `apps/macos/Kelpie/Handlers/Snapshot3DBridge.swift`

**What it does:** Full-page 3D CSS transform for element inspection. ~700 lines of JS that:
1. Reads all DOM elements, computes depth via ancestor traversal
2. Applies `translateZ(n * 30px)` per element with `transformStyle: preserve-3d`
3. Creates an overlay for mouse/touch/wheel input
4. Handles hover highlighting, info panel, mode switching (rotate/scroll), pinch-zoom

**Why it belongs in core:** Pure JS/CSS. Zero platform-specific calls except `exitViaMessage()` which has a fallback chain:
```javascript
window.webkit.messageHandlers.kelpie3DSnapshot.postMessage(...)  // WebKit
window.KelpieBridge.on3DSnapshotEvent(...)                       // generic fallback
console.log('__kelpie_3d_exit__')                                // last-resort fallback
```

**What to move:** The entire JS (lines 4–800 of `Snapshot3DBridge.swift`) to `core-automation/include/kelpie/bridge_scripts.h`. Platform code provides the bridge function via its own mechanism. The JS itself is reusable on iOS/Android/WebKit/Chromium.

**Note:** `Snapshot3DBridge.swift` also contains `Snapshot3DHandler.swift` (the handler that calls the bridge). The handler has a feature flag check (`FeatureFlags.is3DInspectorEnabled`) and state (`context.isIn3DInspector`).

### 2.4 NetworkBridge — Injected JS in `apps/macos/Kelpie/Handlers/NetworkBridge.swift`

**What it does:** Intercepts `XMLHttpRequest.prototype.open/send/setRequestHeader` and `window.fetch` to capture network requests and post them via `window.webkit.messageHandlers.kelpieNetwork.postMessage`.

**Why it belongs in core:** The XHR/fetch interception JS is portable. Only the `postMessage` call differs.

**What to move:** The XHR/fetch interception JS to `core-automation`. The bridge call (`postMessage`) should use the generic fallback chain like Snapshot3DBridge.

### 2.5 ViewportState — `apps/macos/Kelpie/Browser/ViewportState.swift`

**What it does:** Manages viewport dimensions, orientation, and viewport presets. `allMacViewportPresets` is macOS-specific (iPhone SE, iPad Mini, etc.). `ViewportState` itself has platform-agnostic fields: `width`, `height`, `devicePixelRatio`, `orientation`, `mode`.

**Why it belongs in core:** Viewport management is a core automation concern. The preset list differs by platform but the `ViewportState` struct and orientation logic belong in `core-automation`.

**What to move:** `ViewportState` struct and orientation enum to `core-automation/include/kelpie/viewport_state.h`. Platform-specific preset lists stay in platform code.

### 2.6 FeatureFlags — `apps/macos/Kelpie/Browser/FeatureFlags.swift`

**What it does:** Static boolean dictionary for feature toggles. Currently: `is3DInspectorEnabled`.

**Why it belongs in core:** Feature flags are a core concept. The storage/retrieval mechanism is platform-specific but the concept and flag names belong in core.

**What to move:** Flag name constants (`KELPIE_FF_3D_INSPECTOR`) and the `FeatureFlags` struct to `core-protocol/include/kelpie/feature_flags.h`.

### 2.7 FaviconExtractor — `apps/macos/Kelpie/Browser/FaviconExtractor.swift`

**What it does:** Extracts favicons from web pages by:
1. Parsing `<link rel="icon">` tags
2. Fetching `/favicon.ico`
3. Generating letter avatars as fallback

**Why it belongs in core:** Favicon extraction logic is platform-agnostic. The implementation (parsing link tags, building ICO URLs) is the same on all platforms.

**What to move:** The extraction logic (parsing HTML for link tags, URL building) to `core-automation`. The actual HTTP fetch uses platform stack (URLSession/WKWebView). Letter avatar generation (using platform graphics) stays in platform code.

**Note:** SVG favicon decoding via temp file (`ad6d5d6` — "decode SVG favicons via temp file") is macOS-specific and should remain in platform code.

### 2.8 TabStore — `apps/macos/Kelpie/Browser/TabStore.swift`

**What it does:** Multi-tab management. Per-tab `WKWebViewRenderer` instances with title/URL/isLoading/favicon tracking. Tab switching, adding, closing with tab spread animation coordination.

**Why it belongs in core:** Tab management is a core browser concept. The data model (`Tab`: id, title, url, isLoading, favicon) is identical across platforms.

**What to move:**
- `Tab` data model (without renderer reference) to `core-protocol/include/kelpie/types.h`
- `TabStore` logic (add/close/switch) to `core-automation`
- Platform code (macOS/iOS/Android) provides the platform-specific renderer per tab

**Note:** `WKWebViewRenderer` is WebKit-specific. `TabStore` should hold an opaque `RendererInterface*` (already defined in C++ as `kelpie::RendererInterface`). The Swift `Tab` holds a `WKWebViewRenderer` directly — this needs a Swift-level abstraction that wraps the C++ renderer interface.

### 2.9 BrowserState — `apps/macos/Kelpie/Browser/BrowserState.swift`

**What it does:** Aggregates `tabStore`, `viewportState`, `featureFlags`, and bridge scripts (`consoleBridgeScript`, `networkBridgeScript`). Tracks `isIn3DInspector`, `consoleMessages`, `lastError`.

**Why it belongs in core:** `BrowserState` is the top-level automation state. It should be in `core-automation`. Platform code provides the renderer and network layer.

**What to move:** `BrowserState` struct and the bridge script references to `core-automation`. Platform code owns the actual injection mechanism.

### 2.10 SharedCookieJar — `apps/macos/Kelpie/Browser/SharedCookieJar.swift`

**What it does:** Migrates cookies between WebKit (`WKHTTPCookieStore`) and CEF (`CefCookieManager`). Reads/writes cookies from a persistent JSON file (`~/Library/Cookies/kelpie_shared_cookies.json`).

**Why it belongs in core:** Cookie migration between renderers is a core concern. The JSON persistence format and cookie reading/writing logic is portable.

**What to move:** The cookie migration logic (read from one store, write to another) to `core-automation`. Platform-specific cookie APIs (WKHTTPCookieStore vs CefCookieManager) stay in platform code and implement a `CookieStore` interface defined in core.

### 2.11 AIHandler — `apps/macos/Kelpie/Handlers/AIHandler.swift`

**What it does:** `ai-status`, `ai-load`, `ai-unload`, `ai-infer`, `ai-record`. Uses `InferenceEngine` (CoreML/MLX) and `AudioRecorder` (AVFoundation) for native inference. Uses Ollama HTTP for remote inference.

**What belongs in core:**
- Ollama HTTP client protocol (`postJSON`, `ollamaURL`, `isOllamaReachable`) — already in `native/core-ai/src/ollama_client.cpp` but the handler-level orchestration is in Swift
- `InferenceHarness` and `InferenceEngine.InferenceResult` types — portable

**What stays platform-specific:**
- `InferenceEngine` (CoreML/MLX on macOS, Apple Foundation Models on iOS)
- `AudioRecorder` (AVFoundation microphone access)
- `NSBitmapImageRep` screenshot encoding for vision context

**Action:** The `ai-infer` Ollama code path (detached from native inference) should use `core-ai`. The `ai-status` response format should be defined in `core-protocol`.

---

## 3. Platform-Specific — Do Not Move to Core

These files use AppKit, WKWebView, or other macOS-only APIs and belong in the macOS app:

| File | Reason |
|------|--------|
| `AI/AIManager.swift` | AppKit UI integration |
| `AI/AudioRecorder.swift` | AVFoundation microphone |
| `AI/InferenceEngine.swift` | CoreML/MLX |
| `AI/InferenceHarness.swift` | CoreML/MLX harness |
| `AI/PageSummary.swift` | AI logic, partially portable |
| `AI/SystemPrompt.swift` | Portable text, can extract |
| `Device/DeviceInfo.swift` | NSScreen, platform info |
| `Network/HTTPServer.swift` | `NWListener` (macOS Network.framework) |
| `Network/MDNSAdvertiser.swift` | `NWListener` bonjour service |
| `Network/Router.swift` | Swift router, but C++ has `desktop_router.cpp` |
| `Network/ServerState.swift` | macOS HTTP server state |
| `Renderer/WKWebViewRenderer.swift` | WKWebView-specific |
| `Renderer/CEFRenderer.swift` | CEF-specific |
| `Renderer/RendererEngine.swift` | Dual-engine macOS logic |
| `Renderer/RendererState.swift` | Renderer selection state |
| `Renderer/CookieMigrator.swift` | WKHTTPCookieStore + CEF |
| `Handlers/AIHandler.swift` | Mixed: Ollama portable, native inference not |
| `Handlers/RendererHandler.swift` | macOS dual-renderer switching |
| `Handlers/DeviceHandler.swift` | NSScreen viewport info |
| `Handlers/BrowserManagementHandler.swift` | macOS-specific clipboard, viewport, tabs |
| `SafariAuthHelper.swift` | Safari auth API |
| `LLM/LLMHandler.swift` | LLM-specific |
| All `Views/*.swift` | SwiftUI/AppKit UI |
| `KelpieApp.swift` | App lifecycle |

---

## 4. Implementation Priority

### Phase 1 — Bridge Scripts to Core (High Value, Low Risk)
Extract all injected JS strings to `core-automation/include/kelpie/bridge_scripts.h`:
1. `Snapshot3DBridge` (~700 lines JS)
2. `MutationHandler` JS (MutationObserver injection)
3. `NetworkBridge` JS (XHR/fetch intercept)
4. `ConsoleHandler` bridge script

These are pure string constants. Moving them to core costs nothing and makes them available to all platforms immediately.

### Phase 2 — Store Parity (Medium Value)
1. `ViewportState` struct → `core-automation`
2. `FeatureFlags` constants → `core-protocol`
3. `FaviconExtractor` logic → `core-automation`
4. `SharedCookieJar` migration logic → `core-automation` with platform `CookieStore` interface
5. `BrowserState` → `core-automation`

### Phase 3 — Handler Wire-Through (Medium Value, Larger Change)
For each handler that exists in both Swift and C++: replace Swift JS execution with C API calls. This makes the macOS app a consumer of the core rather than a parallel implementation.

Priority order:
1. `EvaluateHandler` (simple)
2. `DOMHandler` (simple)
3. `ScrollHandler` (needs `scroll2` + `scroll-to-y` ported to C++ first)
4. `InteractionHandler` (large, 7 methods)
5. `NavigationHandler` (cookie migration needs to move to core first)
6. `NetworkHandler` (`buildSummary()` logic needs to move to core first)
7. `ConsoleHandler` (JS is in core, handler logic wires to JS in core)

### Phase 4 — TabStore to Core (High Value, Significant Refactor)
Move `Tab` data model and `TabStore` logic to `core-automation`. Requires defining a `TabInterface` that platforms implement (returns opaque `RendererInterface*`). macOS `Tab` wraps C++ tab + Swift `WKWebViewRenderer`. iOS and Android implement their own tab wrappers.

### Phase 5 — AI Orchestration (Lower Priority)
Define `ai-*` response schemas in `core-protocol`. Move Ollama HTTP protocol handling to `core-ai`. Keep native inference in platform code.

---

## 5. Cross-Platform Consistency Requirements

Per AGENTS.md § Platform Parity, every feature on one platform must be on all platforms. Before any item in this document is implemented on macOS, the equivalent must be planned for iOS and Android. This applies to:

- All bridge scripts moved to core (must work identically on iOS WebKit, Android WebView, macOS WebKit, CEF)
- TabStore model moved to core (iOS and Android must use the same tab data model)
- Feature flags defined in core (must be set on all platforms, not just macOS)
- Favicon extraction logic in core (iOS and Android must implement the same algorithm)

When implementing any Phase 1–4 item, update `docs/functionality.md` and the relevant API docs in `docs/api/` to reflect the new cross-platform behavior.
