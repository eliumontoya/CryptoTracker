# Tasks: DeleteMovementUseCase — entry delete with holding revert

**Issue**: #39 — `feat(domain): DeleteMovementUseCase (entrada)`.
Physically delete an entry movement and revert its holding, validating the
holding never goes negative after the revert, atomically (movement + holding in
one `TransactionRunner` block).

## Phase 1: Exploration

- [x] 1.1 **Explore delete patterns** — `HoldingServiceProtocol.deleteHoldingForMovement(_:in:)`
      exists (reverts a movement's delta on the materialized `Holding` row); the 4
      ViewModel `delete()` paths orchestrate it inline. Sibling use cases #37/#38
      (Register/Edit) define the `Domain/UseCases/Movements/` pattern (protocol +
      struct + error enum, `TransactionRunner` + `HoldingServiceProtocol` injected);
      their branches are empty (worktrees deleted) — pattern recovered from Engram.
- [x] 1.2 **Invariant understood** — `Holding.cantidad` clamps at 0 via `didSet`, so a
      negative revert would silently erase the row; the use case must pre-validate
      (`holding.cantidad - cantidadCrypto >= 0`) and throw before any mutation.

## Phase 2: Implementation

- [x] 2.1 **`Crypto Tracker/Domain/UseCases/Movements/DeleteMovementUseCase.swift`** —
      Created: `DeleteMovementError` (`.unsupportedMovementType(TipoMovimiento)`,
      `.insufficientHoldings`), `DeleteMovementUseCaseProtocol`, `struct
      DeleteMovementUseCase(transactionRunner:holdingService:)`. `delete(_:)` runs one
      `transactionRunner.run` block: validate → revert holding → `context.delete`.
      Validation: entrada-only (other tipos throw `.unsupportedMovementType`, mirrors
      #38); holding resolved like `HoldingService.apply` (`cartera.portfolio ?? 
      PortfolioQueries.defaultPortfolio`), missing row ⇒ 0, throws `.insufficientHoldings`
      when the revert would go negative. Legacy wallets without portfolio skip validation.
- [x] 2.2 **`Crypto TrackerTests/DeleteMovementUseCaseTests.swift`** — Created, Swift
      Testing, `@MainActor`, 4 tests: (a) delete simple entry → holding row gone +
      movement removed; (b) delete when holding partially spent (6+4 entrada, venta 4)
      → holding stays positive (2), other movements intact; (c) delete that would make
      holding negative (venta 7, delete entrada 6) → `.insufficientHoldings`, nothing
      persists (atomic); (d) delete non-entry movement → `.unsupportedMovementType`,
      nothing changes.
- [x] 2.3 **DI wiring** — `AppDependencyContainer.swift`: property
      `deleteMovementUseCase: DeleteMovementUseCaseProtocol` + init
      `DeleteMovementUseCase(transactionRunner:holdingService:)`.
- [x] 2.4 **DI test** — `AppDependencyContainerTests.swift`: 1 assertion line
      (`XCTAssertNotNil(dependencies.deleteMovementUseCase)`).

## Phase 3: Verification

- [x] 3.1 **macOS build compiles** — `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` → BUILD SUCCEEDED (exit 0; only pre-existing deprecation warnings).
- [x] 3.2 **Test target builds** — `xcodebuild build-for-testing` → SUCCEEDED (exit 0; 1 pre-existing warning in MovimientoSalidaViewModelTests).
- [x] 3.3 **Focused tests pass** — `test-without-building -only-testing:DeleteMovementUseCaseTests` → 4/4 passed (twice, both runs green).
- [x] 3.4 **No regressions (touched suites)** — `AppDependencyContainerTests` 7/7,
      `HoldingServiceTests` 8/8, `TransactionRunnerTests` 3/3 — all green.

## Notes

- ViewModel `delete()` paths NOT rewired (out of scope; issue asks to create the use
  case). Follow-up: rewire the 4 delete paths to consume `DeleteMovementUseCase`.
- No input struct: delete only needs the `Movimiento` (unlike #37/#38 which carried
  fields/values). Protocol is `delete(_ movement: Movimiento) async throws`.
- Xcode 26.6 shared scheme `Crypto Tracker` works from CLI;
  `PBXFileSystemSynchronizedRootGroup` auto-registered the 2 new files (no pbxproj edit).
- Full-suite baseline: 20 pre-existing failures in 6 suites (CargaCatalogos,
  CargaMovimientos, CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras,
  MovimientoSalida) — untouched by this change.
