# LLM Screenshot Coordinate Mapping

## Problem

Calibration showed a real mismatch on macOS:

- viewport coordinates are in CSS pixels
- raw `tap` expects CSS-pixel viewport coordinates
- screenshots can be returned at retina resolution

Example from the live calibration page:

- viewport: `1610 x 1000`
- `devicePixelRatio`: `2`
- screenshot image: `3220 x 2000`

An LLM that localizes against the screenshot image and then sends those pixel coordinates directly to `tap` will miss by a scale factor even when app-side tap calibration is perfect.

There is a second problem in the semantic interaction path:

- `click(selector)` still uses `el.click()`
- `click-annotation` still uses `el.click()`

That bypasses coordinate-bearing pointer events, so selector targeting is not exercising the same interaction path as coordinate taps and cannot be validated with the calibration page.

## Goals

- Make screenshot coordinate space explicit in the API response.
- Give LLM-oriented screenshot flows non-retina images by default.
- Keep raw screenshot fidelity available for humans and debugging.
- Make selector-based activation dispatch coordinate-bearing pointer and mouse events at the target element center.
- Keep iOS and Android mirrored, and keep macOS/Linux aligned where the same surface exists.

## Non-Goals

- Do not introduce a matrix transform or anything more complex than explicit scale metadata.
- Do not change `tap` from viewport CSS pixels to any other coordinate space.
- Do not add OCR or vision-side heuristics.

## Protocol Changes

### Screenshot Request

Add optional `resolution`:

```json
{
  "resolution": "native" | "viewport"
}
```

Meaning:

- `native`: return the renderer snapshot at native output resolution
- `viewport`: return an image scaled to CSS viewport dimensions

Defaults:

- `screenshot`: `native`
- `screenshot-annotated`: `viewport`

Validation:

- unknown `resolution` values return `INVALID_PARAMS`
- every implementation defines a native enum/type instead of free-form strings

### Screenshot Response

Extend screenshot and annotated screenshot responses with explicit mapping metadata:

```json
{
  "success": true,
  "image": "...base64...",
  "width": 1610,
  "height": 1000,
  "format": "png",
  "resolution": "viewport",
  "coordinateSpace": "viewport-css-pixels",
  "viewportWidth": 1610,
  "viewportHeight": 1000,
  "devicePixelRatio": 2,
  "imageScaleX": 1,
  "imageScaleY": 1
}
```

For native retina screenshots, `imageScaleX` / `imageScaleY` can be `2`.

Rules:

- `tap`, annotation rects, and element rects continue to use viewport CSS pixels.
- `width` / `height` describe the returned image dimensions.
- `viewportWidth` / `viewportHeight` describe the coordinate system used by interaction endpoints.
- `imageScaleX` / `imageScaleY` are convenience fields computed at serialization time from `width / viewportWidth` and `height / viewportHeight`
- the new response fields are additive, so older clients can ignore them safely
- newer clients and MCP wrappers must still tolerate older servers that do not yet return the new metadata

## LLM Defaults

The MCP/browser tool wrappers should default screenshot requests to `resolution: "viewport"` so LLMs receive:

- smaller images
- matching image and viewport coordinate spaces when possible
- explicit scale metadata when not

This change belongs in:

- MCP tool schemas and descriptions
- CLI LLM help metadata
- API docs

The instructions must say:

1. Prefer semantic targeting first.
2. If you must localize visually, use `resolution: "viewport"` unless native detail is necessary.
3. If `imageScaleX` / `imageScaleY` are not `1`, convert image coordinates into viewport CSS pixels before calling `tap`.

## Interaction Changes

### `click(selector)`

Replace the current behavior:

```js
el.scrollIntoView(...)
el.click()
```

With:

1. resolve the element
2. scroll it into view
3. compute its center in viewport CSS pixels
4. resolve `document.elementFromPoint(centerX, centerY)`
5. if the hit-tested node is neither the target element nor one of its descendants/ancestors, fail with `ELEMENT_NOT_VISIBLE`
6. dispatch to the hit-tested node:
   - `pointerdown`
   - `mousedown`
   - `pointerup`
   - `mouseup`
   - compatibility `click`

