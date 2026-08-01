# Design: Add iOS as Build Destination

## Technical Approach

Single-file edit to `project.pbxproj` — zero new files, zero Swift changes. Four project-level settings unlock iOS as a concurrent build destination alongside macOS. Two target-level conditional entitlement entries prevent macOS App Sandbox from leaking into iOS builds. All changes apply to both Debug and Release configurations.

### Architecture Decisions

| # | Decision | Choice | Alternatives | Rationale |
|---|---------|--------|-------------|-----------|
| 1 | SDKROOT | `auto` | `macosx` (current), `iphoneos` | `auto` lets Xcode resolve the SDK per destination — macOS uses `macosx`, iOS simulator uses `iphonesimulator`. No need to pick one |
| 2 | Platform settings placement | Project-level | Target-level | Project-level inheritance means test targets (Crypto TrackerTests, UITests) inherit iOS support automatically — no duplicate edits |
| 3 | Entitlements strategy | Conditional `[sdk=macosx*]` + empty `[sdk=iphoneos*]` | Separate entitlements file for iOS | iOS needs no entitlements (outbound HTTPS is default, no sandbox). Explicit empty override documents intent. Single file vs new maintainable artifact |
| 4 | IPHONEOS_DEPLOYMENT_TARGET | 17.0 | 16.0, 18.0 | Matches SwiftUI maturity baseline; Swift Package deps (CoreXLSX) support iOS 9+. 17.0 is the pragmatic floor for modern SwiftUI APIs |

### Data Flow

No runtime data flow — pure Xcode build configuration.

```
macOS destination ──► SDKROOT=auto resolves macosx ──► CODE_SIGN_ENTITLEMENTS[sdk=macosx*] applies
iOS destination   ──► SDKROOT=auto resolves iphonesimulator ──► CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]="" applies
```

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `Crypto Tracker.xcodeproj/project.pbxproj` | Modify | ~16 lines: 4 project-level setting changes × 2 configs + 2 entitlement lines × 2 configs |

### Exact Edit Sequence

All edits target `Crypto Tracker.xcodeproj/project.pbxproj`. Block IDs for reference:

- `451670322D2F71B800E6F2D6` = Project Debug (lines 281–343)
- `451670332D2F71B800E6F2D6` = Project Release (lines 344–398)
- `451670352D2F71B800E6F2D6` = Target Debug (lines 399–426)
- `451670362D2F71B800E6F2D6` = Target Release (lines 427–454)

#### Edit 1 — Project Debug (L338)

```
OLD: 				SDKROOT = macosx;
NEW: 				SDKROOT = auto;
				SUPPORTED_PLATFORMS = "macosx iphoneos iphonesimulator";
				TARGETED_DEVICE_FAMILY = "1,2";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

#### Edit 2 — Project Release (L394)

Same replacement as Edit 1.

#### Edit 3 — Target Debug (L404)

```
OLD: 				CODE_SIGN_ENTITLEMENTS = "Crypto Tracker/Crypto_Tracker.entitlements";
NEW: 				"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" = "Crypto Tracker/Crypto_Tracker.entitlements";
				"CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" = "";
```

#### Edit 4 — Target Release (L432)

Same replacement as Edit 3.

### Interfaces / Contracts

None — no new types, APIs, or data structures. Pure build system configuration.

### Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | macOS build still succeeds | `xcodebuild -scheme "Crypto Tracker" -destination "platform=macOS" build` |
| Build | iOS destination is selectable | Open Xcode, verify scheme dropdown shows iOS Simulator and iOS Device |
| Settings | Build settings confirm iOS support | `xcodebuild -showBuildSettings` — verify `SUPPORTED_PLATFORMS` includes `iphoneos iphonesimulator`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0` |
| Entitlements | macOS entitlements intact | `codesign -d --entitlements - "path/to/Crypto Tracker.app"` on macOS build — App Sandbox present |
| Entitlements | iOS build has no entitlements | `codesign -d --entitlements -` on iOS build — empty or absent |
| Negative | iOS build WILL fail with compile errors | NSWindow, NSOpenPanel, AppIcon — expected failures deferred to #22, #23, #24 |

### Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

### Migration / Rollout

No migration required. Rollback: revert the 4 edits in `project.pbxproj`.

### Open Questions

None — all settings are line-mapped and verified against the actual pbxproj.

### Known Limitations

- iOS build will NOT compile after this change (NSWindow, NSOpenPanel, AppIcon errors) — these are deferred to issues #22, #23, #24
- macOS build must remain fully functional
- Xcode scheme may need regeneration (#25) but is not required for the pbxproj edit to take effect
