# Exploration: Adapt MovimientosEntradaViewModel to movement use cases

**Issue**: #40 — `refactor(ui): adaptar MovimientosEntradaViewModel a use cases`.
Replace the inline `TransactionRunner` + `HoldingService` orchestration in
`MovimientoEntradaViewModel` with the 3 domain use cases built in #37/#38/#39.

## Current State

`Crypto Tracker/Movimientos/MovimientosEntradaViewModel.swift`
(class `MovimientoEntradaViewModel`) owns the full persistence orchestration
inline:

- `save()` edit path (lines 142–159): snapshots the movement, mutates the
  entity's fields, and calls `holdingService.updateHoldingForMovement(_:previous:in:)`
  inside a `transactionRunner.run` block.
- `save()` create path (lines 160–178): builds `Movimiento.entrada(...)`,
  inserts it and calls `holdingService.updateHoldingForMovement(_:in:)` inside
  `transactionRunner.run`, then stores the new entity in `self.movimiento`.
- `delete()` (lines 189–216): reverts the holding and `context.delete`s the
  movement inside `transactionRunner.run`, then calls `unloadMovimiento()`.

The ViewModel still depends on `transactionRunner` + `holdingService` (optional
init params defaulted to `ModelContextTransactionRunner` + `HoldingService`).

## Affected Areas

- `Crypto Tracker/Movimientos/MovimientosEntradaViewModel.swift` — the refactor
  target: swap inline save/delete bodies for use-case calls.
- `Crypto Tracker/App/AppDependencyContainer.swift` — 2 creation sites already
  wire `transactionRunner`/`holdingService`; must pass the 3 use cases instead.
- `Crypto Tracker/Domain/UseCases/Movements/{Register,Edit,Delete}MovementUseCase.swift`
  — already exist (internal structs + protocols), no changes needed.
- `Crypto TrackerTests/MovimientoEntradaViewModelTests.swift` — must keep
  compiling/passing untouched (hence optional init params with defaults).
- `Crypto Tracker/Movimientos/lib/MovimientosEntradaListViewModel.swift`,
  `Crypto Tracker/ViewModels/Portfolio/xCryptos/PortfolioCryptosViewModel.swift`
  — create the VM with `modelContext` only; must keep working via defaults.

## Approaches

1. **Required use cases via init (strict DI)** — init takes the 3 use cases as
   required parameters; drop `modelContext`/`transactionRunner`/`holdingService`
   from the VM.
   - Pros: cleanest; VM owns no service construction.
   - Cons: cascades — `MovimientosEntradaListViewModel` and
     `PortfolioPorCryptosViewModel` need use cases threaded through their inits,
     plus 3 test instantiation sites updated. Touches 5+ files beyond the issue
     scope.
   - Effort: Medium–High

2. **Optional use cases with defaults (mirror existing pattern)** — init gains
   `registerUseCase`/`editUseCase`/`deleteUseCase` optional params defaulting to
   use cases built from a local `ModelContextTransactionRunner` + `HoldingService`;
   `AppDependencyContainer` injects the real shared use cases explicitly.
   - Pros: matches the exact convention already in this file for
     `transactionRunner`/`holdingService` (optional + default, container
     injects); zero changes to tests, list VM, portfolio VM; change stays
     scoped to VM + container.
   - Cons: VM keeps a construction fallback for non-DI callers (tests/previews).
   - Effort: Low

3. **Use cases required, update everything** — same as 1 but accepts the full
   test churn.
   - Effort: High — rejected as over-scoped for this issue.

## Recommendation

**Approach 2.** Replace the inline `transactionRunner.run` + `holdingService`
calls in `save()`/`delete()` with the 3 use cases:

- create path → `registerUseCase.register(RegisterMovementInput(...))` (stores
  the returned `Movimiento` in `self.movimiento`);
- edit path → `editUseCase.execute(EditMovementInput(movement:updated:))` with
  the form fields mapped into `EditMovementValues` (note field order: `crypto`
  before `cartera` in the value struct);
- delete path → `deleteUseCase.delete(movimiento)` followed by
  `unloadMovimiento()`.

Keep every UI concern intact: `@Published` form/state properties, Combine
bindings (`setupBindings`), `formIsValid`, `precioFiatAlterno`,
`validateForm()`, `loadMovimiento`/`unloadMovimiento`, `defer { isLoading }`
and the same error/`uiState` handling.

Behavioral deltas adopted deliberately (use-case contracts are the new source
of truth): register stamps `holding.updatedAt = movimiento.fecha`; edit and
delete pre-validate the holding revert and throw
`EditMovementError.insufficientHoldings` / `DeleteMovementError.insufficientHoldings`
instead of silently clamping.

## Risks

- `EditMovementValues` memberwise init field order (`crypto` before `cartera`)
  differs from `RegisterMovementInput` (`cartera` before `crypto`) — must match
  each struct exactly or the build fails.
- New validation errors are Spanish and flow through the existing
  `errorMessage`/`hasError` UI, so no UI change needed; the entrada test suite
  scenarios (1.0 BTC register, edit 1→2, delete with revert) stay within the
  non-negative invariant and must remain green.
- `MovimientosEntradaListViewModel`/`PortfolioPorCryptosViewModel` keep their
  own default-constructed services — unchanged behavior, out of scope.

## Ready for Proposal

Yes. Implementation = 2 file edits (VM + DI container) + 2 openspec artifacts.
Workload far below the 400-line review budget.
