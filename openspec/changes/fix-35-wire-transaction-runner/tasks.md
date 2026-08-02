# Tasks: fix-35-wire-transaction-runner — Wire TransactionRunner + HoldingService into movement save/delete

**Bug**: Dashboard KPIs show zeros. `TransactionRunner` (#35) and the CQRS read layer (#36)
exist, but no movement write path updates the materialized `Holding` table, so
`PortfolioQueries` (which reads exclusively from `Holding`) computes empty results.

## Phase 1: HoldingService

- [x] 1.1 **`Crypto Tracker/Services/Domain/HoldingService.swift`** — Create `HoldingSnapshot`
      (pre-mutation snapshot of holding-affecting fields), `HoldingServiceProtocol`
      (`updateHoldingForMovement(_:in:)`, `updateHoldingForMovement(_:previous:in:)`,
      `deleteHoldingForMovement(_:in:)`, `snapshot(of:)`), and `struct HoldingService`.
- [x] 1.2 **Delta semantics** — entrada `+cantidad`, salida `-cantidad`, transferenciaSalida
      `-cantidadCryptoSalida` on origen, transferenciaEntrada `+cantidadCryptoEntrada` on destino,
      swapSalida `-cantidadOrigen` on cryptoOrigen, swapEntrada `+cantidadDestino` on cryptoDestino,
      ajuste = absolute set, comision = no-op (fee netted in transferencia amounts).
- [x] 1.3 **Upsert/delete rules** — row keyed by `Holding.makeId`; row deleted when qty `<= 0`;
      portfolio resolved from `cartera.portfolio` with `PortfolioQueries.defaultPortfolio` fallback;
      service never calls `save()` (the `TransactionRunner` owns persistence).

## Phase 2: Wiring (TransactionRunner + HoldingService)

- [x] 2.1 **`MovimientosEntradaViewModel`** — init gains `modelContext` + optional
      `transactionRunner`/`holdingService`; `save()` create/edit and `delete()` run inside
      `transactionRunner.run`; edit reverts via `previous:` snapshot; delete reverts holding first.
- [x] 2.2 **`MovimientoSalidaViewModel`** — same wiring for create/edit/delete.
- [x] 2.3 **`MovimientoEntreCarterasViewModel`** — save()/delete() handle BOTH legs
      (salida + entrada) holding effects inside one transaction.
- [x] 2.4 **`MovimientoSwapViewModel`** — same pair wiring for both legs.
- [x] 2.5 **`MovimientosEntradaListViewModel`** — `deleteMovimientos` reverts holdings per
      movement via runner; init now takes `modelContext`.
- [x] 2.6 **`AppDependencyContainer`** — exposes `transactionRunner` + `holdingService`;
      rewires Entrada VM factories and drops the dead `movimientosEntradaService`.
- [x] 2.7 **Remove dead code** — delete `MovimientosEntradaService.swift` (all 3 consumers
      rewired); drop `movimientoService` from `PortfolioPorCryptosViewModel`.

## Phase 3: Tests & Verification

- [x] 3.1 **`Crypto TrackerTests/HoldingServiceTests.swift`** — 8 `@Test` cases: entrada creates
      holding, salida decrements + row deleted at zero, delete reverts, transferencia pair moves
      qty between wallets (with commission), swap pair moves qty between cryptos, edit reverts
      previous + applies new, runner rollback leaves movement + holding unpersisted. All green.
- [x] 3.2 **`MovimientoEntradaViewModelTests`** — rewritten to a real in-memory context; save
      asserts holding written; new edit + delete tests prove holding update/revert.
- [x] 3.3 **`AppDependencyContainerTests`** — updated to assert the new transaction services.
- [x] 3.4 **Build + full suite** — `xcodebuild build` and `build-for-testing` succeed (only
      pre-existing warnings). Full suite: 120 passed / 20 failed — the 20 failures are exactly
      the pre-existing baseline in 6 suites (CargaCatalogos, CargaMovimientos,
      CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras, MovimientoSalida),
      verified identical against the pristine tree via `git stash`. 0 new failures.

## Review Workload Forecast

- Decision needed before apply: No
- Chained PRs recommended: No
- 400-line budget risk: Low (single focused change, ~1,000 lines incl. new tests)

## Verification Result

`xcodebuild build` ✅ | `build-for-testing` ✅ | focused suites (HoldingService, Entrada VM,
TransactionRunner, AppDependencyContainer) 38/38 ✅ | full suite 0 new failures vs baseline ✅
