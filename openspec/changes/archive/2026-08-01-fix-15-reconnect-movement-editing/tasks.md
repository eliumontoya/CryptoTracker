# Tasks: Reconnect Movement Editing from Details

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~25–35 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | ask-always |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Simplify MovimientoSearchView init + reconnect 3 call sites | PR 1 | `xcodebuild build -scheme "Crypto Tracker"` | N/A — UI sheet presentation, manual verification only | All 4 files; revert restores old init + re-comments sheets |

## Phase 1: Foundation — Simplify MovimientoSearchView

- [x] 1.1 In `Crypto Tracker/Views/Movimientos/MovimientoForms.swift`, remove the stored property `var mode: EditMovementMode` from `MovimientoSearchView`
- [x] 1.2 In the same file, remove `@Environment(\.modelContext) private var modelContext` from `MovimientoSearchView`
- [x] 1.3 Add `let modelContext: ModelContext` stored property to `MovimientoSearchView`
- [x] 1.4 Replace the existing init with the new 2-parameter init: `init(movimientoDetalle: MovimientoDetalle, modelContext: ModelContext)` — internally create `MovimientosEntradaService(modelContext:)` then `MovimientoEntradaViewModel(movimiento: nil, movimientoService:)` via `StateObject` wrapped value

## Phase 2: Integration — Reconnect Call Sites

- [x] 2.1 In `Crypto Tracker/Views/Portfolio/xCartera/CarteraCryptoDetailView.swift`, add `@Environment(\.modelContext) private var modelContext` and uncomment the `MovimientoSearchView(movimientoDetalle:modelContext:)` call inside `.sheet(item:)`
- [x] 2.2 In `Crypto Tracker/Views/Portfolio/xCartera/CarteraMovimientosView.swift`, add `@Environment(\.modelContext) private var modelContext` and uncomment the `MovimientoSearchView(movimientoDetalle:modelContext:)` call inside `.sheet(item:)`
- [x] 2.3 In `Crypto Tracker/Views/Portfolio/xCryptos/CryptoDetailViews.swift`, add `@Environment(\.modelContext) private var modelContext` and uncomment the `MovimientoSearchView(movimientoDetalle:modelContext:)` call inside `.sheet(item:)`

## Phase 3: Verification

- [ ] 3.1 Run `xcodebuild build -scheme "Crypto Tracker"` — confirm zero compilation errors (blocked by Xcode license agreement in this environment)
- [ ] 3.2 Manual: tap a movement row in CarteraCryptoDetailView → verify edit sheet opens with correct movement data
- [ ] 3.3 Manual: tap a movement row in CarteraMovimientosView → verify edit sheet opens with correct movement data
- [ ] 3.4 Manual: tap a movement row in CryptoDetailViews → verify edit sheet opens with correct movement data
- [ ] 3.5 Manual: for each movement type (Entrada, Salida, EntreCarteras, Swap), verify the form loads existing values, save, and confirm the list refreshes
