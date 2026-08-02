# Exploration: DeleteMovementUseCase (entrada)

**Issue**: #39 — `feat(domain): DeleteMovementUseCase (entrada)`.
Physically delete an entry movement and revert its holding, validating the
holding never goes negative after the revert, atomically (movement + holding in
one transaction).

## Current State

Deletes today are orchestrated inline in the ViewModels, not in the domain layer:

- `MovimientoSalidaViewModel.delete()` (lines 182–201), `MovimientoSwapViewModel.delete()`
  (201–225), `MovimientoEntreCarterasViewModel.delete()` (~192) and
  `MovimientosEntradaViewModel` / `MovimientosEntradaListViewModel`: each runs
  `transactionRunner.run { holdingService.deleteHoldingForMovement(...); context.delete(...) }`.
  The choreography is duplicated per site and **no delete path validates** that
  reverting the movement keeps the materialized `Holding` non-negative.

The domain primitives already exist and are wired (#35 + fix-35, commit `1a9059e`):

- `TransactionRunner` / `ModelContextTransactionRunner` — atomic `save()` + `rollback()` on error.
- `HoldingServiceProtocol` — `deleteHoldingForMovement(_:in:)` inverts the
  movement's delta on the materialized `Holding` row; `snapshot(of:)` captures
  pre-mutation state for the edit path.
- `Holding` entity — compound key `Holding.makeId(portfolio:cartera:crypto:)`;
  `cantidad` clamps at 0 via `didSet`, so a negative revert must be **pre-validated**
  (otherwise the service silently deletes the row instead of surfacing the violation).
- `PortfolioQueries.defaultPortfolio(in:)` — used by `HoldingService.apply` to
  resolve the portfolio for legacy wallets.

Precedents: issues #37 (`RegisterMovementUseCase`) and #38 (`EditMovementUseCase`)
created the sibling use cases under `Domain/UseCases/Movements/` with protocol +
struct + error enum, `TransactionRunner` + `HoldingServiceProtocol` injected, DI
wiring in `AppDependencyContainer`, and Swift Testing suites. Their branches exist
but are empty (worktrees deleted); the pattern is preserved in Engram
(`sdd/37-register-use-case/apply-progress`, `sdd/38-edit-use-case/apply-progress`).

## Affected Areas

- `Crypto Tracker/Domain/UseCases/Movements/DeleteMovementUseCase.swift` — **NEW**
  (folder `Domain/UseCases/Movements/` does not exist yet; create it). Contains
  `DeleteMovementError`, `DeleteMovementUseCaseProtocol`, `DeleteMovementUseCase`.
  Xcode 16+ `PBXFileSystemSynchronizedRootGroup` auto-registers the file — no pbxproj edit.
- `Crypto TrackerTests/DeleteMovementUseCaseTests.swift` — **NEW** Swift Testing suite.
- `Crypto Tracker/App/AppDependencyContainer.swift` — expose `deleteMovementUseCase`
  (property + init, 2 lines).
- `Crypto TrackerTests/AppDependencyContainerTests.swift` — 1 assertion line.
- Future consumer (NOT in scope): rewiring the 4 ViewModel delete paths to the use
  case, as follow-up work once the use case is proven (same deferral as #37/#38).

## Approaches

1. **Dedicated use case, entrada-only, pre-validate revert (chosen)** —
   `DeleteMovementUseCase` with `transactionRunner` + `holdingService` injected.
   `delete(_:)` runs one `transactionRunner.run` block: (a) `validateRevert` —
   for `.entrada` throws `.insufficientHoldings` when `holding.cantidad - cantidadCrypto < 0`,
   throws `.unsupportedMovementType` for any other `tipo` (revert formula differs,
   mirrors #38); (b) `holdingService.deleteHoldingForMovement`; (c) `context.delete`.
   Holding lookup mirrors `HoldingService.apply` (portfolio via `cartera.portfolio ?? defaultPortfolio`).
   - Pros: matches the #37/#38 sibling pattern exactly; validation lives in the
     domain layer where the invariant is testable; atomic via runner rollback
     (proven by `TransactionRunnerTests`); scope honest to the "(entrada)" issue.
   - Cons: other movement types still delete via the ViewModel inline paths until a
     follow-up generalizes the use case.
   - Effort: Low

2. **General-purpose delete for all tipos** — compute the revert rule per type
   (salida adds, transferencia/swap touch two rows, ajuste is absolute).
   - Pros: single delete entry point for every type now.
   - Cons: `ajuste` revert semantics are ambiguous (absolute delta), and the issue
     explicitly scopes to entrada; expanding scope without a requirement risks
     wrong business rules. Better as a dedicated follow-up.
   - Effort: Medium

3. **Add the guard inside `HoldingService` instead of the use case** — make
   `deleteHoldingForMovement` itself throw on negative revert.
   - Pros: single validation point for every caller.
   - Cons: changes shared-service behavior used by ViewModels that today rely on
     the silent clamp-to-zero; a service-layer invariant would also fire for the
     edit path's `previous` revert where the rule differs. Scope creep beyond #39.
   - Effort: Low-Medium

## Recommendation

Approach 1. Create `Crypto Tracker/Domain/UseCases/Movements/DeleteMovementUseCase.swift`
following the #37/#38 template (protocol + struct + error enum in one file), with:

1. `protocol DeleteMovementUseCaseProtocol { func delete(_ movement: Movimiento) async throws }`.
2. `struct DeleteMovementUseCase` holding `transactionRunner` + `holdingService`
   (constructor-injected, matching the container's DI convention).
3. `delete(_:)` = one `transactionRunner.run` block: validate → revert → delete.
4. Validation: entrada-only (`unsupportedMovementType` otherwise); for `.entrada`,
   current holding (resolved like `HoldingService.apply`, missing row ⇒ 0) must
   cover `cantidadCrypto`, else `.insufficientHoldings` — thrown BEFORE any mutation
   so the runner rollback keeps movement + holding intact.
5. Error strings in Spanish (UI-facing), doc comments in English (domain layer).

Tests (Swift Testing, `@MainActor`, `TestSetup.createModelContext()`):
- delete simple entry → holding row gone (0), movement removed;
- delete when holding partially spent → holding stays positive, other movements intact;
- delete that would make holding negative → `.insufficientHoldings`, nothing persists;
- delete non-entry movement → `.unsupportedMovementType`, nothing changes.

DI: expose `deleteMovementUseCase: DeleteMovementUseCaseProtocol` in
`AppDependencyContainer` + assert in `AppDependencyContainerTests`.

## Risks

- **Semantics of "negative"**: `Holding.cantidad` clamps at 0 via `didSet`, so the
  service would silently erase the row on a negative revert. The use case must
  pre-validate to turn that silent behavior into an explicit domain error. Covered
  by the negative-revert test.
- **Legacy wallets without portfolio**: `HoldingService.apply` skips writes when no
  portfolio resolves; validation mirrors that guard so legacy deletes are not
  blocked by a phantom negative check.
- **Sibling branches are empty**: #37/#38 implementations exist only in Engram
  (worktrees deleted). Pattern re-derived from memory + current code; no merge
  conflicts expected since this branch bases on `1a9059e` (main).
- **CLI verification available**: `xcode-select` → `/Applications/Xcode.app`,
  shared scheme `Crypto Tracker`; verified via `xcodebuild build` / `build-for-testing` /
  `test-without-building`. Full-suite baseline has 20 pre-existing failures
  (6 baseline suites) unrelated to this change.

## Ready for Proposal

Yes — scope is minimal and fully specified by the issue. Exploration confirms:
one new domain file + one new test file + 2-line DI wiring + 1 DI test line +
2 openspec artifacts; no pbxproj edits, no schema changes.
