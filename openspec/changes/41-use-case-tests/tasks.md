# Tasks: 41-use-case-tests — Edge-case tests for entry use cases

**Issue #41**: `test(domain): tests de use cases de entrada` — port Android
(`CryptoTrackerKotlin`) coverage patterns for the 3 entry-movement use cases and add
edge-case tests. Acceptance: >90% coverage on the 3 use case files, in-memory test
storage, 0 new baseline failures.

## Phase 1: Exploration

- [x] 1.1 Locate existing suites — `Crypto TrackerTests/` root: `RegisterMovementUseCaseTests.swift`
      (5 tests), `EditMovementUseCaseTests.swift` (6 tests), `DeleteMovementUseCaseTests.swift`
      (4 tests). All Swift Testing, `@MainActor`, `TestSetup.createModelContext()`, real
      `ModelContextTransactionRunner` + `HoldingService`.
- [x] 1.2 Baseline verified — `xcodebuild build-for-testing` EXIT 0; focused 3 suites 15/15 green.
- [x] 1.3 Android reference reviewed — cloned `CryptoTrackerKotlin`; its
      `Register/Edit/DeleteMovementUseCaseTest.kt` cover the same main paths already ported;
      the gap is edge cases (0-qty, max values, legacy wallet, edit no-op, concurrent
      modification, large decimals, already-deleted, zero holding, delete+re-register).
- [x] 1.4 Domain behaviors traced — 0-qty delta → no holding row; legacy wallet → holding
      skipped, movement persists; edit snapshot contract (`movement` must hold pre-edit
      values) → external mutation surfaces as `.insufficientHoldings`; delete after delete
      / zero holding → `.insufficientHoldings` (current = 0).
- [x] 1.5 In-memory storage decision — keep `TestSetup.createModelContext()`: same schema +
      `isStoredInMemoryOnly: true` as `PreviewContainer` (issue's "PreviewContainer
      in-memory" criterion) but per-test container isolation (`PreviewContainer.shared`
      would leak saved rows across tests and break `fetchCount` assertions).

## Phase 2: Implementation

- [x] 2.1 **`Crypto TrackerTests/RegisterMovementUseCaseTests.swift`** — added 4 `@Test`s:
      (a) FIAT alterno con `cantidadCrypto = 0` → movement persisted, no holding row
      created; (b) 0-qty register over an existing holding → quantity unchanged,
      `updatedAt` stamped with movement fecha; (c) max values (~1e12 qty × ~1e12 price,
      total ~1e24) → movement + holding round-trip exactly; (d) legacy cartera sin
      portfolio → movement persists, no holding row. Suite: 5 → 9 tests.
- [x] 2.2 **`Crypto TrackerTests/EditMovementUseCaseTests.swift`** — added 5 `@Test`s:
      (a) edit to identical values (no-op) → revert + re-apply nets zero; (b) edit under
      concurrent modification (entity mutated before `execute`) → `.insufficientHoldings`,
      holding untouched, use case mutation never applied; (c) large decimal quantity
      (~1e12) → holding + movement updated exactly; (d) legacy cartera sin portfolio →
      validation skipped, edit persists without holding; (e) `errorDescription` getter
      coverage. Suite: 6 → 11 tests.
- [x] 2.3 **`Crypto TrackerTests/DeleteMovementUseCaseTests.swift`** — added 5 `@Test`s:
      (a) delete already-deleted movement → second delete throws `.insufficientHoldings`,
      store consistent; (b) delete with zero holding (entry consumed by sales) →
      `.insufficientHoldings`, movement retained; (c) delete + re-register via
      `RegisterMovementUseCase` → holding rebuilt, cycle consistent; (d) legacy cartera
      sin portfolio → delete persists without holding; (e) `errorDescription` getter
      coverage. Suite: 4 → 9 tests.

## Phase 3: Verification

- [x] 3.1 `xcodebuild build-for-testing` — EXIT 0 (pre-existing warnings only).
- [x] 3.2 Focused suites — Register 9 + Edit 11 + Delete 9 = **29/29 green**, verified
      repeatedly (multiple consecutive runs, all green in every result bundle).
- [x] 3.3 Coverage — `xcodebuild test -enableCodeCoverage YES` (focused) →
      RegisterMovementUseCase **100%** (46/46), EditMovementUseCase **100%** (67/67),
      DeleteMovementUseCase **97.96%** (48/49). All >90% target. The single uncovered
      line in Delete is `holdingRow`'s nil-cartera/crypto early-return, unreachable
      through the entry flow (input enforces non-nil cartera+crypto).
- [x] 3.4 Regression — `HoldingServiceTests` 8/8 + `TransactionRunnerTests` 3/3 +
      `AppDependencyContainerTests` 9/9 = 20/20 green. Full serial suite: 150 passed /
      21 failed (20 = documented pre-existing baseline in 6 suites + 1 intermittent
      parallel-runner signal-trap flake that also hits original baseline tests —
      environmental, not a regression; focused bundles always report all 29 green).

## Work Unit Evidence

| Evidence | Required value |
|---|---|
| Focused test command and exact result | `xcodebuild test-without-building -only-testing:"Crypto TrackerTests/RegisterMovementUseCaseTests" -only-testing:"Crypto TrackerTests/EditMovementUseCaseTests" -only-testing:"Crypto TrackerTests/DeleteMovementUseCaseTests"` → 29/29 passed in every result bundle (multiple runs; occasional spurious `TEST EXECUTE FAILED` banner from the parallel runner, bundle always 29/0) |
| Coverage command and exact result | `xcodebuild test -enableCodeCoverage YES -only-testing:...` → Register 100% (46/46), Edit 100% (67/67), Delete 97.96% (48/49) from `.xccovreport` |
| Rollback boundary | Revert the 3 test files to `4d8fc28` state (additions only, no production code); delete `openspec/changes/41-use-case-tests/` |

## Notes

- **In-memory storage**: kept `TestSetup.createModelContext()` — identical schema +
  `isStoredInMemoryOnly: true` to `PreviewContainer` (issue's "PreviewContainer
  in-memory" criterion) with per-test container isolation, which
  `PreviewContainer.shared.container` cannot provide (singleton store would leak
  saved rows across tests and break `fetchCount` assertions).
- **Concurrent-modification test finding**: SwiftData's `rollback()` does NOT revert a
  caller's direct property mutation made outside the use case's transaction; the use
  case's own mutation is never applied and the holding stays untouched. Assertions
  encode the real contract: `.insufficientHoldings` + untouched holding + untouched
  use-case fields.
- **Parallel-runner flake**: on this machine (macOS 26.6 / Xcode 26.6), full-suite
  runs intermittently crash workers with signal trap — the crash also hits ORIGINAL
  baseline tests (e.g., `registerAccumulatesIntoExistingHolding`), confirming it is
  environmental, not caused by this change.

## Review Workload Forecast

- Decision needed before apply: No
- Chained PRs recommended: No
- 400-line budget risk: Low (281 added lines, tests only)