This preserves semantic targeting, keeps the event target aligned with the rendered hit target, and makes the event stream observable and coordinate-bearing.

### `click-annotation`

Use the same coordinate-bearing activation path for the resolved annotated element.

Resolution rule:

- annotation indices always refer to the visible filtered DOM element list used to generate `screenshot-annotated`
- annotation rects are always reported in viewport CSS pixels, even when the image is returned at native scale

## Implementation Plan

### Shared Types and Docs

- extend screenshot response/request types in `packages/shared`
- add a shared `ScreenshotResolution` type
- update core and LLM API docs
- update CLI/MCP tool descriptions and help

### Apple Platforms

- add a shared screenshot payload helper in iOS/macOS handler context or screenshot handler helpers
- compute viewport metrics from JS:
  - `window.innerWidth`
  - `window.innerHeight`
  - `window.devicePixelRatio`
- downscale when `resolution == "viewport"`
- return `INVALID_PARAMS` for unknown `resolution`
- reuse a shared selector activation script in:
  - `click`
  - `click-annotation`

### Android

- extend `captureScreenshotPayload(...)` to:
  - compute viewport metrics from JS
  - optionally scale the bitmap to viewport size
  - return mapping metadata
- return `INVALID_PARAMS` for unknown `resolution`
- switch selector and annotation clicks to coordinate-bearing activation

### Linux

- expose screenshot payload metadata from the Linux HTTP layer when a browser-backed renderer is available
- keep the current `503` behavior only for builds that truly lack snapshot support
- report the same screenshot mapping fields as the Apple and Android handlers
- return `INVALID_PARAMS` for unknown `resolution`
- switch DOM-targeted activation to the same coordinate-bearing event sequence used by `tap`

### Shared Native Desktop Layer

- align the Chromium desktop screenshot and interaction handlers with the same metadata and activation rules
- keep Linux app behavior and the shared desktop engine behavior in sync so Linux does not become a one-off protocol variant

## Verification

1. On the calibration page, `screenshot` with `resolution: "viewport"` should report image width/height equal to viewport width/height.
2. On the calibration page, `screenshot` with `resolution: "native"` should report image scale metadata greater than `1` on retina/high-density devices where applicable.
3. `click(selector)` on a calibration target should update the page's pointer-observed coordinates, proving selector targeting uses coordinate-bearing events.
4. `click-annotation` should do the same.
5. `tap` remains unchanged except for using the same documented coordinate space.
6. selector and annotation clicks against obscured targets should fail with `ELEMENT_NOT_VISIBLE`.
7. invalid `resolution` values should fail consistently with `INVALID_PARAMS` on every platform.

## Cross-Provider Review

Reviewer: `max` in non-interactive mode

Accepted:

- Add native enum/type handling and explicit `INVALID_PARAMS` validation for `resolution` on every platform.
- Treat the screenshot metadata as additive for backward compatibility and document that newer clients must tolerate older servers.
- Define annotation index resolution explicitly so `screenshot-annotated`, `click-annotation`, and `fill-annotation` share one filtered DOM list.
- Fail selector and annotation activation with `ELEMENT_NOT_VISIBLE` when the center point is obscured instead of dispatching to an unrelated target.
- Keep `imageScaleX` / `imageScaleY` as convenience fields only, computed from the returned dimensions rather than stored state.

Rejected:

- Separate API versioning is not needed for this change because the request field is optional and the response fields are additive under `/v1/`.
- iOS safe-area handling does not require a separate coordinate transform because `window.innerWidth` / `window.innerHeight` already describe the WebView content viewport that Kelpie interaction endpoints use.
- CSS transforms do not need a separate mapping layer here because `getBoundingClientRect()` and pointer event coordinates already operate in the same viewport CSS pixel space.
