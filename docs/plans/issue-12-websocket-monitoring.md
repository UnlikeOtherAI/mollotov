# Issue 12 — WebSocket Monitoring

## Goal

Add DevTools-style WebSocket visibility on macOS, iOS, and Android without introducing a second transport or persistent native state store. The feature should mirror the existing console/network bridge approach and expose two new `/v1/` endpoints:

- `get-websockets`
- `get-websocket-messages`

## Design

### Bridge model

- Inject a document-start bridge script on WebKit platforms using `WKUserScript`.
- Inject the equivalent script on Android through the existing `KelpieBridge` JavaScript interface path.
- Override `window.WebSocket` with a wrapper that delegates to the native constructor.
- Preserve native behavior by returning the real socket instance and patching methods/events on that instance rather than replacing the prototype tree with a custom fake object.

### Stored page state

The bridge script will create `window.__kelpieWebSockets` if it does not already exist. Each entry will contain:

- `url`
- `readyState`
- `protocol`
- `createdAt`
- `messagesSent`
- `messagesReceived`
- `lastMessages`

`lastMessages` is a ring-style bounded array with a default maximum of `50` entries. Each message entry stores:

- `direction`
- `data`
- `timestamp`

The bridge also stores a configurable `window.__kelpieWebSocketMessageLimit`, defaulting to `50`.

### Event capture

For each created socket:

- capture constructor arguments (`url`, optional protocols)
- update `readyState` and `protocol` on `open`
- update `readyState` on `close` and `error`
- wrap `send()` to count outbound messages and store a preview
- listen for `message` to count inbound messages and store a preview

Message payloads will be normalized to bounded strings:

- strings kept as-is up to a fixed preview cap
- `ArrayBuffer` recorded as `[ArrayBuffer N bytes]`
- `Blob` recorded as `[Blob type size bytes]`
- typed arrays recorded as `[TypedArrayConstructor N bytes]`
- unknown values stringified best-effort

This keeps responses JSON-safe and small.

### Native handler model

Handlers will follow the current network/console pattern:

- `get-websockets` evaluates page JS and returns connection summaries
- `get-websocket-messages` evaluates page JS and returns flattened recent messages, optionally filtered by `connectionIndex`

No native cache is needed. The page-owned state is already the source of truth and avoids synchronization bugs across navigation.

### Registration and parity

- Add `WebSocketHandler.swift` on macOS and iOS
- Add `WebSocketHandler.kt` on Android
- Register the routes in each platform router/bootstrap path
- Add the new methods to stub lists so unsupported wiring cannot silently 404
- Inject the bridge alongside the existing network/console bridges at document start

## Risks

- Some sites may inspect `window.WebSocket`; the wrapper should preserve `prototype`, `CONNECTING/OPEN/CLOSING/CLOSED`, and static shape as closely as practical.
- Binary messages can be large; previews must stay bounded.
- Sockets created before the bridge loads cannot be captured, which is why injection must happen at document start.

## Cross-Provider Review

Adversarial review findings from an external Codex pass:

- Android injection timing must be explicit. A JavaScript interface alone does not provide document-start interception, so the implementation must use a real document-start injection mechanism.
- `connectionIndex` is not durable enough as the only internal identifier. The bridge should assign each socket a stable per-page ID and treat `connectionIndex` as a query convenience only.
- `window.WebSocket` compatibility needs tighter handling than “preserve shape as closely as practical”. The wrapper must preserve constructor statics, prototype identity, and event behavior as much as possible while still returning the real socket instance.
- Page-owned state is inherently best-effort and page-tamperable. That is acceptable for observability, but it must be bounded and documented rather than treated as authoritative.
- Memory limits must be explicit: per-message preview cap and bounded message history.

Accepted changes for implementation:

- Use Android document-start injection rather than late `evaluateJavascript`.
- Add a stable internal socket ID in page state while keeping the external response format unchanged.
- Do not mutate `readyState` on `error`; only mirror observable state.
- Enforce hard preview and history caps in the bridge.
