# Tasks: 33-holding-entity

Issue #33 — feat(domain): agregar entidad Holding (balance materializado)

## Explore

- [x] E1. Read `Model.swift` — understand current entities and schema registration sites
- [x] E2. Verify the `Portfolio` dependency (Issue #32) — merged to main as `26fea14` (PR #90), schema v3
- [x] E3. Evaluate migration strategy (additive entity → lightweight migration, no VersionedSchema infra)
- [x] E4. Persist `exploration.md`

## Implement

- [x] I1. Add `Holding` @Model in `Model.swift`: compound unique id `portfolioId|carteraId|cryptoId` (String, `@Attribute(.unique)`), relationships to `Portfolio`, `Cartera`, `Crypto`, `cantidad: Decimal`, `updatedAt: Date`
- [x] I2. Enforce `cantidad >= 0` invariant: `max(cantidad, 0)` in init + `didSet` clamp (consistent with existing validated-didSet pattern)
- [x] I3. Static `Holding.makeId(portfolio:cartera:crypto:)` composes the compound key from the three relationship UUIDs
- [x] I4. Register `Holding` in app schema `Crypto_TrackerApp.swift` and bump version `3.0.0 → 4.0.0`
- [x] I5. Register `Holding` in `PreviewContainer` schema; seed 3 preview holdings (BTC/Binance, ETH/MetaMask, SOL/Phantom)
- [x] I6. Register `Holding` in `TestHelpers.createModelContext` and `CargaMovimientosTests` schemas

## Fix compilation

- [x] F1. Fix pre-existing broken build on main: `CryptoSyncView.swift:10` extraneous `}` (introduced by PR #87) — one-line drive-by so the app target compiles
- [x] F2. `xcodebuild build` (macOS Debug) → **BUILD SUCCEEDED**
- [x] F3. `xcodebuild build-for-testing` → **TEST BUILD SUCCEEDED**

## Verify

- [x] V1. Confirm no new warnings/errors from the Holding entity (schema v4 loads in-memory containers)
- [x] V2. Persist apply progress to Engram `sdd/33-holding-entity/apply-progress` (project `cryptotracker`)
- [x] V3. Full test suite from Xcode CLI: **0 new failures vs. base**. Control: base (main + CryptoSyncView fix only) = 20 failures; this branch = 19 failures (testOnCantidadCryptoChange is flaky, passed on re-run). All 4 CargaMovimientosTests failures pre-exist on main.
