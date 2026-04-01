# iOS Native Core Integration

The iOS store wrappers in `apps/ios/Mollotov/Browser/` now call the shared C API from `native/core-state/include/mollotov/state_c_api.h`.

The Xcode project is not updated automatically. Do not edit `project.pbxproj` by hand unless you have to. Configure the target in Xcode instead.

## 1. Set the bridging header

For the `Mollotov` target, set:

- `Objective-C Bridging Header` = `$(PROJECT_DIR)/Mollotov/Mollotov-Bridging-Header.h`

The header itself is already in the repo at:

- `apps/ios/Mollotov/Mollotov-Bridging-Header.h`

## 2. Add header search paths

For the `Mollotov` target, add these to `Header Search Paths`:

- `$(SRCROOT)/../native/core-state/include`
- `$(SRCROOT)/../native/core-protocol/include`

Mark them `recursive = No`.

Notes:

- `$(SRCROOT)` here is `apps/ios`.
- The bridging header imports `mollotov/state_c_api.h`, so `native/core-state/include` must be visible to Clang.
- `libmollotov_core_state.a` depends on `libmollotov_core_protocol.a`, so both headers and both libraries must be configured together.

## 3. Add the static libraries

Add these files to the `Mollotov` target and ensure they are linked in `Link Binary With Libraries`:

- `/tmp/mollotov-build/core-protocol/libmollotov_core_protocol.a`
- `/tmp/mollotov-build/core-state/libmollotov_core_state.a`

If you prefer search paths instead of direct file references, add these to `Library Search Paths`:

- `/tmp/mollotov-build/core-protocol`
- `/tmp/mollotov-build/core-state`

Then add:

- `libmollotov_core_protocol.a`
- `libmollotov_core_state.a`

## 4. Keep the wrapper expectations in mind

The Swift stores assume:

- `mollotov/state_c_api.h` is visible through the bridging header
- both static libraries are linked into the app target
- bookmark and history continue using the existing UserDefaults keys
- network traffic persists under `mollotov_network_traffic` because there was no previous iOS persistence key for that store

## 5. Rebuild after wiring

After the target settings are updated, rebuild the iOS app in Xcode. The store files will not compile until the bridging header and static libraries are configured.
