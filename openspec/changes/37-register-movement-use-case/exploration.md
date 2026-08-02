# Exploration: RegisterMovementUseCase (entrada)

## Current State

Entry movements (`tipo = .entrada`) are created in
`Crypto Tracker/Movimientos/MovimientosEntradaViewModel.swift`, `save()` create path
(lines 160–178): the ViewModel builds `Movimiento.entrada(...)` and runs it atomically via

```swift
try await transactionRunner.run { context in
    context.insert(nuevoMovimiento)
    try holdingService.updateHoldingForMovement(nuevoMovimiento, in: context)
}
```

**Key finding — the issue text is stale**: `MovimientosEntradaService.swift` (and
`MovimientosEntradaServiceProtocol`) was **deleted** in change `fix-35-wire-transaction-runner`
(commit `1a9059e`). The service layer was replaced by two domain primitives wired directly
into the movement ViewModels:

- `TransactionRunner` / `ModelContextTransactionRunner`
  (`Crypto Tracker/Services/Domain/TransactionRunner.swift`) — atomic persistence: runs a
  block on the `ModelContext`, calls `save()` only on success, `rollback()` on error.
- `HoldingServiceProtocol` / `HoldingService`
  (`Crypto Tracker/Services/Domain/HoldingService.swift`) — delta-based materialized `Holding`
  updates keyed by `Holding.makeId(portfolio:cartera:crypto:)`; `.entrada` applies
  `+cantidadCrypto` on the cartera+crypto row; never calls `save()` itself (the runner owns
  persistence).

The domain layer already exists at `Crypto Tracker/Domain/Queries/PortfolioQueries.swift`
(CQRS-lite read layer). There is **no `Domain/UseCases/` folder yet** — this change creates it,
consistent with `AGENTS.md` ("ViewModels usan use cases con protocolos inyectables").

`Movimiento.entrada(...)` factory (`Model.swift` lines 367–391) already satisfies the entry
business rules: `tipo = .entrada`, `valorTotalUSD = cantidadCrypto * precioUSD`, optional
`precioFiatAlterno` / `valorTotalFiatAlterno` / `fiatAlterno`. The FIAT-alternate path flows
through `precioUSD` (VM's `calcularPrecioUSD()` converts FIAT → USD first), so the factory's
derivation reproduces the FIAT-derived total exactly.

**Gap vs. issue rules**: the issue requires `holding.updatedAt = movimiento.fecha`. The current
`HoldingService` sets `updatedAt = Date()` (wall clock). The use case must stamp the holding
row with the movement's `fecha` after the holding delta is applied.

## Affected Areas

- `Crypto Tracker/Domain/UseCases/Movements/RegisterMovementUseCase.swift` — **new**; protocol +
  implementation (this change's deliverable).
- `Crypto Tracker/App/AppDependencyContainer.swift` — expose `registerMovementUseCase` so the
  composition root owns it (AGENTS.md DI rule).
- `Crypto TrackerTests/RegisterMovementUseCaseTests.swift` — **new**; Swift Testing suites
  matching `HoldingServiceTests` / `TransactionRunnerTests` patterns.
- `Crypto TrackerTests/AppDependencyContainerTests.swift` — assert the new service (1 line).
- Not touched: `MovimientoEntradaViewModel.save()` (works correctly today; rewiring to the use
  case is a follow-up), `HoldingService` (its `updatedAt = Date()` behavior is intentionally
  preserved for the other 6 movement types).

## Approaches

1. **Pure use case, no wiring** — create only the protocol + implementation file.
   - Pros: smallest diff; exactly the literal task.
   - Cons: dead code per AGENTS.md ("si no se usa, se borra"); nothing exercises it.
   - Effort: Low

2. **Use case + DI container exposure + tests (recommended)** — create the use case, expose it
   from `AppDependencyContainer` (the composition root), and add Swift Testing suites that prove
   the business rules + atomicity through the real `ModelContextTransactionRunner`.
   - Pros: no dead code; container is the natural home for the next issue (VM rewiring);
     atomicity is proven at the use-case boundary with a throwing `HoldingServiceProtocol` fake;
     ~80 lines, low risk.
   - Cons: `MovimientoEntradaViewModel` still does its own inline version until a follow-up issue
     rewires it (documented as next step, not a defect).
   - Effort: Low

3. **Use case + rewire `MovimientoEntradaViewModel.save()`** — full adoption now.
   - Pros: single source of truth for entry registration immediately.
   - Cons: broader change (VM refactor + its 184-line test suite updated); issue #37 scope is
     "create the use case", not "adopt it"; the VM already works. Better as a dedicated follow-up.
   - Effort: Medium

## Recommendation

Approach 2. Deliver the `RegisterMovementUseCase` (protocol + struct) taking
`TransactionRunner` + `HoldingServiceProtocol` via init (replacing the stale
"MovimientosEntradaServiceProtocol" in the issue — that protocol no longer exists), enforce
`holding.updatedAt = movimiento.fecha` inside the transaction, expose it from
`AppDependencyContainer`, and prove it with Swift Testing (entry fields, FIAT-alternate fields,
updatedAt stamping, and rollback atomicity via a throwing holding-service fake). Rewiring the
ViewModel is the recommended next issue.

## Risks

- **Stale issue reference**: `MovimientosEntradaServiceProtocol` does not exist; implementation
  uses `TransactionRunner` + `HoldingServiceProtocol` (the actual primitives). Documented as a
  deviation, not an error.
- **`updatedAt` semantics**: stamping `Holding.updatedAt` with a backdated `movimiento.fecha`
  makes the row look "old" — this is the issue's explicit business rule, so it wins; noted for
  the next issue that adopts the use case in the VM.
- **Pre-existing test baseline**: 20 failures in 6 suites (CargaCatalogos, CargaMovimientos,
  CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras, MovimientoSalida) — verified
  in `fix-35` as pre-existing. This change must add 0 new failures.
- **New folder**: `Domain/UseCases/Movements/` is a new tree; Xcode picks it up automatically
  (project uses `PBXFileSystemSynchronizedRootGroup`), no `.pbxproj` edit needed.

## Ready for Proposal

Yes. Create `RegisterMovementUseCase` per Approach 2, wire it in `AppDependencyContainer`, add
Swift Testing suites, verify with `xcodebuild` (build + focused suites must stay green, 0 new
failures).
