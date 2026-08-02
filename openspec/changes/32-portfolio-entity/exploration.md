# Exploration: Portfolio entity + Wallet.isMain

## Current State

- All SwiftData entities live in `Model/Model.swift` (`FIAT`, `Crypto`, `PrecioHistorico`,
  `Cartera`, `MovimientoIngreso`, `MovimientoEgreso`, `MovimientoEntreCarteras`,
  `MovimientoSwap`) plus `CryptoSyncConfig` in `Model/CryptoSyncConfigModel.swift`.
- The app schema is a single `Schema([...])` with `version: .init(2, 0, 0)` in
  `App/Crypto_TrackerApp.swift`. There is **no** `VersionedSchema` /
  `SchemaMigrationPlan` infrastructure in the codebase — migrations so far have been
  lightweight-only.
- Containers are registered in three places:
  - `App/Crypto_TrackerApp.swift` — persistent, versioned schema `2.0.0`
  - `Model/PreviewContainer.swift` — in-memory preview schema (no version)
  - `Crypto TrackerTests/Mocks/TestHelpers.swift` — in-memory test schema
- `Cartera` has `init(nombre:simbolo:)` used in ~20 call sites (previews, view models,
  tests, mocks). Its `id`/`nombre`/`simbolo` follow the same pattern as other entities
  (`@Attribute(.unique)`, validated maxLength).
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new files are
  automatically added to targets — no `.pbxproj` edits needed.
- Views reference "portfolio" conceptually (`PortfolioView`, `PortfolioDetalleView`,
  `PortfolioCalculator`) but there is no persisted `Portfolio` model — today the app is
  a single implicit portfolio of all carteras.

## Affected Areas

- `Crypto Tracker/Model/Model.swift` — add `Portfolio` @Model; add `isMain` +
  `portfolio` relationship to `Cartera`; update `Cartera.init`.
- `Crypto Tracker/App/Crypto_TrackerApp.swift` — register `Portfolio` in schema, bump
  version to `3.0.0`, run migration bootstrap.
- `Crypto Tracker/Model/PreviewContainer.swift` — register `Portfolio`, seed default
  portfolio and link preview carteras.
- `Crypto TrackerTests/Mocks/TestHelpers.swift` — register `Portfolio` in test schema.
- `Crypto Tracker/Model/` (new file, e.g. `PortfolioMigration.swift`) — idempotent data
  migration: orphan carteras → default "Portafolio Principal" portfolio.
- Test schemas that list entities explicitly (`AdminCarterasViewModelTests`,
  `MovimientoSalidaParserTests`, etc.) may need `Portfolio` registered only if SwiftData
  does not auto-infer related models — to be verified at build time.
- `Crypto TrackerTests/Mocks/EntityMocks.swift` — optional: extend `Cartera.mock()` for
  `isMain`/`portfolio` convenience (not strictly required).

## Approaches

1. **Lightweight migration + idempotent launch bootstrap** — bump schema version to
   `3.0.0`; all schema changes are additive (new entity, new optional relationship, new
   Bool with default), which SwiftData migrates automatically. Orphan-wallet → default
   portfolio assignment runs as an idempotent data fix at app/container startup.
   - Pros: minimal code, no VersionedSchema boilerplate, safe for existing users
   - Cons: data fix runs at launch rather than inside a `MigrationStage`; needs to be
     idempotent
   - Effort: Low

2. **Full `VersionedSchema` + `SchemaMigrationPlan`** — create `SchemaV2`/`SchemaV3`
   versioned schemas and a migration plan with a custom `MigrationStage` that creates
   the default portfolio and reassigns orphans during migration.
   - Pros: canonical SwiftData migration path; data fix guaranteed to run once during
     migration
   - Cons: high boilerplate (duplicate every entity for v2/v3), larger diff, more
     surface for errors; not justified while the codebase has no VersionedSchema
     infrastructure yet
   - Effort: High

3. **Minimal (schema only, no data fix)** — add entity/fields and bump version, skip
   orphan reassignment.
   - Pros: smallest change
   - Cons: violates issue requirement #3 (orphan wallets → default portfolio)
   - Effort: Low

## Recommendation

**Approach 1** — lightweight additive migration + idempotent `PortfolioMigration`
bootstrap invoked from `CryptoTrackerApp.init` (and available for Preview/TestSetup).
It matches the existing codebase style (no VersionedSchema infra), keeps the diff small,
and satisfies all four issue requirements. The bootstrap only creates the default
portfolio and links orphans when needed, so it is safe to run on every launch.

## Risks

- SwiftData may require explicitly registering `Portfolio` in every test schema that
  includes `Cartera` if related-model inference does not apply — mitigated by adding
  `Portfolio.self` to the three main containers and verifying the full test target
  builds.
- Non-optional `isMain: Bool` added to an existing entity can fail lightweight migration
  if SwiftData can't derive a default — mitigated by declaring `isMain: Bool = false`
  with an explicit default so migration has a value for existing rows.
- `Cartera.init` signature change breaks ~20 call sites — mitigated by giving `isMain`
  and `portfolio` default values (`false` / `nil`), so existing call sites compile
  unchanged.
- The launch bootstrap mutates data on the main context before the app UI starts —
  mitigated by keeping it synchronous, idempotent, and run before `AppDependencyContainer`
  is constructed.

## Ready for Proposal

Yes — scope is well defined by issue #32; proceed with implementation via Approach 1.
