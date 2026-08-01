# Proposal: Reconnect Movement Editing from Details

## Intent

Three detail views broke movement editing when `MovimientoSearchView` was commented out — init required 3 params but callers only passed 1. Restore editing by simplifying the init contract.

## Scope

### In Scope
- Add a convenience init to `MovimientoSearchView` accepting `movimientoDetalle` + `modelContext`
- Remove dead stored `mode` property (unused — `findEditMode()` re-derives mode from `@Query`)
- Uncomment `MovimientoSearchView` call in 3 detail views: `CarteraCryptoDetailView`, `CarteraMovimientosView`, `CryptoDetailViews`
- Ensure all 4 movement types (Entrada, Salida, EntreCarteras, Swap) edit correctly

### Out of Scope
- Fixing ad-hoc `ModelContainer` creation in `CarteraMovimientosView.init` (separate tech debt)
- Refactoring `MovimientoEntradaViewModel` to not require `ModelContext` at init time
- Modifying `EditMovementMode` enum shape
- UI/UX changes to the edit form itself

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `movement-editing`: `MovimientoSearchView` init simplified — accepts `modelContext` instead of pre-built `MovimientoEntradaViewModel` + unused `mode`

## Approach

1. **`MovimientoForms.swift` — `MovimientoSearchView`**:
   - Remove `var mode: EditMovementMode` stored property (dead — `findEditMode()` in body re-derives it from `@Query` results against `movimientoDetalle.tipo` and `id`)
   - Replace init with: `init(movimientoDetalle: MovimientoDetalle, modelContext: ModelContext)` — creates `MovimientosEntradaService` → `MovimientoEntradaViewModel` internally

2. **3 call sites** — each view already has a sheet for `viewModel.selectedMovimientoDetalle`:
   - Add `@Environment(\.modelContext) private var modelContext` to each view struct
   - Replace commented line with: `MovimientoSearchView(movimientoDetalle: movimientoDetalle, modelContext: modelContext)`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Views/Movimientos/MovimientoForms.swift` | Modified | Remove dead mode prop, new init signature |
| `Views/Portfolio/xCartera/CarteraCryptoDetailView.swift` | Modified | Add `@Environment`, uncomment call |
| `Views/Portfolio/xCartera/CarteraMovimientosView.swift` | Modified | Add `@Environment`, uncomment call |
| `Views/Portfolio/xCryptos/CryptoDetailViews.swift` | Modified | Add `@Environment`, uncomment call |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `modelContext` unavailable in nested sheet views | Low | Root `modelContainer` injected at `Crypto_TrackerApp.swift` — all sheets inherit |
| Save not reflected in parent list after edit | Med | `onDisappear` already calls `cargarMovimientos()` — verify after sheet dismiss |

## Rollback Plan

Revert the 4 file changes. The commented-out calls can be re-commented without data loss — no schema changes, no migration needed.

## Dependencies

None.

## Success Criteria

- [ ] Tapping a movement row in any of the 3 detail views opens an edit sheet
- [ ] Edit form loads the selected movement's data (all 4 types)
- [ ] Save updates the movement, closes the sheet, and refreshes parent list
- [ ] `xcodebuild build` passes without errors
