# Mollotov — System Architecture

## Overview

Mollotov is a two-component system: native browser apps on mobile devices and a CLI orchestrator on the developer's machine. All components communicate over the local network via HTTP/JSON. Discovery is automatic via mDNS.

```
                        ┌─────────────┐
                        │     LLM     │
                        │  (Claude,   │
                        │   GPT, etc) │
                        └──────┬──────┘
                               │ MCP / CLI
                        ┌──────┴──────┐
                        │  Mollotov   │
                        │    CLI      │
                        │             │
                        │ ┌─────────┐ │
                        │ │ mDNS    │ │  Discovers devices
                        │ │ Scanner │ │  automatically
                        │ └─────────┘ │
                        │ ┌─────────┐ │
                        │ │ Command │ │  Routes to individual
                        │ │ Router  │ │  or group targets
                        │ └─────────┘ │
                        │ ┌─────────┐ │
                        │ │ MCP     │ │  Exposes CLI as
                        │ │ Server  │ │  MCP tool provider
                        │ └─────────┘ │
                        └──────┬──────┘
                               │ HTTP/JSON
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────┴───────┐ ┌─────┴────────┐ ┌─────┴────────┐
     │  iPhone         │ │  iPad         │ │  Pixel        │
     │                 │ │               │ │               │
     │ ┌─────────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │
     │ │  WKWebView  │ │ │ │ WKWebView │ │ │ │  WebView  │ │
     │ └─────────────┘ │ │ └───────────┘ │ │ └───────────┘ │
     │ ┌─────────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │
     │ │ HTTP Server │ │ │ │HTTP Server│ │ │ │HTTP Server│ │
     │ └─────────────┘ │ │ └───────────┘ │ │ └───────────┘ │
     │ ┌─────────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │
     │ │ MCP Server  │ │ │ │MCP Server │ │ │ │MCP Server │ │
     │ └─────────────┘ │ │ └───────────┘ │ │ └───────────┘ │
     │ ┌─────────────┐ │ │ ┌───────────┐ │ │ ┌───────────┐ │
     │ │ mDNS Advert │ │ │ │mDNS Advert│ │ │ │mDNS Advert│ │
     │ └─────────────┘ │ │ └───────────┘ │ │ └───────────┘ │
     └─────────────────┘ └───────────────┘ └───────────────┘
```

For full tech stack details, see [tech-stack.md](tech-stack.md).

---

## Component Architecture

### 1. Browser App (iOS / Android)

Each browser app has four internal layers:

```
┌──────────────────────────────────┐
│           UI Layer               │
│  URL bar │ WebView │ Settings    │
├──────────────────────────────────┤
│        Browser Engine            │
│  WKWebView (iOS) / WebView (And)│
├──────────────────────────────────┤
│        Command Handler           │
│  Receives HTTP → executes on     │
│  WebView via native APIs         │
├──────────────────────────────────┤
│        Network Layer             │
│  HTTP Server │ MCP │ mDNS        │
└──────────────────────────────────┘
```

**UI Layer** — Minimal chrome. URL bar on the left, settings icon on the right. Settings panel slides in from the right showing IP address, port, device name, mDNS status, and connection instructions. For details, see [ui/mobile.md](ui/mobile.md).

**Browser Engine** — Platform WebView. All page interaction goes through native APIs:
- iOS: `WKWebView` native methods — `evaluateJavaScript`, `takeSnapshot`, scroll via `scrollView`
- Android: `WebView` + CDP — `DOM.getDocument`, `Page.captureScreenshot`, `Runtime.evaluate`

**Command Handler** — Translates incoming HTTP requests into native WebView calls. Each command maps to a specific native API invocation. No scripts are injected into the page's execution context.

**Network Layer** — Embedded HTTP server (Swifter/Telegraph on iOS, Ktor on Android), MCP server over the same transport, and mDNS service advertisement.

### 2. CLI

```
┌──────────────────────────────────┐
│         CLI Interface            │
│  Commander.js commands + help    │
├──────────────────────────────────┤
│        Command Router            │
│  Individual │ Group │ Smart      │
├──────────────────────────────────┤
│       Device Manager             │
│  Registry │ Health │ Resolution  │
├──────────────────────────────────┤
│        Network Layer             │
│  mDNS Discovery │ HTTP Client    │
├──────────────────────────────────┤
│         MCP Server               │
│  Exposes all CLI commands as     │
│  MCP tools for direct LLM use   │
└──────────────────────────────────┘
```

