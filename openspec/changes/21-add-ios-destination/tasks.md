# Tasks: Add iOS as Build Destination

## Phase 1: pbxproj Edits

- [x] 1.1 **Edit project-level Debug config** — Replace `SDKROOT = macosx;` at L338 with `SDKROOT = auto;` followed by the three new settings (`SUPPORTED_PLATFORMS`, `TARGETED_DEVICE_FAMILY`, `IPHONEOS_DEPLOYMENT_TARGET`). Lines 281–343, block `451670322D2F71B800E6F2D6`.
- [x] 1.2 **Edit project-level Release config** — Same replacement at L394. Lines 344–398, block `451670332D2F71B800E6F2D6`.
- [x] 1.3 **Edit target-level Debug entitlements** — Replace `CODE_SIGN_ENTITLEMENTS = "Crypto Tracker/Crypto_Tracker.entitlements";` at L404 with the two conditional lines (`[sdk=macosx*]` + `[sdk=iphoneos*]`). Lines 399–426, block `451670352D2F71B800E6F2D6`.
- [x] 1.4 **Edit target-level Release entitlements** — Same replacement at L432. Lines 427–454, block `451670362D2F71B800E6F2D6`.

## Verification

- [ ] 2.1 **macOS build succeeds**: `xcodebuild -scheme "Crypto Tracker" -destination "platform=macOS" build` passes.
- [ ] 2.2 **iOS destinations visible**: Xcode scheme dropdown shows iOS Simulator and iOS Device.
- [ ] 2.3 **Build settings confirm iOS**: `xcodebuild -showBuildSettings` output includes `SUPPORTED_PLATFORMS = "macosx iphoneos iphonesimulator"` and `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- [ ] 2.4 **macOS entitlements intact**: `codesign -d --entitlements -` on macOS build shows App Sandbox and network entitlements.
- [ ] 2.5 **pbxproj format valid**: Open project in Xcode — no schema warnings or parse errors.

## Notes

- iOS build WILL produce compile errors (NSWindow, NSOpenPanel, AppIcon) — these are expected and addressed in #22, #23, #24.
- If `xcodebuild` with iOS destination is attempted: expect build failure. macOS build is the verification gate.
- Line numbers assume the current worktree state. If the pbxproj has changed since exploration, verify via content match rather than line number.
