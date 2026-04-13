# 2026-04-13 Issue Sweep Batch 2

## Scope

This batch addresses:

- `#1` LLM feedback loop / `report-issue`
- `#2` click and tap diagnostics
- `#4` richer `--llm-help`
- `#5` platform support marking and honest capabilities
- automatic session restore on restart for the tabbed app shells

## Goals

1. Make failures actionable for LLMs instead of opaque.
2. Make tool availability visible before a command is attempted.
3. Make `--llm-help` rich enough that an LLM can choose parameters and parse results without guessing.
4. Add a real feedback pipeline instead of only telling LLMs to file GitHub issues manually.
5. Make iOS, Android, and macOS restore open tabs and pages automatically after restart.

## Non-Goals

- Auto-pushing reports to GitHub. This remains a future consent-gated step.
- Reworking the native desktop single-renderer Linux/Windows runtime into a real tabbed shell.
- Adding diagnostics for every endpoint in one pass. This batch targets the highest-signal interaction failures first.

## Root Causes

### 1. Help metadata is too thin

`packages/cli/src/help/llm-help.ts` currently flattens Zod schemas into only `name`, `type`, `required`, and `description`. It drops:

- enum values
- nested object and array shapes
- default values
- platform restrictions
- response shapes
- error descriptions

This causes models to guess.

### 2. Platform support has no shared surfaced contract in the CLI/help layer

The native MCP registry already knows platform availability, but the TypeScript CLI/MCP surface does not expose equivalent structured support data. The result is:

- MCP descriptions only sometimes mention restrictions in prose
- `--llm-help` has no `platforms` field
- discovery does not expose `get-capabilities`
- Android still returns fake success for unsupported endpoints

### 3. Error responses are structurally too small

Browser error responses currently stop at `code` and `message`. For selector and coordinate failures, that is not enough for self-correction.

### 4. Session restore is inconsistent and manual

iOS and Android already persist sessions, but they restore through a prompt instead of automatically. macOS has tabs but no persisted session restore. The user requirement is restart continuity, not optional restoration.

## Decisions

### A. Standardize a richer error envelope

The cross-platform error envelope becomes:

```json
{
  "success": false,
  "error": {
    "code": "ELEMENT_NOT_FOUND",
    "message": "No element matches selector '#submit'",
    "diagnostics": {
      "...": "endpoint-specific context"
    }
  }
}
```

This is additive and backward-compatible for existing consumers that only read `code` and `message`.

### B. Add first-class diagnostics for interaction failures

This batch adds structured diagnostics to:

- `click`
- `fill`
- `click-annotation`
- `fill-annotation`

`tap` will also return hit-target diagnostics on success so LLMs can see what was actually hit at the applied point.

Common diagnostic fields:

- `viewport`
- `scrollPosition`
- `selector` when relevant
- `targetRect` and `targetCenter` when relevant
- `obstruction` when the intended element is covered
- `actualElementAtPoint` for coordinate interactions

`ELEMENT_NOT_FOUND` for selector-driven interactions will also include a bounded `similarElements` list derived from visible interactive elements whose text, id, name, or classes resemble selector tokens.

### C. Keep diagnostics implementation local to each browser runtime, but use the same shape

The implementation will stay platform-native:

- iOS: Swift JS helper scripts in handler support files
- Android: Kotlin JS helper scripts in handler support files
- macOS: Swift JS helper scripts in handler support files
- Linux desktop: C++ JS helper script in the Chromium desktop handler

The shape stays consistent even if the implementation differs.

### D. Add `report-issue` end to end

#### Browser endpoint

Add `POST /v1/report-issue` on iOS, Android, macOS, and Linux.

Accepted payload:

- `category`
- `command`
- `params`
- `error`
- `context`
- `url`
- `platform`
- `diagnostics`
- `screenshotBase64`

The endpoint will normalize the payload, attach device identity and timestamp, write a JSON file locally, and return:

```json
{
  "success": true,
  "reportId": "...",
  "storedAt": "...",
  "platform": "ios",
  "deviceId": "..."
}
```