**CLI Interface** — Commander.js with structured help. Every command includes LLM-readable descriptions with input/output schemas, usage examples, and behavioral notes.

**Command Router** — Three modes:
- **Individual**: Send command to one device by name or IP
- **Group**: Send same command to all (or filtered subset of) devices, collect results
- **Smart**: Commands that query all devices and return filtered results (e.g., `findButton` returns only devices where the element was found)

**Device Manager** — Maintains a live registry of discovered devices. Tracks each device's name, IP, port, platform, resolution, and health status. Provides resolution metadata for resolution-aware commands.

**Network Layer** — mDNS scanner continuously discovers `_mollotov._tcp` services. HTTP client sends commands to individual browser HTTP servers.

**MCP Server** — Wraps all CLI commands as MCP tools. An LLM connected via MCP can discover devices, send commands, and receive results without going through the CLI interface.

---

## Data Flow

### Single Device Command

```
LLM → CLI (mollotov click --device iphone "#submit")
  → Device Manager (resolve "iphone" → 192.168.1.42:8420)
  → HTTP POST 192.168.1.42:8420/v1/click {selector: "#submit"}
  → Browser Command Handler
  → WKWebView.evaluateJavaScript("document.querySelector('#submit')")
  → Native tap at element coordinates
  → HTTP 200 {success: true, element: {tag: "button", text: "Submit"}}
  → CLI formats and returns result
```

### Group Command

```
LLM → CLI (mollotov group navigate "https://example.com")
  → Device Manager (all devices: [iphone, ipad, pixel])
  → Parallel HTTP POST to each /v1/navigate
  → Each browser navigates independently
  → Collect all responses
  → CLI returns aggregated result:
    {devices: [{name: "iphone", status: "ok"}, ...]}
```

### Smart Query

```
LLM → CLI (mollotov group find-button "Submit")
  → Device Manager (all devices)
  → Parallel HTTP POST to each /v1/find-element {text: "Submit", role: "button"}
  → Collect results, filter to found-only
  → CLI returns:
    {found: [{name: "iphone", element: {...}}, {name: "pixel", element: {...}}],
     notFound: [{name: "ipad"}]}
  → LLM decides what to do with the subset
```

### Resolution-Aware Command (scroll2)

```
LLM → CLI (mollotov scroll2 --device iphone "#footer")
  → Device Manager (resolve "iphone" → 192.168.1.42:8420)
  → HTTP POST 192.168.1.42:8420/v1/scroll2 {selector: "#footer", position: "center"}
  → Browser calculates element position relative to its own viewport
  → Browser scrolls iteratively until element is visible (up to maxScrolls)
  → HTTP 200 {success: true, scrollsPerformed: 3, element: {visible: true}}
  → CLI returns result
```

---

## Communication Protocol

### HTTP API

All browser-CLI communication uses REST over HTTP/JSON.

- Base URL: `http://{device-ip}:{port}/v1/`
- Content-Type: `application/json`
- Auth: None (local network only — devices must be on same network)
- Port: `8420` (default, configurable in settings)

### mDNS Service

```
Service Type: _mollotov._tcp
Port: 8420

TXT Records:
  id       = "a1b2c3d4-..."        # Stable unique device ID (UUID)
  name     = "My iPhone"           # User-friendly device name
  model    = "iPhone 15 Pro"       # Device model
  platform = "ios" | "android"     # Platform identifier
  width    = "390"                  # CSS viewport width
  height   = "844"                  # CSS viewport height
  port     = "8420"                 # HTTP server port
  version  = "1.0.0"               # App version
```

### Device Identity

Every Mollotov browser instance has a **stable unique device ID** used for reliable targeting across sessions:

- **iOS**: Uses `identifierForVendor` (UUID that persists across app launches, resets only on full app reinstall). Stored in Keychain for extra persistence.
- **Android**: Uses a self-generated UUIDv4, stored in SharedPreferences on first launch. Persists across app restarts. Falls back to `Settings.Secure.ANDROID_ID` as a secondary identifier.
- **Simulators/Emulators**: Generate a UUIDv4 on first launch, stored locally. Each simulator instance gets its own unique ID.

