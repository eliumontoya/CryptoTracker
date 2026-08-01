# Proposal: Add iOS as Build Destination

## Intent

`Crypto Tracker` targets macOS only (`SDKROOT = macosx`). We need iOS as a concurrent build destination so the app can run on iPhone/iPad simulators and devices alongside the existing macOS target. This is the first step in a cross-platform strategy — platform-compilation fixes follow in separate issues (#22-#25).

## Scope

### In Scope
- `project.pbxproj`: change `SDKROOT` from `macosx` → `auto` (Debug + Release)
- Add `SUPPORTED_PLATFORMS = "macosx iphoneos iphonesimulator"` (Debug + Release)
- Add `TARGETED_DEVICE_FAMILY = "1,2"` (Debug + Release)
- Add `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (Debug + Release)
- Conditional entitlements: `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` keeps existing file; `CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*] = ""` (Debug + Release)

### Out of Scope
- iOS compilation fixes: `NSWindow` guard (#22), `NSOpenPanel` guard (#23)
- AppIcon iOS slots (#24)
- Xcode scheme fix (#25)
- Any Swift source changes

## Capabilities

### New Capabilities
None — pure project configuration change, no new domain behavior.

### Modified Capabilities
None — no existing spec requirements change.

## Approach

**Conditional entitlements in pbxproj only** (zero new files). All 5 setting groups (4 project-level + 2 target-level) are line-mapped in `exploration.md`. Changes apply at project level so test targets inherit automatically. iOS needs no entitlements (outbound HTTPS is default; no sandbox), so the empty `[sdk=iphoneos*]` override suffices.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Crypto Tracker.xcodeproj/project.pbxproj` | Modified | ~12 lines across Debug/Release configs at project and app-target levels |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| iOS build fails with compile errors (NSWindow, NSOpenPanel, AppIcon) | High (guaranteed) | Known and deferred to #22-#24. macOS build must still succeed. |
| Entitlements file leaks to iOS build | Low | `[sdk=iphoneos*] = ""` blocks it; verifiable via `codesign -d --entitlements`. |

## Rollback Plan

Revert ~12 lines in `project.pbxproj`: restore `SDKROOT = macosx`, remove the 4 added build settings, remove `[sdk=...]` entitlement conditionals. No file creations to undo.

## Dependencies

None.

## Success Criteria

- [ ] `xcodebuild -scheme "Crypto Tracker" -destination "platform=macOS" build` still succeeds
- [ ] Xcode scheme dropdown shows iOS Simulator / iOS Device as selectable destinations
- [ ] `xcodebuild -showBuildSettings` confirms `SUPPORTED_PLATFORMS` includes `iphoneos iphonesimulator`
- [ ] `IPHONEOS_DEPLOYMENT_TARGET = 17.0` present in build settings output
