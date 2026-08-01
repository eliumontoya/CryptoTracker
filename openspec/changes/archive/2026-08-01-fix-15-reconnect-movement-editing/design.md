# Design: Reconnect Movement Editing from Details

## Technical Approach

Replace `MovimientoSearchView`'s 3-parameter init with a 2-parameter init that creates its own `MovimientoEntradaViewModel` internally. Callers no longer need to build a VM from incomplete data (`MovimientoDetalle` vs `MovimientoIngreso`). The dead `mode` stored property is removed — `findEditMode()` already re-derives `EditMovementMode` from `@Query` results.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep pre-built VM param | Caller needs `MovimientoIngreso` but only has `MovimientoDetalle` — impossible at call site | Rejected |
| Inject `MovimientosEntradaServiceProtocol` directly | Adds another parameter without simplifying callers | Rejected |
| Inject `ModelContext` and build VM+Service internally | Self-contained init; callers pass only what they have | **Chosen** |

### Decision: Remove dead `mode` stored property

**Rationale**: `findEditMode()` is the authoritative source of `EditMovementMode` — it queries `@Query` arrays against `movimientoDetalle.tipo` and `id` every render. The stored `mode` property was never read. Keeping it introduces a parallel, untrusted source that can diverge.

## Data Flow

```
User taps row
    │
    ▼
DetailView.sheet(item: $viewModel.selectedMovimientoDetalle)
    │  passes MovimientoDetalle + modelContext
    ▼
MovimientoSearchView(movimientoDetalle:, modelContext:)
    │  init: MovimientosEntradaService(modelContext)
    │         → MovimientoEntradaViewModel(movimiento: nil, service:)
    │  body: findEditMode() → EditMovementMode(matched model)
    ▼
EditMovimientoView(mode:, movimientoEntradaViewModel:)
    ├── .entrada      → MovimientoEntradaFormView(pre-created VM)
    ├── .salida       → VM created inline with matched model
    ├── .entreCarteras → VM created inline with matched model
    └── .swap         → VM created inline with matched model
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `Crypto Tracker/Views/Movimientos/MovimientoForms.swift` | Modify | Remove `mode` stored property and unused `@Environment(\.modelContext)`; add `let modelContext: ModelContext`; new init creates service → VM internally |
| `Crypto Tracker/Views/Portfolio/xCartera/CarteraCryptoDetailView.swift` | Modify | Add `@Environment(\.modelContext) private var modelContext`; uncomment `MovimientoSearchView` call |
| `Crypto Tracker/Views/Portfolio/xCartera/CarteraMovimientosView.swift` | Modify | Add `@Environment(\.modelContext) private var modelContext`; uncomment `MovimientoSearchView` call |
| `Crypto Tracker/Views/Portfolio/xCryptos/CryptoDetailViews.swift` | Modify | Add `@Environment(\.modelContext) private var modelContext`; uncomment `MovimientoSearchView` call |

## Interfaces / Contracts

**New init**:
```swift
init(movimientoDetalle: MovimientoDetalle, modelContext: ModelContext) {
    self.movimientoDetalle = movimientoDetalle
    self.modelContext = modelContext
    let service = MovimientosEntradaService(modelContext: modelContext)
    _movimientoEntradaViewModel = StateObject(wrappedValue:
        MovimientoEntradaViewModel(movimiento: nil, movimientoService: service))
}
```

**What is removed from `MovimientoSearchView`**:
- `@Environment(\.modelContext) private var modelContext` — replaced by the explicit parameter stored as `let`
- `var mode: EditMovementMode` — dead; `findEditMode()` re-derives it

**Call site pattern** (identical across all 3 views):
```swift
@Environment(\.modelContext) private var modelContext

// In .sheet(item:) body:
MovimientoSearchView(movimientoDetalle: movimientoDetalle, modelContext: modelContext)
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | No compilation errors | `xcodebuild build` passes |
| Integration | Sheet opens in all 3 detail views | Manual — tap movement row, verify edit sheet appears |
| E2E | All 4 movement types edit and save | Manual — open each type, verify form loads, save, verify list refreshes on dismiss |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. No schema changes, no data migration. Rollback plan: revert the 4 files — re-comment the 3 sheet calls and restore the old init signature.

## Open Questions

- [ ] `EditMovimientoView` passes the pre-created VM (`movimiento: nil`) to `MovimientoEntradaFormView` for `.entrada` without calling `loadMovimiento()`. For `.salida`, `.entreCarteras`, and `.swap`, VMs are created inline _with_ the matched model. Confirm whether the `.entrada` path already calls `loadMovimiento()` elsewhere (e.g., `onAppear` inside `MovimientoEntradaFormView`), or whether a follow-up fix is needed in `EditMovimientoView` to pass the found `MovimientoIngreso`.
