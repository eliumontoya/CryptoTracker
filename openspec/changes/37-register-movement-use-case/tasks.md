# Tasks: 37-register-movement-use-case — RegisterMovementUseCase (entrada)

**Issue #37**: Create a domain use case that registers an entry movement + holding atomically
(movement + holding in one transaction).

## Phase 1: Exploration

- [x] 1.1 Explore existing patterns: `TransactionRunner`, `HoldingService`, `Movimiento.entrada`
      factory, `MovimientoEntradaViewModel.save()`, DI container. **Finding**: the issue text
      references `MovimientosEntradaServiceProtocol`, which was deleted in `fix-35-wire-transaction-runner`
      (commit `1a9059e`); the real primitives are `TransactionRunner` + `HoldingServiceProtocol`.
- [x] 1.2 Confirm how entries are created today: `MovimientoEntradaViewModel.save()` builds
      `Movimiento.entrada(...)` and runs insert + `updateHoldingForMovement` inside
      `transactionRunner.run` (lines 160–178).
- [x] 1.3 Gap vs. issue business rules: `HoldingService` stamps `updatedAt = Date()`; issue
      requires `holding.updatedAt = movimiento.fecha` — must be enforced by the use case.

## Phase 2: Implementation

- [x] 2.1 **`Crypto Tracker/Domain/UseCases/Movements/RegisterMovementUseCase.swift`** — new;
      `RegisterMovementInput` (fecha, cantidadCrypto, precioUSD, usaFiatAlterno,
      precioFiatAlterno, valorTotalFiatAlterno, cartera, crypto, fiatAlterno),
      `RegisterMovementUseCaseProtocol` (`register(_:) async throws -> Movimiento`),
      `struct RegisterMovementUseCase` taking `TransactionRunner` + `HoldingServiceProtocol`
      via init (DI). Creates `Movimiento.entrada`, inserts + applies holding delta atomically
      via the runner, and stamps `holding.updatedAt = movimiento.fecha`.
- [x] 2.2 **`Crypto Tracker/App/AppDependencyContainer.swift`** — expose
      `registerMovementUseCase: RegisterMovementUseCaseProtocol`, initialized from the
      container's `transactionRunner` + `holdingService`.
- [x] 2.3 **`Crypto TrackerTests/RegisterMovementUseCaseTests.swift`** — new; Swift Testing,
      5 `@Test` cases (entry fields + holding, accumulation into existing holding,
      FIAT-alternate fields, `updatedAt == fecha`, rollback atomicity via throwing
      `HoldingServiceProtocol` fake).
- [x] 2.4 **`Crypto TrackerTests/AppDependencyContainerTests.swift`** — assert
      `dependencies.registerMovementUseCase` is non-nil.

## Phase 3: Verification

- [x] 3.1 `xcodebuild build` — passes (0 errors, pre-existing warnings only).
- [x] 3.2 `xcodebuild build-for-testing` — passes (0 errors).
- [x] 3.3 Focused suites (RegisterMovementUseCase, HoldingService, TransactionRunner,
      AppDependencyContainer, MovimientoEntradaViewModel) — 49/49 passed.
- [x] 3.4 Full suite — 125 passed / 20 failed; the 20 failures are exactly the pre-existing
      baseline in 6 suites (CargaCatalogos, CargaMovimientos, CargaMovimientosViewModel,
      EliminarData, MovimientoEntreCarteras, MovimientoSalida). **0 new failures.**

## Work Unit Evidence

| Evidence | Required value |
|---|---|
| Focused test command and exact result | `xcodebuild test-without-building -only-testing:RegisterMovementUseCaseTests ...` → 5/5 passed (2 runner passes, all green) |
| Runtime harness command and exact result | `xcodebuild build-for-testing` EXIT 0; `xcodebuild test-without-building` focused suites 49/49, full suite 125/20 vs. 120/20 baseline |
| Rollback boundary | Delete `Crypto Tracker/Domain/UseCases/Movements/RegisterMovementUseCase.swift`, `Crypto TrackerTests/RegisterMovementUseCaseTests.swift`; revert 1-line DI edits in `AppDependencyContainer.swift` + `AppDependencyContainerTests.swift` |

## Review Workload Forecast

- Decision needed before apply: No
- Chained PRs recommended: No
- 400-line budget risk: Low (2 new files ~230 lines + 2 one-line DI edits)

## Follow-up (next issue)

- Rewire `MovimientoEntradaViewModel.save()` create path to consume `RegisterMovementUseCase`
  (replacing its inline `Movimiento.entrada` + runner block), removing the duplicated logic.