The device ID is:
- Included in mDNS TXT records as `id` field
- Returned by `getDeviceInfo` in the `device.id` field
- Accepted by CLI `--device` flag (in addition to name and IP)
- Stable across network changes, app restarts, and reboots
- Never changes unless the app is completely reinstalled

**CLI device targeting priority**: `--device` accepts device ID (exact match), device name (fuzzy match), or IP address. Device ID is the most reliable — names can collide, IPs can change.

### MCP Transport

Both browser and CLI MCP servers use **Streamable HTTP** (SSE) transport:

- Browser MCP: `http://{device-ip}:{port}/mcp`
- CLI MCP: `stdio` (standard MCP CLI transport) or `http://localhost:8421/mcp`

---

## Security Model

Mollotov operates exclusively on the local network. No cloud services, no remote access, no authentication tokens.

| Boundary | Control |
|---|---|
| Network isolation | Devices must be on the same local network |
| No internet exposure | HTTP servers bind to local/private IPs only |
| No persistent scripts | No browser extensions or content scripts. Some iOS features use ephemeral bridge scripts (cleared on navigation) |
| No data collection | No telemetry, no analytics, no phone-home |
| Port access | Default 8420, configurable per device |

---

## Platform-Specific Architecture Details

### iOS — No-Injection DOM Access

WKWebView's `evaluateJavaScript` executes in the page's JS context via the native bridge. It is not a persistent content script — it runs on demand and doesn't survive navigation. The page can theoretically detect these calls (e.g., by overriding DOM prototype methods), but this is true of all browser automation tools including Playwright.

**iOS bridge scripts (honest accounting):** Features that WKWebView doesn't expose natively require ephemeral bridge scripts injected via `evaluateJavaScript` or `WKUserScript`:
- Console capture: overrides `console.log/warn/error` to forward messages to native
- Mutation observation: injects a `MutationObserver`
- Accessibility tree: queries ARIA attributes via DOM traversal
- Page text extraction: runs a Readability-style algorithm
- Network logging: limited — WKWebView has no network interception API; only top-level navigation events via `WKNavigationDelegate`. XHR/fetch tracking requires an injected `XMLHttpRequest`/`fetch` wrapper.

These scripts are lightweight, non-persistent, and do not modify page content or behavior. They are cleared on navigation.

### Simulator & Emulator Support

Both platforms work identically on simulators/emulators and real devices:

**iOS Simulator**
- Each Simulator instance runs its own app process
- Bonjour/mDNS works natively — the Simulator shares the host's network stack
- No port forwarding needed — the HTTP server is directly reachable from the host
- Multiple Simulators with different screen sizes can run simultaneously (iPhone SE, iPhone 15, iPad, etc.)
- `getDeviceInfo` returns `isSimulator: true`

**Android Emulator**
- Each emulator instance runs its own app process
- Emulators run behind NAT — use `adb forward tcp:{hostPort} tcp:8420` to expose each instance
- The CLI auto-detects ADB-forwarded ports when standard mDNS discovery fails
- Multiple emulators with different AVDs (Pixel 4, Pixel 8, Tablet, etc.) can run simultaneously
- `getDeviceInfo` returns `isSimulator: true`

**Mixed fleets** — the CLI treats real devices, simulators, and emulators identically once discovered. The `isSimulator` flag in device info lets LLMs distinguish them if needed.

### Android — Chrome DevTools Protocol

Android WebView is Chromium-based. Enabling `setWebContentsDebuggingEnabled(true)` exposes CDP over a local Unix socket. The app connects to this socket and issues CDP commands:

- `DOM.*` — full DOM tree traversal and queries
- `Page.captureScreenshot` — screenshots
- `Runtime.evaluate` — JS evaluation via protocol
- `Input.dispatchMouseEvent` / `Input.dispatchTouchEvent` — input simulation
- `Emulation.*` — viewport and device metric control
- `Network.*` — request interception (future)

This is the same protocol Playwright and Chrome DevTools use.
