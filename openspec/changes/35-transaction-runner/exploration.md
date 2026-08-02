# Exploration: TransactionRunner — atomicity for movement ↔ holding updates

**Issue**: #35 — `feat(domain): implementar atomicidad movimiento ↔ holding (TransactionRunner)`.
Guarantee that movement + holding updates persist atomically via a `TransactionRunner` protocol wrapping `ModelContext.save()`.

## Current State

All SwiftData persistence flows call `modelContext.save()` directly at the end of a mutation:

- **Services** — `CargaMovimientosEntradaService` (line 41), `CargaMovimientosSalidaService` (45), `CargaMovimientosEntreCarterasService` (42), `CargaMovimientosSwapService` (39): each `insert`s parsed movements in a loop, then a single `try modelContext.save()`.
- **ViewModels** — `MovimientoSalidaViewModel.save()/delete()` (lines 156/175), `MovimientoEntreCarterasViewModel` (137/156), `MovimientoSwapViewModel` (147/166): each builds/updates a movement and calls `modelContext.save()`.

There is NO shared transaction abstraction. `ModelContext.save()` itself is already atomic (all pending changes persist in one transaction), but the "execute → save → propagate error" choreography is duplicated in every site, and nothing formalizes the movement ↔ holding invariant (both must persist together or neither).

## Affected Areas

- `Crypto Tracker/Services/Domain/TransactionRunner.swift` — **NEW** file (folder `Services/Domain/` does not exist yet; create it). Protocol + `ModelContextTransactionRunner` implementation. Xcode 16+ `PBXFileSystemSynchronizedRootGroup` auto-registers new files — no pbxproj edit needed.
- `Crypto Tracker/Views/Admin/CryptoSyncView.swift` — **pre-existing build break**: stray `}` at line 10 (top-level, line 60). Same bug already fixed on branches #33/#34, never merged to main. Blocks ALL builds including this change's verification; needs a 1-line drive-by fix.
- Future consumers (NOT in scope for this change): the 4 `CargaMovimientos*` services and the 3 movement ViewModels will be rewired to `TransactionRunner` in follow-up work.

## Approaches

1. **Protocol + `ModelContextTransactionRunner` struct (issue-mandated)** — `protocol TransactionRunner { func run<T>(_ block: (ModelContext) throws -> T) async throws -> T }`; a struct holding the `ModelContext` executes the block, calls `save()` on success, rethrows on failure.
   - Pros: exactly the issue contract; wraps SwiftData's native atomic `save()`; injectable into ViewModels/services per existing DI conventions; trivially testable with in-memory context (`TestSetup.createModelContext()`).
   - Cons: none material — `ModelContext` is not `Sendable`, so the `async` signature + struct requires care (Swift 5 mode in this project, no strict-concurrency enforcement).
   - Effort: Low

2. **Protocol + `final class` implementation** — same protocol, class instead of struct.
   - Pros: matches the `class` style of the existing `CargaMovimientos*` services.
   - Cons: unnecessary reference semantics for a stateless wrapper; struct is the Swift-idiomatic default.
   - Effort: Low

3. **Also rewire existing services/ViewModels now** — replace their inline `try modelContext.save()` calls with the runner.
   - Pros: immediate adoption of the abstraction.
   - Cons: expands the diff well beyond issue scope; risky to touch 4 services + 3 ViewModels in one change; better as a follow-up once the runner is proven.
   - Effort: Medium — deferred.

## Recommendation

Approach 1. Create `Crypto Tracker/Services/Domain/TransactionRunner.swift` with the protocol exactly as specified in the issue, plus `struct ModelContextTransactionRunner: TransactionRunner` that:

1. Runs the block with the injected `ModelContext`.
2. On success, persists with `try modelContext.save()` and returns the block's result.
3. On any thrown error (block or save), propagates the error — nothing is persisted, honoring SwiftData's atomic save semantics.

Rollback consideration: `modelContext.rollback()` IS required. A failing block leaves pending inserts registered in the context; without rollback, a subsequent `save()` (from another run) would persist the partial write (e.g., movement without its holding update), violating the atomicity guarantee. `run` therefore calls `rollback()` in the catch path before rethrowing — proven by `TransactionRunnerTests.runRollsBackBlockWhenBlockThrows` (fails without rollback, passes with it).

## Risks

- **Pre-existing build break**: `CryptoSyncView.swift` stray `}` blocks verification. Must be fixed (drive-by, 1 line) or no build can be proven. Flag it in the apply report.
- **Concurrency**: `ModelContext` is non-`Sendable`; the protocol is `async`. Project is Swift 5 mode, so no strict-concurrency diagnostics; keep the wrapper single-context-per-injection to avoid cross-context mutation.
- **No CLI test runner for full suite**: `xcodebuild` IS available (Xcode 26.6, shared scheme exists), so at minimum `xcodebuild build` + `build-for-testing` can be verified from CLI. Full test execution may be limited to Xcode IDE per project-context.md.
- **Branch base**: this branch (`feat/35-transaction-runner`) is based on `26fea14` (main). #33 (Holding) and #34 (unified Movimiento) are NOT merged — irrelevant here since `TransactionRunner` is generic over `ModelContext` and depends only on SwiftData.

## Ready for Proposal

Yes — scope is minimal and fully specified by the issue. Exploration confirms: single new file, protocol + struct, no pbxproj edits, no schema changes, one required pre-existing-fix drive-by.
