# Exploration: 33-holding-entity

Issue #33 — feat(domain): agregar entidad Holding (balance materializado)

## Current State

The app persists movements-only domain entities in `Crypto Tracker/Model/Model.swift`
(FIAT, Crypto, PrecioHistorico, Portfolio, Cartera, MovimientoIngreso, MovimientoEgreso,
MovimientoEntreCarteras, MovimientoSwap) plus `CryptoSyncConfig` in
`Model/CryptoSyncConfigModel.swift`. Balances are computed on-the-fly in 4+ places
(CryptoDetail, CarteraDetail, PortfolioCalculatorService, MainPortfolioCalculator) —
exactly the duplication Issue #33 removes.

Schema is registered in four places with explicit entity lists and a version:

1. `Crypto Tracker/App/Crypto_TrackerApp.swift` — app schema, `version: .init(3, 0, 0)` after #32 merged
2. `Crypto Tracker/Model/PreviewContainer.swift` — in-memory preview schema
3. `Crypto TrackerTests/Mocks/TestHelpers.swift` — `TestSetup.createModelContext()` test schema
4. `Crypto TrackerTests/CargaMovimientosTests.swift` — full test schema

Plus scoped test schemas in the parser test files (no Portfolio/Holding needed there).

## Dependency Resolution

Issue #33's model spec requires `var portfolio: Portfolio`. That dependency (Issue #32,
`feat(domain): agregar entidad Portfolio + Wallet.isMain`) has been **merged to main**
as commit `26fea14` (PR #90): `Portfolio` @Model exists, `Cartera.isMain` +
`Cartera.portfolio` relationship exist, app schema is v3, and the idempotent
`PortfolioMigration` backfills orphan carteras. The Holding change now applies cleanly
on top of main with no merge gymnastics.

## Affected Areas

- `Crypto Tracker/Model/Model.swift` — add `Holding` @Model (compound unique id, relationships, `cantidad >= 0` invariant)
- `Crypto Tracker/App/Crypto_TrackerApp.swift` — register `Holding` in schema, bump version `3.0.0 → 4.0.0`
- `Crypto Tracker/Model/PreviewContainer.swift` — register `Holding`, seed preview holdings
- `Crypto TrackerTests/Mocks/TestHelpers.swift` — register `Holding` in test schema
- `Crypto TrackerTests/CargaMovimientosTests.swift` — register `Holding` in full test schema
- `openspec/changes/33-holding-entity/tasks.md` — apply progress
- (Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new files auto-sync, no pbxproj edits)

## Approaches

1. **Add Holding directly on main (dependency already merged)** — implement per issue spec.
   - Pros: Compiles; matches issue spec exactly (`var portfolio: Portfolio`); no branch juggling; schema bump v3→v4 is the only version change.
   - Cons: None material.
   - Effort: Low

2. **Defer until a VersionedSchema migration exists** — build proper `SchemaV4` migration plan first.
   - Cons: No VersionedSchema infra exists in the project; SwiftData lightweight migration handles additive entities fine; over-engineering for a new entity.
   - Effort: Medium (unnecessary)

## Recommendation

Approach 1: add `Holding` exactly per the issue spec with the `cantidad >= 0` invariant
(`didSet` clamp pattern, consistent with existing `validated(maxLength:)` didSet style),
register it in all 4 schema sites, and bump the app schema version to `4.0.0`.
No new data migration file is needed — the entity is additive (SwiftData lightweight
migration); `PortfolioMigration` stays idempotent for the cartera backfill.

## Risks

- Pre-existing on main: `CryptoSyncView.swift` had an extraneous `}` at line 10
  (from PR #87) that broke the app build — CLI builds were not being run, so it slipped
  through. Fixed as a one-line drive-by so the target compiles; surfaced for review.
- `cantidad >= 0` invariant must guard the didSet path, not just init, since SwiftData
  mutations go through the property setter.
- `updatedAt` intentionally NOT auto-touched in `didSet`: SwiftData materialization can
  fire observers on load, which would overwrite the persisted timestamp.

## Ready for Proposal

Yes — proceed to apply. Add Holding per spec with invariant, register in all containers,
bump schema to 4.0.0, verify build.
