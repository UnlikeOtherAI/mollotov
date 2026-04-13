# Coordinate Calibration Page

## Why This Exists

Raw coordinate taps are currently hard to debug and harder to correct:

1. `tap` on iOS, Android, and macOS shows a DOM overlay at the requested point, then runs `document.elementFromPoint(x, y)?.click()`.
2. That loses the original coordinate semantics. The page sees a programmatic `.click()`, not a real pointer sequence with `clientX` / `clientY`.
3. There is no persistent app-level calibration offset for coordinate taps.
4. There is no bundled local diagnostic page that can be opened on-device and used to measure, preview, save, and verify offsets.

The result is that when coordinate taps drift, operators and LLMs are forced into guesswork.

## Goals

- Ship one built-in coordinate calibration page with every browser build on iOS, Android, macOS, and Linux.
- Make the page reachable at a stable local URL served by the embedded HTTP server.
- Show exact viewport-relative coordinates for manual taps/clicks anywhere on the page.
- Expose enough coordinate context to debug the transform instead of hiding everything behind one opaque offset value.
- Allow the operator to save persistent X/Y tap offsets per app install.
- Make raw `tap` use calibrated coordinates and dispatch real pointer/mouse events with coordinates, not only `.click()`.
- Keep semantic actions (`click`, `fill`, `click-annotation`) unchanged.

## Non-Goals

- Do not change selector-based interaction semantics.
- Do not add LLM-first automation around the page beyond what existing `navigate` and `tap` already provide.
- Do not attempt matrix or scale correction in this pass. This feature stores only additive X/Y offsets.
- Do not treat this page as a fix for model screenshot-localization mistakes. It calibrates the app-side coordinate application path only.
- Do not add Windows work in this change.

## User Flow

1. Open `http://127.0.0.1:8420/debug/coordinate-calibration` in any Kelpie browser.
2. Tap or click anywhere on the page to see exact viewport-relative coordinates.
3. Use the built-in test targets and the current saved offsets to preview where automated taps will land.
4. Adjust `offsetX` / `offsetY`, save, and rerun the preview until the calibrated marker lands exactly on the intended target.
5. Use normal `tap` automation. The saved offsets are applied automatically.

## Route Surface

### Local Debug Page

- `GET /debug/coordinate-calibration`

Returns the bundled HTML page. This is not part of the external browser-control API. It is a local debug surface hosted by the app itself.

### New API Endpoints

- `POST /v1/get-tap-calibration`
- `POST /v1/set-tap-calibration`

These are part of the normal browser API because the page needs persistent native storage and operators may want to inspect/update calibration programmatically.

#### `get-tap-calibration`

Response:

```json
{
  "success": true,
  "offsetX": 0,
  "offsetY": 0
}
```

#### `set-tap-calibration`

Request:

```json
{
  "offsetX": 12,
  "offsetY": -4
}
```

Response:

```json
{
  "success": true,
  "offsetX": 12,
  "offsetY": -4
}
```

Validation:

- `offsetX` and `offsetY` are required numbers.
- Values are stored as viewport CSS-pixel offsets.

## Tap Semantics Change

`tap` remains a raw coordinate fallback, but its implementation changes.

### Current

```js
var el = document.elementFromPoint(x, y);
if (el) el.click();
```

### New

1. Load saved offsets.
2. Compute calibrated coordinates:

```text
appliedX = requestedX + offsetX
appliedY = requestedY + offsetY
```

3. Clamp the calibrated coordinates into the current visible viewport so wildly bad offsets do not push the event path offscreen:

```text
appliedX = clamp(appliedX, 0, viewportWidth - 1)
appliedY = clamp(appliedY, 0, viewportHeight - 1)
```

4. Show the touch indicator at `appliedX` / `appliedY`.
4. Dispatch a coordinate-bearing event sequence at the calibrated point:
   - `pointerdown`
   - `mousedown`
   - `pointerup`
   - `mouseup`
   - `click`
5. Use `MouseEvent` fallback when `PointerEvent` is unavailable.
6. Prefer the element at the calibrated point, but fall back to `document.body` so the page still receives the synthetic coordinates even when no interactive element is hit.
7. Preserve compatibility by keeping `x` and `y` in the success response as the requested coordinates, and add:
   - `appliedX`
   - `appliedY`
   - `offsetX`
   - `offsetY`

Example response:

```json
{
  "success": true,
  "x": 200,
  "y": 300,
  "appliedX": 212,
  "appliedY": 296,
  "offsetX": 12,
  "offsetY": -4
}
```

## Calibration Page Design

The page is a single bundled HTML file with inline CSS and JavaScript to keep packaging simple.

### Layout

- Fixed metrics bar at the top:
  - viewport width/height
  - `devicePixelRatio`
  - `visualViewport` width/height/offset/scale when available
  - `scrollX` / `scrollY`
  - current saved offsets
  - last manual tap coordinates
  - last automated requested/applied coordinates
