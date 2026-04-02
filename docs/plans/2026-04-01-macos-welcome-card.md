# macOS Welcome Card

## Goal

Add the same welcome screen used by the iOS and Android apps to the macOS app.

## Scope

- Show the welcome card over the macOS browser shell on first launch.
- Reuse the same copy and dismissal behavior as iOS:
  - tap outside to dismiss
  - "Don't show this again" persists to `hideWelcomeCard`
  - "Get Started" dismisses
- Add a native shell-level bottom info card on macOS for the existing `toast` endpoint so MCP/server messages appear in app chrome instead of only inside page DOM.
- Keep the card visually aligned with the existing iOS/macOS look rather than introducing a separate onboarding flow.

## Implementation Plan

1. Add a macOS `WelcomeCardView` that mirrors the iOS structure and text.
2. Mount it in the macOS `BrowserView` as a top-level overlay above browser content and floating controls.
3. Use `@AppStorage("hideWelcomeCard")` and local `showWelcome` state exactly as on iOS, while also supporting desktop dismissal via `Esc`.
4. Add a native shell toast state to macOS and render it as a bottom card overlay in `BrowserView`.
5. Update user-facing docs to mention the welcome card and native shell toast on macOS.

## Non-Goals

- No new onboarding steps, tutorials, or settings links.
- No protocol or API changes.
- No redesign of the existing iOS/Android welcome copy.

## Risks

- The overlay must not interfere with the recently reworked macOS floating-menu hit testing after dismissal, and must not click through to underlying controls.
- The card should look native on macOS while staying materially identical to iOS.
- The native shell toast should replace duplicate page-level messaging on macOS so users do not see the same message twice.

## Cross-Provider Review

Gemini findings:

- Add explicit desktop dismissal handling such as `Esc`.
- Avoid click-through when dismissing an overlay over live controls.
- A standard macOS sheet would be more native than a full-window overlay.

Assessment:

- Accepted: add `Esc` dismissal and guard against click-through.
- Rejected: use a separate sheet. The request is to add the same welcome screen used on iOS, not invent a different macOS onboarding window.
