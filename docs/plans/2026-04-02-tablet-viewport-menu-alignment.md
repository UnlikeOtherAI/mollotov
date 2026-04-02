# Tablet Viewport Menu Alignment

## Problem

The tablet staged-viewport UI is inconsistent across surfaces:

- The iPad `View` menu and tablet floating menu do not present the same fitting preset set clearly.
- The floating picker still uses short labels that do not match the top menu naming.
- The floating picker is anchored too close to the radial action fan, so pills can cover action buttons.

Android must mirror the same behavior as iPad.

## Root Cause

- iOS floating pills render `label`, while the top menu renders `menuLabel`.
- Android still uses a local hard-coded preset store with short labels and no laptop entries.
- The floating picker placement uses a fixed horizontal offset from the phone button instead of reserving horizontal space outside the radial action arc.

## Plan

1. Keep the native preset catalog intact. Do not remove or reorder built-in entries as a behavior fix.
2. Normalize tablet staged preset presentation on iOS and Android around one display label format.
3. Expand Android's mirrored preset store to include the same tablet and laptop entries already exposed by the shared native catalog.
4. Reposition the floating picker farther outside the fan, widen pills enough for the unified labels, and stack them without overlapping the fan buttons.
5. Update the mobile/tablet docs to describe the broader fitting preset set and the unified naming.

## Cross-Provider Review

External Codex review agreed with the root cause but called out one extra risk: Android still duplicates the preset catalog and label model locally, so a UI-only patch on iOS would preserve drift instead of fixing it. The implementation should therefore:

- keep the native catalog unchanged,
- align Android's mirrored preset list with the same tablet and laptop entries already present in the shared catalog,
- use one visible label format across top-menu and floating-picker surfaces,
- and support more than a single short column once tablet and laptop presets are included, otherwise the picker can overflow vertically even after moving it outside the fan.
