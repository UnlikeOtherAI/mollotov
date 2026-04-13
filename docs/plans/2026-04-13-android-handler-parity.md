# Android Handler Parity

## Problem

Android is missing handler-layer parity for six routes that already exist on iOS and macOS:

- `get-console-messages`
- `get-js-errors`
- `watch-mutations`
- `stop-watching`
- `query-shadow-dom`
- `get-shadow-roots`

Some Android behavior already exists, but it is split across `devtools/` and `llm/` instead of the main `handlers/` layer, and console state is owned by one Android class instead of shared through `HandlerContext`.

## Root Cause

- Console route state is private to `devtools/ConsoleHandler`, while the rest of the platform uses `HandlerContext` as the shared browser execution seam.
- Mutation routes exist in `devtools/MutationHandler`, but parity work requested here belongs in `handlers/`.
- Shadow DOM routes were added to `LLMHandler`, so route ownership does not mirror Apple and is easy to miss when maintaining parity.
- Router stub registration is broad, so route parity depends on the right class registering the method first.

## Plan

1. Add Android `handlers/ConsoleHandler`, `handlers/MutationHandler`, and `handlers/ShadowDOMHandler` that mirror the Apple route structure.
2. Move console message storage into `HandlerContext` and have `JsBridge` append there directly so console capture survives handler refactors.
3. Remove duplicate registrations for these routes from `devtools/ConsoleHandler`, `devtools/MutationHandler`, and `LLMHandler`.
4. Register the new handler-layer routes from `MainActivity` and leave the router stub list unchanged except for any methods that no longer need to be treated as effectively missing.
5. Update functionality and API docs for Android parity in the same change.

## Cross-Provider Review

External adversarial review focused on four risks:

- `JsBridge` needs an explicit path into the shared console buffer or the refactor breaks console capture,
- duplicate route ownership should be eliminated rather than hidden by registration order,
- dead Android `devtools/` classes should not remain as alternate implementations,
- and the docs update needs to be explicit about which files change.

Assessment:

- The shared-state point is correct. Console buffers belong on `HandlerContext`, and `JsBridge` should append there directly.
- Duplicate route ownership is the real maintenance bug. Consolidating route registration and deleting the old Android `devtools/` handler copies is part of the fix.
- Reusing `JSEscape.string(...)` is the right Android equivalent to the Swift code.
- Mutation watchers should stay JS-local and ephemeral, matching Apple, with no added Android lifecycle storage.
- The docs change should be limited to [docs/api/devtools.md](docs/api/devtools.md) and [docs/functionality.md](docs/functionality.md) for this work.