#### CLI / MCP exposure

Add:

- `kelpie report-issue`
- `kelpie feedback-summary`
- `kelpie_report_issue`
- `kelpie_feedback_summary`

The CLI will also store a normalized local copy under `~/.kelpie/feedback/` so feedback remains visible even when the report originated from a remote device. `feedback-summary` will aggregate those local copies by category, command, platform, and error code.

### E. Add structured platform support metadata to the CLI/MCP/help layer

`BrowserToolDef` and `CliToolDef` gain a structured `platforms` field.

Rules:

- absent means all current platforms
- restricted tools set explicit platform lists
- MCP descriptions are decorated with a `Platforms:` suffix when the tool is restricted
- `--llm-help` includes `platforms`
- `kelpie explain` includes platforms

This batch will mark at least:

- renderer switching: macOS only
- Safari auth: Apple platforms
- iOS debug display tools: iOS only
- fullscreen: desktop platforms that actually implement it
- keyboard APIs: iOS and Android
- geolocation and request interception only where truly implemented

### F. Make capability reporting honest

#### Runtime response shape

iOS, Android, and macOS `get-capabilities` will move to the shared shape:

```json
{
  "success": true,
  "version": "0.1.0",
  "platform": "ios",
  "supported": [],
  "partial": [],
  "unsupported": []
}
```

#### Android unsupported endpoints

Android geolocation and request interception stubs will stop returning fake success and will return `PLATFORM_NOT_SUPPORTED` until they are actually implemented.

#### Discovery enrichment

`discover` will enrich discovered devices with `get-capabilities` in parallel and store the result in the local registry when reachable. This is additive. Auto-scan during implicit device lookup does not need to block on enrichment.

### G. Upgrade `--llm-help` structurally, not with prose patches

`--llm-help` entries will include:

- `platforms`
- structured `params`
- enum values
- default values when known
- nested object and array shapes
- `errors` as `{ code, description }`
- `response`

Response modeling strategy:

- every command gets at least a base response shape showing `success`
- high-signal commands get richer field shapes from a maintained response metadata map

This avoids pretending that every command has bespoke response docs when the repo does not yet have a generated schema pipeline.

### H. Make restart restore automatic on the tabbed app shells

#### iOS / Android

Remove the pending-session restore prompt and restore the last saved tab set automatically at startup.

#### macOS

Add a `SessionStore` for `TabStore` and restore automatically on launch.

Persistence rule:

- save the current tab set and active tab continuously on tab structure and URL changes
- also save on lifecycle exit where appropriate
- blank start pages do not replace a valid persisted session

## Implementation Outline

1. Introduce shared help metadata support for:
   - error descriptions
   - param defaults and nested shapes
   - response metadata
   - platform metadata
2. Add local CLI feedback storage plus `report-issue` / `feedback-summary` commands and MCP tools.
3. Add browser-side `report-issue` handlers and stores on iOS, Android, macOS, and Linux.
4. Standardize `get-capabilities` on iOS, Android, and macOS.
5. Replace Android fake-success unsupported stubs with `PLATFORM_NOT_SUPPORTED`.
6. Add structured click/fill/annotation diagnostics and tap hit-target reporting across platforms.
7. Switch iOS and Android to automatic restore, and add macOS session persistence/restore.
8. Update docs and close the resolved issues.

## Risks

- The Android and macOS interaction handler files are already near the file-size limit, so diagnostics support may require helper extraction before adding logic.
- Discovery enrichment adds network calls. The implementation should keep the capability fetch timeout short and non-fatal.
- Automatic restore changes startup behavior. Any welcome/start-page flow must not wipe a valid saved session.

## Cross-Provider Review

Attempted with `max` as the project-preferred external reviewer.

- `max -p "Say only OK."` succeeded, confirming the wrapper is installed and callable.
- Multiple substantive adversarial review prompts for this plan stalled and then timed out without returning content, even after reducing the prompt size and scope.

Because the provider was not available for a useful design review in this session, implementation proceeds with the documented plan and the failure is recorded here.
