# Tasks: EditMovementUseCase (entrada)

**Issue**: #38 — `feat(domain): EditMovementUseCase (entrada)`.
Edit an existing entry movement and adjust the associated holding: revert the previous effect, apply the new one, validate the holding never goes below zero during the revert, and support wallet/crypto changes — all atomically via `TransactionRunner`.

## Phase 1: Use Case

- [x] 1.1 **`Crypto Tracker/Domain/UseCases/Movements/EditMovementUseCase.swift`** — Create the use case file (folder `Domain/UseCases/Movements/` is new):
  - `EditMovementValues` — value payload with the editable entrada fields (fecha, cantidadCrypto, precioUSD, valorTotalUSD, fiat-alternate fields, crypto, cartera, fiatAlterno).
  - `EditMovementInput` — `movement: Movimiento` (must still hold pre-edit values at call time) + `updated: EditMovementValues`. Old values come from `HoldingServiceProtocol.snapshot(of:)` (single source of truth — matches the existing `MovimientoEntradaViewModel.save` edit path), not from duplicated input fields.
  - `EditMovementError` — `.insufficientHoldings` (revert would drive holding below zero) and `.unsupportedMovementType` (entrada-only use case), with Spanish user-facing descriptions.
  - `EditMovementUseCaseProtocol` — `func execute(_ input: EditMovementInput) async throws`.
  - `EditMovementUseCase` — `transactionRunner` + `holdingService`; `execute` snapshots the entity, then inside `transactionRunner.run`: validates the revert (old holding `cantidad - previous.cantidadCrypto >= 0`), applies the new values, and calls `updateHoldingForMovement(movement, previous:)` (reverts old + applies new — handles wallet/crypto changes).

## Phase 2: Tests

- [x] 2.1 **`Crypto TrackerTests/EditMovementUseCaseTests.swift`** — Swift Testing suite (`@Test` / `#expect`, in-memory `TestSetup.createModelContext()`, real `HoldingService` math — no hardcoded mocks), 6 tests:
  1. `editQuantityAdjustsHoldingAndMovement` — 2 → 5 BTC: holding 2 → 5, `valorTotalUSD` recomputed.
  2. `editPriceUpdatesMovementWithoutTouchingHolding` — price 50k → 60k: movement fields updated, holding unchanged.
  3. `changeWalletMovesHoldingToNewWallet` — old wallet holding reverted (row deleted at zero), new wallet holding created.
  4. `changeCryptoMovesHoldingToNewCrypto` — BTC holding reverted, ETH holding created.
  5. `revertBelowZeroThrowsAndPersistsNothing` — 5 in / 3 out → holding 2; edit to 8 throws `.insufficientHoldings`, nothing persisted (movement + holding unchanged).
  6. `nonEntradaMovementThrowsUnsupportedType` — salida movement rejected with `.unsupportedMovementType`.

## Phase 3: DI Wiring

- [x] 3.1 **`Crypto Tracker/App/AppDependencyContainer.swift`** — Add `let editMovementUseCase: EditMovementUseCaseProtocol` and instantiate with the existing `transactionRunner` + `holdingService`.
- [x] 3.2 **`Crypto TrackerTests/AppDependencyContainerTests.swift`** — Add `testEditMovementUseCaseIsWired` (`XCTAssertNotNil(dependencies.editMovementUseCase)`).

## Phase 4: Verification

- [x] 4.1 **macOS build compiles** — `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` → `** BUILD SUCCEEDED **` (only pre-existing NavigationLink deprecation warnings).
- [x] 4.2 **Focused tests pass** — `EditMovementUseCaseTests` 6/6 green; regressions green: `HoldingServiceTests` 8/8, `TransactionRunnerTests` 3/3, `AppDependencyContainerTests` 9/9 (incl. new DI test).

## Notes

- `Domain/UseCases/Movements/` and `Crypto TrackerTests/` files auto-register via Xcode 16+ `PBXFileSystemSynchronizedRootGroup` — no `project.pbxproj` edit.
- **Design decision**: the input does NOT carry explicit `old.*` fields. The old state is captured from the persisted entity via `holdingService.snapshot(of:)` before mutation — the same contract as the existing `MovimientoEntradaViewModel.save()` edit path and `HoldingServiceProtocol.updateHoldingForMovement(_:previous:)`. Carrying old values in the input was rejected: two sources of truth for "old" invites drift that corrupts the revert math (see `exploration.md` → Approaches).
- **Negative-balance guard rationale**: `Holding.cantidad` clamps at zero via `didSet`, so a negative revert would silently corrupt the balance (e.g. after later sales consumed the entry's holdings). The use case fails fast with `.insufficientHoldings` inside the transaction — the runner rolls back, so nothing persists.
- Full suite has known pre-existing failures (20 across 6 baseline suites, per #35); verification was scoped to the domain layer + DI to prove no regression.
