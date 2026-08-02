# Exploration: EditMovementUseCase (entrada)

**Issue**: #38 — `feat(domain): EditMovementUseCase (entrada)`.
Edit an existing entry movement and adjust the associated holding atomically.

## Current State

Movement + holding updates are already atomic via `TransactionRunner` + `HoldingService`:

- `Crypto Tracker/Services/Domain/TransactionRunner.swift` — `protocol TransactionRunner { func run<T>(_ block: (ModelContext) throws -> T) async throws -> T }` + `struct ModelContextTransactionRunner` (save on success, `rollback()` + rethrow on failure).
- `Crypto Tracker/Services/Domain/HoldingService.swift` — `HoldingServiceProtocol` already has the **edit path**: `updateHoldingForMovement(_ movement:, previous: HoldingSnapshot, in context:)` reverts the previous effect (`apply(oldDeltas.map { $0.inverted() })`) then applies the new one; `snapshot(of:)` captures a movement's holding-affecting fields (`HoldingSnapshot`) before mutation.
- The edit flow is currently implemented **inline in the ViewModel**: `MovimientoEntradaViewModel.save()` (edit branch) snapshots the movement, mutates the entity inside `transactionRunner.run`, then calls `holdingService.updateHoldingForMovement(existingMovimiento, previous: previous, in: context)`.
- `Movimiento` (unified entity, `Model.swift`): entry movements are `TipoMovimiento.entrada` with `cantidadCrypto`, `precioUSD`, `valorTotalUSD`, optional fiat-alternate fields, `cartera`, `crypto`, `fiatAlterno`.
- `Holding` has a compound key `portfolioId|carteraId|cryptoId` (`Holding.makeId`) and clamps `cantidad` to ≥ 0 via `didSet` — so a negative revert would be silently clamped unless validated explicitly.
- Domain layer folders exist only for Queries (`Domain/Queries/PortfolioQueries.swift`); `Domain/UseCases/Movements/` is the target location per `ARCHITECTURE.md`.
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` for `Crypto Tracker/` and `Crypto TrackerTests/` — new files auto-register, no `project.pbxproj` edit needed.
- Tests use Swift Testing (`@Test` / `#expect`), in-memory context via `TestSetup.createModelContext()`, and `@testable import Crypto_Tracker` (`HoldingServiceTests.swift` is the closest template).

## Affected Areas

- `Crypto Tracker/Domain/UseCases/Movements/EditMovementUseCase.swift` — **NEW**: `EditMovementInput`, `EditMovementValues`, `EditMovementError`, `EditMovementUseCaseProtocol`, `EditMovementUseCase`.
- `Crypto TrackerTests/EditMovementUseCaseTests.swift` — **NEW**: 6 tests (quantity, price, wallet change, crypto change, negative revert, unsupported type).
- `Crypto Tracker/App/AppDependencyContainer.swift` — wire `editMovementUseCase` using existing `transactionRunner` + `holdingService`.
- `Crypto TrackerTests/AppDependencyContainerTests.swift` — add one `XCTAssertNotNil` for the new use case.
- `openspec/changes/38-edit-movement-use-case/` — **NEW**: `exploration.md`, `tasks.md`.

## Approaches

1. **Domain use case wrapping the existing snapshot-based edit path (chosen)** — `EditMovementInput { movement, updated: EditMovementValues }`; the use case captures the **old** state via `holdingService.snapshot(of: movement)` before mutation, validates the revert cannot drive the old holding below zero, then runs `transactionRunner.run { mutate entity; updateHoldingForMovement(movement, previous:) }`.
   - Pros: single source of truth for "old" (the persisted entity — no drift between passed-in old values and reality); reuses the proven `HoldingServiceProtocol` edit contract; matches the issue's own instruction to follow existing patterns; atomicity and rollback come free from `TransactionRunner`.
   - Cons: the input does not carry explicit `old.*` fields (the issue's loose wording "old + new values"); the caller must call `execute` before mutating the entity (documented contract).
   - Effort: Low

2. **Input carries explicit `previous` + `updated` value structs** — use case reverts based on `input.previous` instead of the entity snapshot.
   - Pros: literal reading of the issue wording; decoupled from entity state.
   - Cons: two sources of truth for "old" (input vs. entity) → drift risk corrupts the revert math; `HoldingServiceProtocol` only builds `HoldingSnapshot` from a `Movimiento` entity, so a parallel snapshot API would be needed; dead/duplicated data if the entity is the real source — violates the repo's "no dead code" rule.
   - Effort: Medium — rejected.

3. **Reuse the inline ViewModel logic and only extract a thin service** — no domain use case; keep logic in `MovimientoEntradaViewModel`.
   - Pros: zero new abstraction.
   - Cons: contradicts `ARCHITECTURE.md` (use cases are the domain layer for movement+holding operations) and the issue's explicit deliverable.
   - Effort: Low — rejected.

## Recommendation

Approach 1. Create `Domain/UseCases/Movements/EditMovementUseCase.swift`:

- `EditMovementValues` — value payload with the editable entrada fields (fecha, cantidadCrypto, precioUSD, valorTotalUSD, fiat-alternate fields, crypto, cartera, fiatAlterno).
- `EditMovementInput` — `let movement: Movimiento` (still holding pre-edit values at call time) + `let updated: EditMovementValues`.
- `EditMovementUseCaseProtocol` — `func execute(_ input: EditMovementInput) async throws`.
- `EditMovementUseCase` — `transactionRunner` + `holdingService`; `execute` snapshots the entity, then inside `transactionRunner.run`: (1) validates the revert — for `.entrada`, the old holding `cantidad - previous.cantidadCrypto` must be ≥ 0, else `EditMovementError.insufficientHoldings` (this replaces the silent `Holding.cantidad` clamp with an explicit domain error); (2) applies the new values to the entity; (3) `updateHoldingForMovement(movement, previous:)` reverts old + applies new, which also covers the "crypto or wallet changed" case (old deltas target the old cartera/crypto, new deltas target the new ones).
- `EditMovementError` — `insufficientHoldings`, `unsupportedMovementType` (the use case is entrada-only; the revert formula `cantidad - old.cantidadCrypto` only holds for `.entrada`). User-facing descriptions in Spanish to match the app's existing movement errors.

A non-entrada movement passed to the use case throws `unsupportedMovementType` before any mutation.

## Risks

- **Caller contract**: `movement` must still hold pre-edit values when `execute` is called (snapshot = old state). Documented on `EditMovementInput`.
- **Validation is entrada-specific**: `.salida`/`.ajuste` revert math differs (negative delta / absolute delta). Guarded by `unsupportedMovementType`.
- **Legacy wallets without portfolio**: no materialized holding row exists, so validation skips — matches `HoldingService.apply` behavior (no holding write for those).
- **Full suite has pre-existing failures** (20 across 6 baseline suites per #35 verification); verification will target the new tests + `HoldingServiceTests` + `TransactionRunnerTests` to prove no domain-layer regression.

## Ready for Proposal

Yes — scope is fully determined by the issue and the existing `HoldingServiceProtocol` + `TransactionRunner` contracts. Exploration confirms: 2 new Swift files (auto-registered), 2 small edits (DI container + its test), no pbxproj/schema changes, no migration.
