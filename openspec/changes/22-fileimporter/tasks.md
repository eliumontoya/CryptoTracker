# Tasks — feat(ui): reemplazar NSOpenPanel por .fileImporter

Change: `22-fileimporter` — Issue #22
Platform: iOS 14+ / macOS 11+ (project: iOS 17 / macOS 14)

## Phase 1: Replace NSOpenPanel with .fileImporter

- [x] 1.1 Read the 3 affected files and locate every `NSOpenPanel` usage
- [x] 1.2 Add `@State private var isShowingFileImporter` to `FileSelectionRow` (SharedComponents.swift)
- [x] 1.3 Replace `seleccionarArchivo()` NSOpenPanel with
      `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` and remove the `#if os(macOS)` guard
- [x] 1.4 Verify with grep that no NSOpenPanel or AppKit references remain in the affected files
- [x] 1.5 Persist tasks.md + apply-progress to engram (topic_key `sdd/22-fileimporter/apply-progress`, project `cryptotracker`)

## Review Workload Forecast

- Decision needed before apply: No
- Chained PRs recommended: No
- 400-line budget risk: Low (single-file edit, ~20 lines)
