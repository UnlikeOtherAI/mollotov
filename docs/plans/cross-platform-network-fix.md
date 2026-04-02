# Cross-Platform Network Inspector and Library Sheet Fixes

## Problem

Three defects share the same root causes:
1. Network inspectors miss the top-level document request because only JS bridge traffic is logged.
2. Network inspector filter UI is too dense and cramped, especially on macOS, which makes the list feel broken.
3. macOS history and bookmarks sheets still rely on weak SwiftUI row hit targets.

## Root Cause

- macOS, iOS, and Android all append network entries from injected JS bridges that only observe `fetch` and `XMLHttpRequest`.
- The browser shell navigation itself is handled natively by `WKWebView` / `android.webkit.WebView`, so the page document request never enters `NetworkTrafficStore`.
- The current inspector UIs expose both method and category chips as top-level filters. That overuses horizontal space and makes the left pane harder to scan.
- macOS history and bookmark rows are plain SwiftUI list rows with `Button` + `.plain`, which has already been a weak pattern elsewhere in this app.

## Proposed Fix

### 1. Capture the top-level document request in native web view delegates

Add a single native network entry for the main-frame document navigation on each platform:
- macOS WebKit: use `WKNavigationDelegate` response/navigation callbacks in `WKWebViewRenderer`
- macOS Chromium: append a document row when the CEF renderer completes a top-level navigation, even if only partial metadata is available
- iOS: use `WKNavigationDelegate` response/navigation callbacks in `WebViewCoordinator`
- Android: use `WebViewClient` callbacks in `WebViewContainer`

Each document entry should:
- use method `GET`
- use the committed page URL
- include the best available status code, MIME type/content type, and expected size
- use response headers when available
- avoid duplicate inserts for the same navigation event

Apple WebKit paths can include real response metadata. Android and macOS Chromium may only provide partial metadata for top-level document rows, and that is acceptable; the invariant is that the page navigation itself appears in the inspector.

This keeps the existing JS bridge for subresource/XHR/fetch traffic and fixes the missing page request without introducing a proxy layer.

### 2. Simplify the network inspector filter model on every platform

Replace the chip-heavy method+category filter bar with a single top-level method filter in the app UI:
- `All calls`
- `GET`
- `POST`
- `PUT`
- `DELETE`

Category remains visible only as row metadata and in the detail screen. API and handler filtering semantics remain unchanged.

Platform-specific presentation:
- macOS: menu-style dropdown above the left request list
- iOS: compact menu picker at the top of the list
- Android: exposed dropdown menu at the top of the sheet

### 3. Make macOS list interactions use explicit full-row hit targets

For bookmarks, history, and network rows on macOS:
- give rows a full-width content shape
- keep row activation native and full-width rather than relying on tiny text labels
- keep toolbar actions and close controls as real controls

This avoids repeating the earlier floating-menu/button problem in these sheets.

## Non-Goals

- No HTTP proxy or CDP-based network capture rewrite
- No protocol/API changes
- No attempt to recover historical entries already stored without titles

## Risks

- `WKWebView` navigation callbacks do not expose full response headers in every callback, so Apple document entries may have partial header metadata.
- Android `WebView` and macOS Chromium provide less response metadata than WebKit; top-level document rows may legitimately show `0` or blank fields instead of guessed values.
- Some pages redirect. Duplicate suppression should key off the final committed URL plus navigation lifecycle, not just the raw string.

## Cross-Provider Review

Codex adversarial review findings:
- High: macOS scope had to include both renderers, not just `WKWebViewRenderer`, because users can switch between WebKit and Chromium at runtime.
- High: Android metadata must allow partial values instead of inventing `200` or synthetic headers for top-level document rows.
- Medium: the filter simplification is UI-only; `network-list` API/filter semantics stay unchanged.
- Medium: the macOS interaction fix should prefer native full-row activation over more custom button chrome.
