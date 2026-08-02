# Exploration: 41-use-case-tests — Edge-case coverage for entry use cases

**Issue**: #41 — `test(domain): tests de use cases de entrada`.
Port Android (`CryptoTrackerKotlin`) coverage patterns for the 3 entry-movement use
cases and close edge-case gaps. Acceptance: same coverage as Android (>90% lines on
the 3 use case files), PreviewContainer in-memory test storage.

## Current State

The 3 use cases shipped in #37–#39 with baseline suites (15 tests total, all green):

| Suite | Tests | Covers |
|---|---|---|
| `RegisterMovementUseCaseTests` | 5 | entry fields + holding, accumulation, FIAT-alternate fields, `updatedAt == fecha`, rollback atomicity |
| `EditMovementUseCaseTests` | 6 | quantity, price, wallet change, crypto change, negative revert, unsupported type |
| `DeleteMovementUseCaseTests` | 4 | simple delete, partially-spent holding, negative revert rejected, non-entry rejected |

All suites: Swift Testing, `@MainActor`, `TestSetup.createModelContext()` (in-memory
container — same schema list and `isStoredInMemoryOnly: true` as `PreviewContainer`),
`@testable import Crypto_Tracker`, real `ModelContextTransactionRunner` +
`HoldingService`.

### Android reference (CryptoTrackerKotlin)

Android tests use in-memory fakes (`FakeMovementRepo`/`FakeHoldingRepo`) + `FakeTx`,
and cover the same 3 happy/error paths already ported. The iOS port additionally
exercises real SwiftData persistence + transaction rollback (stronger than the fake
repos). The Android coverage adds nothing the iOS suites lack for the main paths;
the **gap is edge cases**, listed in the task.

### Key domain behaviors relevant to the new edge cases (verified by reading code)

1. **Register with `cantidadCrypto = 0`** — `Movimiento.entrada` persists the 0-qty
   movement; `HoldingService.apply` computes delta `+0` → no row created (new row
   only when `delta > 0`), existing row untouched but `updatedAt` re-stamped.
2. **Max/large values** — `valorTotalUSD = cantidadCrypto * precioUSD` is `Decimal`;
   values up to ~1e12×1e12 (≈1e24) are safe (Decimal max ≈1.8e38). No overflow guard
   in the domain → large values must round-trip through movement + holding unchanged.
3. **Missing cartera** — `RegisterMovementInput.cartera`/`crypto` are **non-optional**
   (compile-time enforced), so "missing" means a **legacy wallet without portfolio**:
   `HoldingService.apply` skips the holding write, movement still persists. Same path
   as `RegisterMovementUseCase.fetchHolding` returning nil (no `updatedAt` stamp).
4. **Edit no-op (same values)** — snapshot `previous` == new deltas → revert then
   re-apply nets zero; holding unchanged.
5. **Edit under concurrent modification** — the `EditMovementInput` contract says
   `movement` MUST hold pre-edit values (snapshot = old state). If the entity is
   mutated externally before `execute`, the snapshot captures the already-mutated
   quantity → `validateRevert` sees `holding - previous.cantidadCrypto < 0` and
   throws `.insufficientHoldings` before any mutation (fail-fast, atomic).
6. **Delete already-deleted movement** — after `context.delete`, the holding row is
   gone → second delete's `validateRevert` resolves `current = 0` →
   `0 - cantidadCrypto < 0` → `.insufficientHoldings`; nothing further persists.
7. **Delete with zero holding** — entrada fully consumed by sales (holding row deleted
   at 0) → delete throws `.insufficientHoldings`, movement retained.
8. **Delete + re-register** — cross-use-case cycle: delete entrada (holding reverted),
   register the same entrada again via `RegisterMovementUseCase` → holding rebuilt.

## Affected Areas

- `Crypto TrackerTests/RegisterMovementUseCaseTests.swift` — add 3 edge-case tests.
- `Crypto TrackerTests/EditMovementUseCaseTests.swift` — add 3 edge-case tests.
- `Crypto TrackerTests/DeleteMovementUseCaseTests.swift` — add 3 edge-case tests.
- `openspec/changes/41-use-case-tests/` — NEW: `exploration.md`, `tasks.md`.
- No production code, no DI, no `.pbxproj` edits (test files already registered).

## Approaches

1. **Extend the existing 3 suites (chosen)** — add `@Test` methods to the current
   files, reusing their helpers (`makeContext`, `holding`, `seedEntrada`, …).
   - Pros: zero new files; helpers already encapsulate schema/context setup;
     consistent with the #37–#39 pattern; smallest diff.
   - Cons: files grow (~60–90 new lines each) but stay under the 400-line review budget.
   - Effort: Low
2. **New `Domain/UseCases/` test folder** (issue's "Archivos afectados" hint) — split
   edge cases into new suites.
   - Pros: matches the issue's folder sketch literally.
   - Cons: duplicates the helper setup; the issue text is a sketch, and the existing
     suites are the natural home (task item 3 says "Add missing edge case tests for
     the 3 use cases"). Rejected.
3. **Dedicated edge-case suite files per use case** — one file per use case for the
   new tests only.
   - Pros: clean separation happy-path vs edge.
   - Cons: two files per use case testing the same struct is noise; no reviewer value.
     Rejected.

## Recommendation

Approach 1. Extend the 3 existing suites with 3 edge-case tests each (9 new tests),
matching the task's explicit edge-case list. Storage stays in-memory via
`TestSetup.createModelContext()` — identical semantics to `PreviewContainer`
(issue's "PreviewContainer in-memory" criterion) with **per-test container
isolation**, which `PreviewContainer.shared.container` cannot provide (its singleton
store would leak saved rows across tests and break `fetchCount` assertions).

## Risks

- **Concurrent-modification and already-deleted behaviors** are inferred from the
  domain code; each new test will be run and its assertion adjusted to the actual
  (correct) invariant behavior before finalizing.
- **20 pre-existing baseline failures** in 6 unrelated suites (CargaCatalogos,
  CargaMovimientos, CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras,
  MovimientoSalida) — this change adds tests only; must add 0 new failures.
- **Coverage measurement** requires `-enableCodeCoverage YES` + parsing the
  `.xccovreport` for the 3 use case files; target >90% lines.
- **400-line budget risk**: Low (~250–300 added lines total, tests only).

## Ready for Proposal

Yes — scope is fully determined. Apply = edit 3 test files (9 new `@Test`s), verify
focused suites + coverage, write `tasks.md`, save Engram
`sdd/41-use-case-tests/apply-progress`.
