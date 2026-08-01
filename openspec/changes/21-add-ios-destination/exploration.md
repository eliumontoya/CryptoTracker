# Exploration: feat(infra) — agregar iOS como destination al target

## Current State

`Crypto Tracker.xcodeproj/project.pbxproj` (583 lines, objectVersion 77) is a **macOS-only**
project. The main app target (`PBXNativeTarget "Crypto Tracker"`, `4516700C2D2F71B700E6F2D6`,
`com.apple.product-type.application`) has:
- `SDKROOT = macosx` at the project level (Debug + Release) — hard-pinned to macOS.
- No `SUPPORTED_PLATFORMS`, no `TARGETED_DEVICE_FAMILY`, no `IPHONEOS_DEPLOYMENT_TARGET` anywhere.
- macOS deployment: project-level `15.2`, overridden to `14.0` at every target level (main + tests).
- One shared entitlements file `Crypto Tracker/Crypto_Tracker.entitlements` with **macOS-only**
  entitlements: `com.apple.security.app-sandbox`, `files.user-selected.read-only`,
  `network.client`, `network.server`, `network.client.dns`. Applied unconditionally to the app
  target (Debug + Release). Applying app-sandbox to an iOS build fails codesign → entitlements
  MUST be conditional per SDK.
- No shared xcscheme; the management plist references a shared scheme that does not exist
  (stale). Not part of this issue's scope.
- Swift Package dependencies: CoreXLSX 0.14.2 (+ XMLCoder, ZIPFoundation). CoreXLSX declares
  platforms `macOS 10.11 / iOS 9 / tvOS 9 / watchOS 2` → **no package blocker for iOS 17**.

## Affected Areas

- `Crypto Tracker.xcodeproj/project.pbxproj` — the ONLY file this change touches.

## Exact Settings Map (line numbers from the wt-21 worktree)

### Project-level XCBuildConfiguration `451670322D2F71B800E6F2D6 /* Debug */` (lines 281–343)

| Setting | Line | Current | New |
|---|---|---|---|
| `MACOSX_DEPLOYMENT_TARGET` | 334 | `15.2` | keep (effective macOS target = 14.0 via target override) |
| `SDKROOT` | 338 | `macosx` | `auto` |
| `SUPPORTED_PLATFORMS` | — (absent) | — | add: `"macosx iphoneos iphonesimulator"` |
| `TARGETED_DEVICE_FAMILY` | — (absent) | — | add: `"1,2"` |
| `IPHONEOS_DEPLOYMENT_TARGET` | — (absent) | — | add: `17.0` |

### Project-level XCBuildConfiguration `451670332D2F71B800E6F2D6 /* Release */` (lines 344–398)

| Setting | Line | Current | New |
|---|---|---|---|
| `MACOSX_DEPLOYMENT_TARGET` | 391 | `15.2` | keep (same rationale) |
| `SDKROOT` | 394 | `macosx` | `auto` |
| `SUPPORTED_PLATFORMS` | — (absent) | — | add: `"macosx iphoneos iphonesimulator"` |
| `TARGETED_DEVICE_FAMILY` | — (absent) | — | add: `"1,2"` |
| `IPHONEOS_DEPLOYMENT_TARGET` | — (absent) | — | add: `17.0` |

Project-level placement makes tests/UITests targets inherit everything automatically.

### Target-level `Crypto Tracker` app configs

- `451670352D2F71B800E6F2D6 /* Debug */` (lines 399–426):
  - **L404**: `CODE_SIGN_ENTITLEMENTS = "Crypto Tracker/Crypto_Tracker.entitlements";`
    → replace with SDK-conditional lines (see Approaches).
  - L410 `ENABLE_HARDENED_RUNTIME = YES`, L406 `COMBINE_HIDPI_IMAGES = YES` — macOS-only,
    silently ignored on iOS. **No change needed.**
  - L418 `MACOSX_DEPLOYMENT_TARGET = 14.0` — keep (satisfies "macOS 14.0").
- `451670362D2F71B800E6F2D6 /* Release */` (lines 427–454):
  - **L432**: same `CODE_SIGN_ENTITLEMENTS` line → same conditional replacement.
  - L446 `MACOSX_DEPLOYMENT_TARGET = 14.0` — keep.

### Test targets (no edits)

- `Crypto TrackerTests` (451670382D/451670392D) and `Crypto TrackerUITests`
  (4516703B2D/4516703C2D): inherit `SUPPORTED_PLATFORMS`/`SDKROOT`/deployment targets from
  project level. `TEST_HOST`/`BUNDLE_EXECUTABLE_FOLDER_PATH` resolve correctly per platform.

## Entitlements Approaches

1. **Conditional build settings in pbxproj only (recommended)** — keeps the single-file scope:
   ```pbxproj
   CODE_SIGN_ENTITLEMENTS[sdk=macosx*] = "Crypto Tracker/Crypto_Tracker.entitlements";
   CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*] = "";
   ```
   iOS needs NO entitlements (outbound HTTPS is default; no sandbox). The explicit empty
   override documents intent. Zero new files.
   - Pros: single-file change; App Sandbox cannot leak to iOS; no dead entitlements.
   - Cons: iOS build runs without an entitlements file (fine; signing works).
   - Effort: Low
2. **Second entitlements file** — `Crypto_Tracker_iOS.entitlements` (empty or `network.client`)
   wired via `[sdk=iphoneos*]`.
   - Pros: explicit file per platform.
   - Cons: violates the "single file: project.pbxproj" constraint; new file to maintain.
   - Effort: Low

## Risks (iOS build will NOT compile from the pbxproj change alone)

- **`Crypto Tracker/Views/Admin/CryptoSyncView.swift` L51** — `NSWindow.willCloseNotification`
  (macOS-only, reached via SwiftUI→AppKit on macOS; does not exist on iOS → compile error).
  Needs `#if os(macOS)` guard (or conditional `.task`).
- **`Crypto Tracker/Views/Admin/SetupInicial/CargaMovimientos/SharedComponents.swift` L60** —
  `NSOpenPanel()` (macOS-only → compile error on iOS). Needs `#if os(macOS)` + `.fileImporter`
  alternative for iOS.
- **AppIcon asset catalog** — `Assets.xcassets/AppIcon.appiconset` has only `mac` idiom slots.
  Building for iOS fails actool ("app icon set did not have any applicable content") unless the
  catalog gains iOS slots, or a single-file mitigation
  `ASSETCATALOG_COMPILER_APPICON_NAME[sdk=iphoneos*] = "";` is added.
- Project-level `MACOSX_DEPLOYMENT_TARGET = 15.2` vs target-level `14.0` is inconsistent but
  harmless; effective value is 14.0. Leave as-is to keep the diff minimal, or align to 14.0.
- UI tests target launches "Crypto Tracker" by name — works on iOS simulator once the app
  compiles.

## Ready for Proposal

Yes — the pbxproj edits are fully mapped. The orchestrator MUST tell the user that selecting
the iOS destination will surface 2 compile errors (`NSWindow`, `NSOpenPanel`) and one actool
error (AppIcon), which are follow-up fixes outside this issue's single-file scope.
