# Tasks: 32-portfolio-entity

Issue #32 — feat(domain): agregar entidad Portfolio + Wallet.isMain

## Explore

- [x] E1. Investigate current schema (Model.swift, all entities) and container registration points
- [x] E2. Evaluate migration strategy (no VersionedSchema infra exists → lightweight + launch bootstrap)
- [x] E3. Persist `exploration.md`

## Implement

- [x] I1. Add `Portfolio` @Model (id, nombre, descripcion, isDefault, `carteras` relationship)
- [x] I2. Add `Cartera.isMain: Bool = false` + `Cartera.portfolio: Portfolio?` relationship
- [x] I3. Extend `Cartera.init` with defaulted `isMain`/`portfolio` params (keeps all ~20 call sites compiling)
- [x] I4. Bump app schema version `2.0.0 → 3.0.0` and register `Portfolio` in `Crypto_TrackerApp.swift`
- [x] I5. Add `Model/PortfolioMigration.swift` — idempotent v2→v3 data migration (orphan carteras → "Portafolio Principal" default)
- [x] I6. Call `PortfolioMigration.apply` in `CryptoTrackerApp.init` after container creation
- [x] I7. Register `Portfolio` in `PreviewContainer` schema; seed default portfolio + link preview carteras (Binance isMain)
- [x] I8. Register `Portfolio` in `TestHelpers.createModelContext` and `CargaMovimientosTests` schema

## Fix compilation

- [x] F1. Verify app target builds with no new errors
- [x] F2. Fix pre-existing Swift 6 actor-isolation errors in `CargaMovimientosTests` (`@MainActor` on test class) so the test target compiles
- [x] F3. Verify test target builds (`TEST BUILD SUCCEEDED`)

## Verify

- [x] V1. Run full test suite; compare failures vs. pristine branch baseline (identical 47 pre-existing failures, 0 new)
- [x] V2. Persist apply progress to Engram `sdd/32-portfolio-entity/apply-progress` (project `cryptotracker`)
