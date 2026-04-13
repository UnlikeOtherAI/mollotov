# Mobile mDNS Lifecycle Recovery

## Goal

Ensure Kelpie's mDNS advertisement matches platform lifecycle expectations:

- macOS advertises continuously for the lifetime of the running app instance.
- iOS and Android re-establish mDNS advertisement whenever the app returns to the foreground.
- Mobile apps do not rely on a one-time registration surviving an arbitrary background suspension period.

## Root Cause

Current mobile lifecycle handling starts mDNS once during app launch:

- iOS calls `startMDNS()` from `KelpieApp.startServices()`.
- Android calls `register()` from `MainActivity.startServer()`.

Neither platform currently has a foreground recovery path. If the OS suspends, drops, or invalidates the mDNS registration while the app is backgrounded, Kelpie returns to the foreground with a live HTTP server but no fresh advertisement attempt.

macOS does not share this exact problem because Bonjour advertisement is attached to the long-lived `HTTPServer` listener and stays up for the running app instance.

## Design

### iOS

- Add explicit `ensureMDNSAdvertising()` and `stopMDNS()` behavior to `ServerState`.
- Make `startMDNS()` idempotent by restarting only when needed instead of stacking listeners.
- Observe SwiftUI `scenePhase` in `KelpieApp`.
- On `.active`, call `ensureMDNSAdvertising()`.
- On `.background`, stop only the standalone mDNS advertiser. Leave the HTTP server lifecycle unchanged.

This keeps the invariant simple: foreground means Kelpie should be discoverable; background means iOS is free to suspend network advertisement, and foreground always repairs it.

### Android

- Add idempotent `ensureRegistered()` and `unregister()` behavior to `MDNSAdvertiser`.
- Hook `MainActivity.onStart()` to ensure registration.
- Hook `MainActivity.onStop()` to unregister.

This mirrors the iOS contract and keeps platform parity on mobile.

### macOS

- No lifecycle change.
- Keep the existing listener-backed Bonjour advertisement running for the lifetime of the server process.

## Scope

- iOS lifecycle wiring for mDNS recovery.
- Android lifecycle wiring for mDNS recovery.
- Documentation update describing the lifecycle guarantees.

## Verification

- iOS: launch app, verify advertising; background app; foreground app; verify advertising is re-established.
- Android: launch app, verify advertising; background app; foreground app; verify advertising is re-established.
- macOS: confirm existing behavior remains continuous while the app is running.

## Cross-Provider Review

Reviewer: `max`

Accepted findings:

- iOS `startMDNS()` must not replace advertisers without stopping the existing listener first.
- iOS needs explicit app-level `scenePhase` handling for foreground recovery.
- Android needs explicit `onStart()` and `onStop()` hooks instead of relying on one-time registration in `onCreate()`.
- Android teardown must avoid racing unregister/re-register across configuration changes.

Rejected or deferred:

- macOS recovery beyond the current long-lived HTTP listener is out of scope for this bug. The requirement here is continuous advertisement while the macOS app is running, which the current design already satisfies.
- Retry/backoff on mobile mDNS failure is deferred. A foreground transition already provides a natural retry boundary, and the current fix should stay minimal.
