## Goal

Ensure real navigations are retained in history, avoid false history writes caused by tab selection, and autocomplete previously visited URLs from the address bar while typing.

## Root Cause

- iOS, Android, and macOS were recording history from the active browser state exposed to the top-level browser view.
- That state changes on tab switches as well as on real navigations, so history writes were coupled to presentation state instead of navigation state.
- The address bars had no shared history completion path, so prior visited URLs could not be suggested while typing.

## Constraints

- iOS and Android must remain in parity for user-facing behavior.
- The history/completion matching should be shared so platform behavior does not drift.
- The fix should not add secondary stores or duplicate navigation bookkeeping in multiple layers.

## Plan

1. Record history at the tab or renderer layer where real URL/title changes originate.
2. Remove history writes from top-level browser views on iOS, Android, and macOS.
3. Expose one shared native `best_url_completion` matcher from `core-state`.
4. Add thin platform wrappers around that matcher in iOS and Android, and reuse the existing macOS wrapper.
5. Update the address bars to show an inline completion remainder while editing and navigate to the completed URL on submit.
6. Document the user-facing behavior in `docs/functionality.md`.

## Expected Result

- A loaded URL remains present in history after tab switches and restart flows because it is recorded from real navigation state.
- Revisiting a URL moves it to the top instead of duplicating it.
- Typing a prefix such as `deep water` or `deepwater` can complete to the most recent matching prior URL.

## Cross-Provider Review

Attempted via `max`, but the external review command did not return usable output in this environment. Proceeded with a local adversarial review against the same criteria:

- Keep history writes at the navigation source, not at presentation-state observers.
- Share completion matching in `core-state` so iOS, Android, and macOS do not drift.
- Reuse one Android address-field composable instead of keeping two slightly different autocomplete implementations.
- Keep the URL-bar UI logic display-only; navigation resolution still comes from the shared matcher.
