# Exploration: feat(ui) — reemplazar NSOpenPanel por .fileImporter

## Current State

`FileSelectionRow` (`Crypto Tracker/Views/Admin/SetupInicial/CargaMovimientos/SharedComponents.swift`)
is the only file-picker component in the app. Its `seleccionarArchivo()` opens an `NSOpenPanel`
inside an `#if os(macOS)` guard added by change #21 (commit `9f69be5`) to make the target compile
for iOS. On iOS the "Seleccionar" button is currently a **no-op** — the guard is empty.

The component is consumed 8 times:

- `CargaCatalogosView.swift` — 4 rows via the single-type `init(title:subtitle:url:type:)` (CSV).
- `CargaMovimientosInicialesView.swift` — 4 rows via the multi-type
  `init(title:subtitle:url:types:)` using `ExcelReader.validateExcelTypes()` (`[xlsx]`).

Both initializers are already supported by the component (`types: [UTType]`), so the consumers'
call sites do NOT need API changes.

### Scope check (grep across `Crypto Tracker`)

- `NSOpenPanel` / `.runModal()` — only in `SharedComponents.swift` L61/L66.
- `import AppKit` — none in the codebase.
- `NSWindow.willCloseNotification` — `CryptoSyncView.swift` L52 (also wrapped by #21). This is a
  different concern (window-close cleanup, macOS-only lifecycle hook) with no cross-platform
  equivalent and is **out of scope** for #22, which is strictly the file-picker replacement.
- `.fileImporter` availability — iOS 14+ / macOS 11+ (deployment targets: iOS 17, macOS 14). OK.

## Affected Areas

- `Crypto Tracker/Views/Admin/SetupInicial/CargaMovimientos/SharedComponents.swift` — the only
  file requiring edits: remove NSOpenPanel + guard, attach `.fileImporter`.
- `Crypto Tracker/Views/Admin/SetupInicial/CargaCatalogosView.swift` — consumes `FileSelectionRow`
  (4 rows); behavior changes (picker now works on iOS) but no code edits needed.
- `Crypto Tracker/Views/Admin/SetupInicial/CargaMovimientos/CargaMovimientosInicialesView.swift` —
  consumes `FileSelectionRow` (4 rows); behavior changes but no code edits needed.

## Approaches

1. **Self-contained `FileSelectionRow`** — the row owns `@State private var isShowingFileImporter`
   and attaches `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` to its own body;
   the "Seleccionar" button sets the flag. Consumers keep their exact call sites.
   - Pros: single source of truth for picker logic; component stays reusable; no per-row state or
     result-routing boilerplate in 2 parent views; matches existing component contract.
   - Cons: parents receive no explicit edits (they are affected only by behavior).
   - Effort: Low

2. **Parent-level `.fileImporter`** — each parent owns 4 `isShowingFileImporter` flags plus
   result routing back to the right URL binding, with the row exposing a trigger callback.
   - Pros: picker presentation lives next to the parent's state.
   - Cons: 8 duplicated flag/state blocks; routing logic per row; breaks the reusable-component
     contract; more surface for bugs. No benefit over option 1.
   - Effort: Medium

## Recommendation

**Approach 1 — self-contained `FileSelectionRow`.** It is the idiomatic SwiftUI pattern, keeps the
"componente reutilizable" contract intact, and both parent views keep compiling unchanged.

Completion-handler semantics (verified against Apple docs):
- On success → assign `url = selectedURL`.
- On cancel → `onCompletion` is NOT called (the picker just dismisses) — no error UI needed.
- On failure → log; matches the codebase's existing `print("❌ ...")` diagnostic pattern
  (cf. `ExcelReader.swift` L134).

## Risks

- **macOS sandbox / security-scoped URL**: `.fileImporter` returns a security-scoped URL, and
  Apple recommends `startAccessingSecurityScopedResource()`. The pre-existing NSOpenPanel path
  never called it either (verified: zero references in the codebase). This change keeps **parity**
  with current behavior; if macOS sandbox file reads regress, a follow-up would add
  start/stop-scoped-access around the URL consumption in the ViewModels.
- **CLI build verification unavailable**: `xcodebuild` is not usable (active developer directory
  is CommandLineTools; no `Package.swift` for `swift test` — see `openspec/project-context.md`).
  Verification is limited to grep + review; a real build must run in Xcode.
- **Out-of-scope AppKit reference**: `CryptoSyncView.swift` L52 (`NSWindow.willCloseNotification`)
  remains — do NOT remove its guard here.

## Ready for Proposal

Yes — single-file edit, low risk, verified scope. Tell the user: only `SharedComponents.swift`
changes; the two parent views are behavior-affecting consumers only; `CryptoSyncView`'s NSWindow
guard is intentionally untouched (separate concern).