- Main calibration field:
  - dark background
  - 3x3 target grid labeled `A1` through `C3`
  - each target shows its exact CSS-pixel coordinates
  - targets sit inside the visible viewport, not on the edges, so browser chrome and safe-area behavior are obvious
- Bottom control strip:
  - `offsetX` numeric input
  - `offsetY` numeric input
  - save button
  - reset button
  - rerun grid preview button
  - copy-state button

### Behaviors

- Manual tap/click anywhere:
  - shows a fixed marker
  - records `clientX` / `clientY`
  - updates the metrics bar
- Automated preview:
  - the page posts to `/v1/tap` for each target coordinate
  - the page records the requested and applied coordinates returned by the API
  - the page shows:
    - target marker
    - requested marker
    - applied marker
  - preview taps occur only inside the dedicated calibration field so page controls are not accidentally triggered by the synthetic events
- Save:
  - posts to `/v1/set-tap-calibration`
  - refreshes current state from `/v1/get-tap-calibration`
- Reset:
  - saves `0,0`

### Page-to-Tap Hook

The page defines:

```js
window.__kelpieTapCalibration = {
  onAutomationTap(payload) { ... }
}
```

When `tap` executes on any page, it checks for that hook. If present, it reports:

```json
{
  "requestedX": 200,
  "requestedY": 300,
  "appliedX": 212,
  "appliedY": 296,
  "offsetX": 12,
  "offsetY": -4
}
```

That lets the calibration page render the requested/applied markers before the event sequence fires.

## Asset Strategy

Use one shared source HTML file in the repo and bundle that same file into each platform build.

Proposed source:

- `assets/diagnostics/coordinate-calibration.html`

Platform packaging:

- iOS: add the HTML file to the app bundle resources.
- macOS: add the HTML file under bundled resources.
- Android: include the shared asset via Gradle `assets` source dirs.
- Linux: copy the shared asset next to the executable in the post-build step.

Serving strategy:

- iOS/macOS: read from `Bundle.main`.
- Android: read from app assets.
- Linux: read from the executable directory.

## Persistence

Store the calibration offsets in the simplest native store already used by each platform:

- iOS: `UserDefaults`
- macOS: `UserDefaults`
- Android: `SharedPreferences`
- Linux: JSON or text file in the existing profile directory

Proposed logical key:

- `tapCalibrationOffsetX`
- `tapCalibrationOffsetY`

Linux file:

- `<profile_dir>/tap-calibration.json`

## Platform Scope

### iOS

- Bundle and serve the page.
- Add calibration storage.
- Update `tap` to use calibrated pointer/mouse event dispatch.

### Android

- Bundle and serve the page.
- Add calibration storage.
- Update `tap` to use calibrated pointer/mouse event dispatch.

### macOS

- Bundle and serve the page.
- Add calibration storage.
- Update `tap` to use calibrated pointer/mouse event dispatch.

### Linux

- Bundle and serve the page.
- Add calibration storage.
- Add `tap` support for the browser-backed build so the page can self-test.
- If the Linux app is running in the current non-browser stub path, return `PLATFORM_NOT_SUPPORTED` for `tap` and keep the page limited to manual coordinate readout.

## Documentation Changes

Update in the same change:

- `docs/api/core.md`
- `docs/functionality.md`
- `docs/architecture.md`

Document:

- the new `get-tap-calibration` / `set-tap-calibration` endpoints
- the built-in page URL
- the fact that `tap` now applies stored offsets and dispatches pointer/mouse events instead of only `.click()`

## Verification

- Open the built-in page on iOS, Android, macOS, and Linux browser-backed builds.
- Manual taps/clicks update coordinates correctly.
- Save non-zero offsets, reload the page, verify offsets persist.
- Run the built-in grid preview, confirm applied markers move by the saved offset.
- Call `/v1/tap` directly and verify the response includes requested/applied/offset values.
- Confirm selector-based `click` behavior is unchanged.

## Limits

- The page can prove whether Kelpie is applying viewport coordinates correctly and consistently.
- The page cannot fix an LLM choosing the wrong point inside a screenshot image. That is a separate visual-grounding problem.

## Cross-Provider Review

External review via `max` on the initial concept pushed two useful constraints:

1. Do not reduce the problem to a single unexplained magic offset. The page must expose the coordinate stack that matters during debugging.
Accepted:
the metrics bar includes viewport, DPR, visual viewport, and scroll information, and the page distinguishes requested vs applied coordinates.

2. The diagnostic surface should let the operator see both the intended target and the resulting applied point, not just save numbers.
Accepted:
the page renders target, requested, and applied markers and can rerun built-in preview taps after each save.

Self-audit tightened the design further:

1. Calibrated coordinates must be clamped into the viewport before dispatch.
Accepted.

2. This feature only calibrates the app-side additive coordinate path. It must not claim to solve screenshot-localization errors or non-linear transforms.
Accepted.
