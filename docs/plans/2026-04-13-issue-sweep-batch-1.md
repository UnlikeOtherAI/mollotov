# 2026-04-13 Issue Sweep Batch 1

## Goal

Triage the full GitHub issue set for `UnlikeOtherAI/kelpie`, close issues that are already resolved, and implement the highest-signal open gaps that are clearly reproducible from the current codebase.

## Current Issue Triage

Open issues reviewed:

1. `#1` LLM feedback / `report-issue`
Status: Open. No HTTP handler, CLI command, or MCP tool exists yet.

2. `#2` Click/tap diagnostics on failure
Status: Open. Success responses improved, but failure payloads still do not include the requested diagnostics bundle.

3. `#3` Missing CLI commands for existing MCP tools
Status: Open. `toast`, `debug-screens`, `set-debug-overlay`, `get-debug-overlay`, and `safari-auth` still have MCP tools but no CLI commands.

4. `#4` Richer `--llm-help`
Status: Open. Help output still lacks default values, enum values, response shapes, and richer error descriptions.

5. `#5` Platform support matrix in CLI/MCP
Status: Partially addressed, still open. Native MCP availability exists, but CLI / `--llm-help` still does not surface platform availability cleanly enough.

6. `#6` CEF `set_cookie` broken in external loop mode
Status: Open. Workaround exists; root fix does not.

7. `#7` Instruct LLMs to report issues
Status: Fixed in this sweep. The CLI help footer, full `--llm-help` output, MCP server description, and docs now point LLMs to the GitHub issue tracker when automation fails unexpectedly.

8. `#8` Annotation lifecycle clarity
Status: Open. Annotation tools are documented, but lifecycle/expiry semantics are still not surfaced clearly enough.

9. `#9` Chromium release monitor
Status: Open. Current bundled CEF is still `chromium-146.0.7680.165`, not the issue target `146.0.7680.177`.

11. `#11` `click` text treated like CSS selector
Status: Open, but the issue framing is partly wrong. `click` is intentionally selector-based. The real bug is that invalid selector syntax degrades into a generic JS error instead of a clearer command-level failure.

12. `#12` WebSocket monitor
Status: Open. No CLI/API support exists.

13. `#13` `fill` fails on `textarea`
Status: Open and reproducible in current code on all browser-backed platforms. The code still resolves `HTMLInputElement.prototype.value` first and applies it to `textarea`.

14. `#14` `type` does not sync React controlled components
Status: Open and reproducible in current code on all browser-backed platforms. No `_valueTracker` sync logic exists.

Closed issues reviewed:

10. `#10` Gecko release monitor
Status: Already closed.

## Batch Scope

Implement now:

- `#3` Add the missing CLI commands for already-exposed MCP tools.
- `#7` Add issue-reporting guidance to the LLM-facing help surfaces.
- `#13` Fix `fill` for `textarea`.
- `#14` Fix `type` / `fill` value syncing for React-style controlled inputs and textareas.

Close after verification:

- `#3`
- `#7`
- `#13`
- `#14`

Leave open for later:

- `#1`, `#2`, `#4`, `#5`, `#6`, `#7`, `#8`, `#9`, `#11`, `#12`

## Design

### A. CLI surface parity for existing tools

Add CLI commands for:

- `toast <message>`
- `debug-screens`
- `debug-overlay get`
- `debug-overlay set <enabled>`
- `safari-auth [url]`

Update:

- command registration
- `command-metadata.ts`
- `docs/cli.md`
- command coverage tests

### B. Cross-platform form-value helper logic

Root cause:

- `fill` and `type` currently use `HTMLInputElement.prototype.value` first, which throws when applied to a `textarea`.
- framework-controlled inputs are updated without syncing value trackers, so React can revert the DOM value immediately after events fire.

Fix shape:

- introduce small per-platform JS helper snippets that:
  - detect input vs textarea before choosing a setter
  - capture previous value
  - update the framework tracker (when present) back to the previous value before dispatching `input`
  - optionally dispatch `change` at the end of a typing sequence

Apply the same invariant to:

- selector-based `fill`
- selector-based `type`
- annotation-based fill paths where they directly assign `el.value`

Platforms in scope:

- iOS
- Android
- macOS
- Linux / shared Chromium desktop runtime

## Verification

- `pnpm lint`
- `pnpm build`
- `pnpm test`
- `make lint-swift`
- `cd apps/android && ./gradlew build`
- `cmake -S apps/linux -B apps/linux/build && cmake --build apps/linux/build`
- macOS live smoke test:
  - use a fresh tab
  - load a disposable page with a `textarea`
  - verify `fill textarea ...` works
  - verify a React-style controlled input/textarea stays synced after `type`

## Cross-Provider Review

External review was requested after this plan was written, but repeated `max` review attempts stalled without returning actionable output. I proceeded with the implementation after local code review and cross-platform build verification because the batch was narrowly scoped to:

- exposing already-existing MCP functionality through the CLI
- fixing the same form-control invariant across all browser-backed platforms

## Outcome

Implemented:

- `#3` missing CLI command coverage for existing MCP tools
- `#7` issue-reporting guidance in the CLI, MCP, and docs
- `#13` `fill` on `textarea`
- `#14` React-style controlled input and textarea syncing for `type` and `fill`

Verified:

- `pnpm lint`
- `pnpm build`
- `pnpm test`
- `make lint-swift`
- `cd apps/android && ./gradlew build`
- `cmake -S apps/linux -B apps/linux/build && cmake --build apps/linux/build`
- macOS `xcodebuild -project apps/macos/Kelpie.xcodeproj -scheme Kelpie -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- iOS `xcodebuild -project apps/ios/Kelpie.xcodeproj -scheme Kelpie -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build`
- live macOS smoke test on a fresh tab:
  - `fill` updated a `textarea`
  - `type` updated a controlled input and its rendered state
