# Tasks: Transfer edit/delete use cases + ViewModel DI (issue #48 extended)

**Issue**: #48 — `feat(domain): transfer edit/delete use cases`.
Extend the domain movement use cases so wallet transfers (`transferenciaSalida` /
`transferenciaEntrada`) can be edited and deleted atomically with their materialized
holdings, and wire `MovimientoEntreCarterasViewModel` through protocol DI instead of
orchestrating `TransactionRunner` + `HoldingService` inline.

## Phase 1: Extend `EditMovementUseCase` for transfers

- [x] 1.1 Add `EditTransferMovementValues` and `EditTransferMovementInput` to
      `EditMovementUseCase.swift`. The input carries the `.transferenciaSalida` leg;
      the use case locates the paired `.transferenciaEntrada` by `groupId`.
- [x] 1.2 Add `execute(_ input: EditTransferMovementInput)` to
      `EditMovementUseCaseProtocol`.
- [x] 1.3 Implement validation: project the balance for every affected
      `(portfolio, cartera, crypto)` key after reverting the old pair and applying
      the new pair; reject the edit if any key would go negative.
- [x] 1.4 Apply the updated values to both legs, keeping the existing `precioUSD` (the
      transfer form does not expose a price field).
- [x] 1.5 Call `holdingService.updateHoldingForMovement(_:previous:)` for both legs
      inside a single `transactionRunner.run` block.

## Phase 2: Extend `DeleteMovementUseCase` for transfers

- [x] 2.1 Accept `.transferenciaEntrada` and `.transferenciaSalida` as valid types.
- [x] 2.2 Locate the paired leg by `groupId` and validate that reverting the entrada
      (`destination holding - cantidadCryptoEntrada`) stays non-negative.
- [x] 2.3 Revert holdings and delete both legs atomically in one transaction.
- [x] 2.4 Preserve the existing single-leg `.entrada` / `.salida` delete behaviour.

## Phase 3: Create `MoveBetweenWalletsUseCase` wiring

- [x] 3.1 `MoveBetweenWalletsUseCase` already exists from issue #47. No changes required.

## Phase 4: Rewire `MovimientoEntreCarterasViewModel`

- [x] 4.1 Replace `transactionRunner` + `holdingService` properties with
      `moveBetweenWalletsUseCase`, `editUseCase`, `deleteUseCase` (protocol types).
- [x] 4.2 Update `init` to accept optional use-case parameters with defaults built from
      a fresh `ModelContextTransactionRunner` + `HoldingService`, keeping tests
      compiling.
- [x] 4.3 `save()` create path calls `moveBetweenWalletsUseCase.execute(...)` using
      `crypto.precio` as `precioUSD`.
- [x] 4.4 `save()` edit path calls `editUseCase.execute(EditTransferMovementInput(...))`.
- [x] 4.5 `delete()` calls `deleteUseCase.delete(movimiento)`.
- [x] 4.6 Keep `formIsValid`, `cryptoDisponible`, `adjustCantidades`, `setupBindings`
      and loading logic unchanged. Remove unused `piernaEntrada(_:)` helper.
- [x] 4.7 Fix `setMaxCantidadSalida()` to also set `cantidadCryptoEntrada` to the max.

## Phase 5: Update `AppDependencyContainer`

- [x] 5.1 Inject the shared `moveBetweenWalletsUseCase`, `editMovementUseCase`, and
      `deleteMovementUseCase` into `makeMovimientoEntreCarterasViewModel`.
- [x] 5.2 Add DI assertions in `AppDependencyContainerTests` for the transfer
      use case and ViewModel factory.

## Phase 6: Tests

- [x] 6.1 Extend `EditMovementUseCaseTests` with transfer-edit scenarios:
      edit quantities, change destination wallet, invalid insufficient origin funds,
      invalid destination spent too much.
- [x] 6.2 Extend `DeleteMovementUseCaseTests` with transfer-delete scenarios:
      delete both legs from salida, delete both legs from entrada, reject when
      destination holding spent too much. Update unsupported-type test to use
      `.ajuste`.
- [x] 6.3 Update `MovimientoEntreCarterasViewModelTests` to seed a portfolio and
      initial holding, create transfers through `MoveBetweenWalletsUseCase` before
      deletion, and refetch wallets in `setUp` so `BalanceCalculator` inverse
      relationships resolve.

## Phase 7: Build & commit

- [x] 7.1 `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` passes.
- [x] 7.2 Build-for-testing passes.
- [x] 7.3 Focused test suites pass (Edit/Delete/MoveBetweenWallets/AppDependency/MovimientoEntreCarteras).
- [x] 7.4 Commit with a message mentioning the extended scope.

## Notes

- `MovimientoEntreCarterasViewModel.movimiento` is always the `.transferenciaSalida`
  leg; the paired `.transferenciaEntrada` is resolved by `groupId`.
- The transfer form does not expose a price field, so `precioUSD` is sourced from
  `crypto.precio` on creation and preserved on edit.
- All mutations are expected to run inside a single `TransactionRunner` block.
- Full suite still has pre-existing SwiftData concurrency failures/crashes in
  unrelated suites (CargaCatalogos, CargaMovimientos, EliminarData,
  MovimientoEntrada/Salida, Register/Delete edge cases) that reproduce on baseline.
