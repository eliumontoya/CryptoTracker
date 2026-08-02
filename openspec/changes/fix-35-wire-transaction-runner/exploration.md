# Exploration: fix-35-wire-transaction-runner — Wire TransactionRunner + HoldingService into movement save/delete

**Bug**: Dashboard shows zeros. The `Holding` materialized table stays empty because
`TransactionRunner` (#35) exists but is not wired into any movement write path. The CQRS
read layer (`PortfolioQueries`, #36) reads balances exclusively from `Holding`, so with an
empty table every KPI (`invertidoUSD`, `valorActualUSD`, `gananciaUSD`) computes to zero.

## Current State

- `TransactionRunner` + `ModelContextTransactionRunner` exist in
  `Services/Domain/TransactionRunner.swift` and are used ONLY by `TransactionRunnerTests` (3/3 green).
- The 4 movement ViewModels persist with direct `modelContext.save()` and never touch `Holding`:
  - `MovimientosEntradaViewModel` → `MovimientosEntradaService.insert/save/delete`
  - `MovimientoSalidaViewModel`, `MovimientoEntreCarterasViewModel`, `MovimientoSwapViewModel`
    → inline `modelContext.insert/delete` + `save()`
- `Holding` entity: unique compound key `portfolioId|carteraId|cryptoId` (`Holding.makeId`),
  `cantidad >= 0` invariant, relationship to `Portfolio` (non-optional).
- Read layer: `PortfolioQueries.portfolioSummary/portfolioByCryptos/holdingsByWallet` aggregate
  exclusively from `FetchDescriptor<Holding>`; cost basis comes from a single pass over movements.
- Edit path hazard: the existing-movement branch mutates the `Movimiento` in place, so the
  Holding update needs the movement's PREVIOUS effect to revert it (snapshot) or it double-counts.
- Transferencia/swap are stored as TWO legs sharing a `groupId`; each leg hits a different
  holding row (origen decremented, destino incremented).

## Affected Areas

- `Crypto Tracker/Services/Domain/HoldingService.swift` — **NEW**: protocol + struct applying
  signed deltas to the materialized `Holding` rows; `HoldingSnapshot` for the edit revert path.
- `Crypto Tracker/Movimientos/MovimientosEntradaViewModel.swift` — replace service-based writes
  with `TransactionRunner` + `HoldingService`; init gains `modelContext` + optional runner/service.
- `Crypto Tracker/ViewModels/Movimientos/{MovimientoSalida,MovimientoEntreCarteras,MovimientoSwap}ViewModel.swift`
  — wrap save()/delete() in `transactionRunner.run` + holding updates (optional params keep tests compiling).
- `Crypto Tracker/Movimientos/lib/MovimientosEntradaListViewModel.swift` — list swipe-delete also
  reverts holdings (adds `modelContext`).
- `Crypto Tracker/ViewModels/Portfolio/xCryptos/PortfolioCryptosViewModel.swift` — drop now-unused
  `movimientoService`.
- `Crypto Tracker/App/AppDependencyContainer.swift` — expose `transactionRunner` + `holdingService`,
  rewire Entrada VM factories.
- `Crypto Tracker/Movimientos/MovimientosEntradaService.swift` — becomes fully dead (all three
  consumers rewired) → delete per AGENTS.md "no dead code".
- Tests: `MovimientoEntradaViewModelTests` rewritten to a real context (its mock service contract
  disappears); new `HoldingServiceTests` proving holdings write/revert/edit for all 4 movement types.
- Xcode `PBXFileSystemSynchronizedRootGroup` auto-registers new files — no pbxproj edit.

## Approaches

1. **Delta-based HoldingService + runner wiring (chosen)** — HoldingService computes signed
   deltas per movement type (entrada/salida/transferencia legs/swap legs/ajuste absolute/comision
   no-op), upserts/increments the row by compound key, deletes the row at `<= 0`. ViewModels run
   movement mutation + holding mutation inside `TransactionRunner.run` (single `save()`).
   - Pros: matches the issue-mandated `TransactionRunner` contract; rollback on failure
     (`modelContext.rollback()` in the runner) guarantees movement+holding atomicity; edit path
     handled via `HoldingSnapshot` (revert old, apply new); minimal blast radius.
   - Cons: `TransactionRunner.run` is `async` while the old Entrada service was sync — Entrada VM
     must drop the service (becomes dead code) and use the runner directly.
   - Effort: Medium

2. **Recompute holdings from movements after every write** — idempotent "rebuild" per wallet×crypto.
   - Pros: no snapshot/revert logic; naturally handles edits.
   - Cons: contradicts the task's requested method contract (`updateHoldingForMovement`,
     `deleteHoldingForMovement`); O(N) per write; loses the "apply delta" intent of #35.
   - Effort: Medium (rejected)

3. **Extend `MovimientosEntradaService` to own runner+service** — keep the Entrada VM on the service.
   - Pros: preserves the service seam.
   - Cons: service methods are sync `throws`; runner is `async throws` → signature mismatch; would
     leave the other 3 VMs inconsistent with Entrada. Rejected.

## Recommendation

Approach 1. New `Services/Domain/HoldingService.swift`:

1. `HoldingSnapshot` — captures holding-affecting fields (tipo + ids + amounts) before mutation.
2. `HoldingServiceProtocol` — `updateHoldingForMovement(_:in:)` (create), `updateHoldingForMovement(_:previous:in:)`
   (edit: revert previous + apply new), `deleteHoldingForMovement(_:in:)` (delete), `snapshot(of:)`.
3. `struct HoldingService` — computes signed deltas per `TipoMovimiento`; upserts by
   `Holding.makeId`; row deleted when qty `<= 0`; portfolio resolved from `cartera.portfolio`
   with `PortfolioQueries.defaultPortfolio` fallback (legacy wallets skip safely); never calls
   `save()` itself — the surrounding `TransactionRunner` owns persistence.
4. ViewModels (Entrada, Salida, EntreCarteras, Swap): create/edit/delete run inside
   `transactionRunner.run`; hold-update calls made for EVERY leg of transferencia/swap pairs.
5. `MovimientosEntradaListViewModel.deleteMovimientos` reverts holdings per movement.
6. Delete `MovimientosEntradaService.swift` (dead after rewiring).

## Risks

- **Existing tests construct VMs with `modelContext:` only** — mitigated with optional
  `transactionRunner`/`holdingService` params defaulting from the VM's context; mock carteras have
  no `portfolio`, so holdings are safely skipped in those tests (no assertion breakage).
- **Pre-existing baseline failures**: change #35 tasks.md records ~20 pre-existing failures in 6
  suites (incl. MovimientoSalida, MovimientoEntreCarteras); the new wiring must not add new ones.
- **Ajuste/comision semantics**: ajuste is out of scope (no ViewModel); treated as absolute-set.
  Comision is a no-op (fee already netted in transferencia amounts).
- **Concurrency**: project is Swift 5 mode; runner block executes synchronously on the caller
  actor. Keep one context per runner.

## Ready for Proposal

Yes — exploration complete, approach determined, blast radius mapped. Directly implementable.
