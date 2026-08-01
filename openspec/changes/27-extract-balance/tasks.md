# Tasks — 27-extract-balance: extraer cálculo de balance a un solo lugar

## Explore

- [x] 1.1 Read all 4 source files with duplicated balance logic
- [x] 1.2 Read all callers of `getCryptoDisponible`, `calcularBalanceCrypto`, `calcularDetallesCartera`, `calcularResumenPorCrypto`
- [x] 1.3 Confirm all implementations are mathematically identical (they are)
- [x] 1.4 Confirm `PortfolioCryptoCalculator` already delegates to `getCryptoDisponible` (no change needed)
- [x] 1.5 Confirm `MainPortfolioCalculator` is NOT a 5th duplicate (USD aggregation, different concern)
- [x] 1.6 Write `exploration.md`

## Apply

- [x] 2.1 Create `Crypto Tracker/Model/BalanceCalculator.swift` with the unified algorithm
      `balance(crypto:en:movimientoActual:)` = `ingresos + transferenciasRecibidas + swapsRecibidos + movimientoActual - (egresos + transferenciasEnviadas + swapsEnviados)`
- [x] 2.2 Refactor `Model/CarteraExtension.swift` — `getCryptoDisponible` delegates to `BalanceCalculator` (signature preserved, all 8 callers unaffected)
- [x] 2.3 Refactor `ViewModels/Admin/AdminCarterasViewModel.swift` — call `BalanceCalculator.balance` directly in `calcularValorTotalUSD`; delete dead private `calcularBalanceCrypto`
- [x] 2.4 Refactor `Model/PortfolioCalculatorService.swift` — replace inline `balanceActual` computation; keep `guard balanceActual != 0` filter
- [x] 2.5 Confirm `Model/PortfolioCryptoCalculator.swift` needs no change (delegates via `getCryptoDisponible`)
- [x] 2.6 Verify no inline duplicate of the formula remains (rg: only `BalanceCalculator.swift` matches)

## Verify

- [x] 3.1 `xcodebuild build` — **BUILD SUCCEEDED**, no errors, no new warnings
- [x] 3.2 `xcodebuild test` — failure set identical before/after refactor (43 pre-existing environment failures, 0 new)
- [x] 3.3 Confirmed the test-target compile errors (`CargaMovimientosTests.swift` actor isolation) are pre-existing via git-stash baseline comparison
- [x] 3.4 Confirmed balance-related tests (`testCryptoDisponible`, `testComision`) fail identically on baseline

## Delivery forecast

- 400-line budget risk: **Low** (3 insertions / 58 deletions in source + 1 new file + docs)
- Chained PRs recommended: **No**
- Decision needed before apply: **No**

## Notes

- Issue referenced file as `Model/PortfolioCalculatorService .swift` (space); actual path is `Model/PortfolioCalculatorService.swift` (no space).
- Design decision: object-based API (`crypto:en:`) instead of the issue's `(cryptoId: UUID, carteraId: UUID)` sketch — all callers hold live model objects; a UUID API would require a ModelContext dependency and change every caller. The six domain terms from the issue formula are preserved verbatim.
