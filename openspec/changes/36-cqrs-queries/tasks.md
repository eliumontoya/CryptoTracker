# Tasks: 36-cqrs-queries

Issue #36 — feat(domain): implementar queries de lectura (CQRS-lite)

## Explore

- [x] E1. Read calculator files (`MainPortfolioCalculator`, `PortfolioCalculatorService`, `PortfolioCryptoCalculator`) in current branch and in branch #34 (unified Movimiento) — movement-summing algorithms, KPI semantics (USD-only per spec `portfolio-calculation`)
- [x] E2. Read `Holding` entity (branch #33): compound unique id `portfolioId|cartera|cryptoId`, relationships to `Portfolio`/`Cartera`/`Crypto`, `cantidad` (clamped >= 0), `updatedAt`
- [x] E3. Read unified `Movimiento` entity (branch #34): `tipoRaw` + `tipo`, `groupId`, union of fields (entrada/salida/transferencia/swap), 8 `TipoMovimiento` cases
- [x] E4. Merge dependency branches `feat/33-holding-entity` and `feat/34-unified-movement` into `feat/36-cqrs`; resolve schema conflicts (register both `Holding` + `Movimiento` in app/preview/test containers, keep deprecated entities for migration)
- [x] E5. Persist `exploration.md`

## Implement

- [x] I1. Create `Domain/Queries/PortfolioQueries.swift` (auto-registered by PBXFileSystemSynchronizedRootGroup) with 4 read queries using `FetchDescriptor`/`#Predicate`:
  - `portfolioSummary(portfolioId:)` → `PortfolioSummary` (invertidoUSD, valorActualUSD, totalVentasUSD, gananciaUSD, rendimientoPct)
  - `portfolioByCryptos(portfolioId:)` → `[CryptoAggregate]` (qty from materialized `Holding`, avgCostUSD, adquiridoUSD, ventasUSD, valorActualUSD, pnlUSD, pnlPct)
  - `holdingsByWallet(walletId:)` → `WalletHoldings` (rows + wallet totals)
  - `movementsByWallet(walletId:assetId:)` → `[Movimiento]` (optionally filtered by asset)
- [x] I2. Add read model structs in the same file: `PortfolioSummary`, `CryptoAggregate`, `WalletHoldings` (+ `WalletHoldingRow`)
- [x] I3. Cost basis helper `costoPorCrypto(movimientos:)` — single aggregation pass: adquirido (entradas + swapEntrada USD), ventas (salidas + swapSalida USD); transfers/ajustes/comisiones excluded (no capital change)
- [x] I4. `defaultPortfolio(in:)` + `carteras(portfolioId:in:)` query helpers (portfolio is the active-entity scoping from #32)
- [x] I5. Rewrite `MainPortfolioCalculator` → query-backed `calcularResumen(portfolioId:in:)` + `calcularDistribucionGanancias(portfolioId:in:)`
- [x] I6. Rewrite `PortfolioCalculatorService` → query-backed `calcularDetallesCartera(_:in:)` + `calcularDetallesPortfolio(portfolioId:in:)` (keeps per-crypto movement breakdown from `movementsByWallet`)
- [x] I7. Rewrite `PortfolioCryptoCalculator` → query-backed `calcularResumenPorCrypto(portfolioId:in:)`
- [x] I8. Update `PortfolioDetalleViewModel` / `PortfolioPorCryptosViewModel` → `actualizarPortfolio()` resolves default portfolio, calls query-backed calculators; remove unreachable `do/catch` (non-throwing now)
- [x] I9. Update views (`PortfolioView`, `PortfolioDetalleView`, `PortfolioPorCryptosView`) — drop `@Query carteras/cryptos` where unused, drop dead `import SwiftData`, keep refresh triggers

## Fix compilation

- [x] F1. `xcodebuild build` (macOS Debug) → **BUILD SUCCEEDED**, no new warnings
- [x] F2. `xcodebuild build-for-testing` → **TEST BUILD SUCCEEDED**

## Verify

- [x] V1. `xcodebuild test` → 20 failures, all pre-existing baseline suites (#34 baseline identical: CargaCatalogos, CargaMovimientos, CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras, MovimientoSalida + flaky `testOnCantidadCryptoChange`) — **0 new regressions**
- [x] V2. Persist apply progress to Engram `sdd/36-cqrs-queries/apply-progress` (project `cryptotracker`)
