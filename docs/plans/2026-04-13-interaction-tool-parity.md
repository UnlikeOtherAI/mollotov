# Interaction Tool Parity and LLM Guidance

## Problem

LLMs are overusing screenshot-driven coordinate taps instead of semantic interaction tools. Two issues are contributing:

1. The cross-platform interaction surface is not fully aligned in the relevant fallback workflow.
   - Android `screenshot-annotated` does not return the same image payload as iOS/macOS.
   - iOS/macOS claim Shadow DOM capability, but the Shadow DOM LLM endpoints are only implemented on Android.
2. The MCP and CLI guidance does not clearly rank semantic interaction above coordinate tapping.
   - `tap` reads like a normal interaction primitive instead of a last-resort fallback.
   - `get-accessibility-tree`, `find-element`, and `click-annotation` do not explicitly advertise the preferred escalation order.

## Scope

Keep the change narrow and protocol-compatible:

1. Bring the interaction discovery and fallback tools into parity across iOS, Android, and macOS.
2. Preserve existing endpoint names and request shapes.
3. Update LLM-facing guidance to recommend this order:
   - `get-accessibility-tree`
   - `find-element` / `find-button` / `find-input`
   - `click` / `fill`
   - `screenshot-annotated` + `click-annotation` / `fill-annotation`
   - `tap` only when semantic and annotation-driven targeting both fail

## Proposed Changes

### 1. Pair the visual fallback workflow

Update Android `screenshot-annotated` so it returns the same core payload shape as iOS/macOS:

- `image`
- `width`
- `height`
- `format`
- `annotations`

Refactor Android screenshot capture into shared handler context or helper code rather than duplicating bitmap capture logic.

### 2. Pair the Shadow DOM tools

Implement `query-shadow-dom` and `get-shadow-roots` on iOS and macOS using the same JS bridge strategy already used on Android.

This keeps:

- `get-capabilities.shadowDOM = true`
- shared docs that describe Shadow DOM traversal as a supported but limited feature
- the shared MCP tool list honest for the Apple platforms

### 3. Make the interaction order explicit

Update the LLM-facing descriptions in:

- MCP tool metadata
- CLI command help metadata
- user-facing docs

So the model sees `tap` as a fallback, not a peer of selector-based interaction.

## Non-Goals

- No new HTTP or MCP endpoints.
- No native synthesized touch/pointer events in this change.
- No attempt to make closed Shadow DOM universally inspectable.

## Risks

- Android screenshot capture refactor must not regress the plain `screenshot` endpoint.
- Apple Shadow DOM helpers should stay limited to JS-readable roots and must fail cleanly when a root is closed or absent.
- Guidance changes should reduce coordinate tapping without hiding the `tap` tool entirely.

## Cross-Provider Review

Attempted via `max`, but the external shell client did not return actionable review output and stayed in an interactive spinner state. No provider findings were available to incorporate.

Given that failure, the implementation stayed deliberately narrow:

- no new HTTP or MCP endpoints
- parity fixes only for already-documented interaction tools
- guidance updates only to clarify the preferred interaction order
