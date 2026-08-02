# Issue #30: chore: limpiar código muerto y archivos residuales

## Goal
Remove dead code and residual files to keep the codebase clean and consistent.

## Phase 1: Delete residual files

- [x] 1.1 Delete `Crypto Tracker/Views/Movimientos/MovimientosViews.swift` (empty, only imports)
- [x] 1.2 Delete `Crypto Tracker/Model/MovimientoFormType.swift` (unused enum)

## Phase 2: Unify movement error systems

- [x] 2.1 Add `.sameCartera` case to `MovimientoFormCommonError`
- [x] 2.2 Replace all `MovimientoFormError` usages with `MovimientoFormCommonError`
- [x] 2.3 Remove the `MovimientoFormError` struct from `MovimientoSharedTypes.swift`
- [x] 2.4 Replace `ErrorInformacionFaltante` / `ErrorDeNegocio` in `MovimientosEntradaService.swift` with `MovimientoFormCommonError`
- [x] 2.5 Delete `Crypto Tracker/Model/Errores/erroresExtend.swift` and empty `Model/Errores` directory

## Phase 3: Repository hygiene

- [x] 3.1 Delete `Crypto Tracker.zip` from repo root (if present)
- [x] 3.2 Add `*.zip` to `.gitignore` (`.DS_Store` already present)

## Phase 4: Remove unused code

- [x] 4.1 Delete `Crypto TrackerTests/MovimientosEntradaTests.swift` (fully commented-out test file)

## Phase 5: Verify

- [x] 5.1 Run `xcodebuild build` and confirm no errors
- [x] 5.2 Run `xcodebuild test` and confirm no new failures

## Review Workload Forecast

- 400-line budget risk: Low
- Chained PRs recommended: No
- Decision needed before apply: No
- Mode: single PR
