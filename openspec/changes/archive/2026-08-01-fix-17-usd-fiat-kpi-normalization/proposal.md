# Proposal: Fix USD/FIAT KPI Normalization in Portfolio

## Intent

Three compounding bugs cause portfolio KPIs (investment, current value, gain, ROI) to produce incorrect values by mixing distinct FIAT currencies with USD in the same arithmetic operations.

**Why now**: Every portfolio summary KPI displayed to the user is mathematically wrong when any movement uses `usaFiatAlterno`. Rendimiento and ganancia percentages are unreliable for users with EUR/MXN transactions.

## Scope

### In Scope
- Remove `totalInvertidoFIAT`, `valorActualFIAT` from `CryptoDetail`; compute gain/ROI in USD only
- Remove FIAT-based computed properties from `CarteraDetail`; replace with USD equivalents
- Fix `MainPortfolioCalculator` line using `totalInvertidoFIAT` as `totalInvertidoUSD`
- Fix `PortfolioCalculatorService` — drop FIAT conversion block, compute `ganancia` as `valorUSD - totalInvertidoUSD`
- Update `CarteraHeaderView` to format using USD properties only
- Update unit tests referencing removed FIAT properties

### Out of Scope
- Removing `valorTotalFiatAlterno` from `MovimientoIngreso`/`MovimientoEgreso` SwiftData models (data migration risk; models are still useful for entry forms)
- Changing the entry form FIAT-as-alternate-currency input UX
- Renaming `totalInvertidoUSD` → `totalInvestedUSD` or other English normalization

## Capabilities

### New Capabilities
None

### Modified Capabilities
None (no existing specs in `openspec/specs/`)

> **Note**: After apply, portfolio-calculation specs should be created to lock in USD-only normalization.

## Approach

Full USD normalization. Remove the FIAT aggregation layer entirely from portfolio summary calculations. All KPIs (inversión, valor actual, ganancia, rendimiento) compute directly from USD values already available on every movement (`valorTotalUSD`).

Key changes:
1. **CryptoDetail**: Remove `totalInvertidoFIAT`, `valorActualFIAT`. `ganancia` becomes `valorUSD - totalInvertidoUSD`. `porcentajeGanancia` uses USD counterparts.
2. **CarteraDetail**: Add `totalInvertidoUSD` computed property. Remove `totalInvertidoFIAT`, `totalValorFIAT`. `gananciaTotal` becomes sum of `cryptoDetail.ganancia` (now USD-based). `rentabilidadTotal` uses USD.
3. **PortfolioCalculatorService**: Delete the `totalInvertidoFIAT` aggregation block (lines 57–66) and the FIAT conversion block (lines 68–70). Pass `ganancia` as `valorUSD - totalInvertidoUSD`.
4. **MainPortfolioCalculator**: Line 5 — sum `$1.totalInvertidoUSD` instead of `$1.totalInvertidoFIAT`.
5. **Views**: `CarteraHeaderView` references `summary.totalInvertidoUSD` instead of `summary.totalInvertidoFIAT`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Model/PortofolioModel.swift` | Modified | CryptoDetail/CarteraDetail: remove FIAT props, add USD equivalents |
| `Model/PortfolioCalculatorService .swift` | Modified | Delete FIAT aggregation and conversion logic |
| `Model/MainPortfolioCalculator.swift` | Modified | Fix line 5: use totalInvertidoUSD |
| `Views/Portfolio/xCartera/PortfolioViewsComponents.swift` | Modified | CarteraHeaderView: FIAT→USD prop |
| `ViewModels/Portfolio/xCartera/CarteraDetailViewModel.swift` | Review | Confirm gananciaDisplay formatting (no model changes expected) |
| `Crypto TrackerTests/` | Modified | Update tests referencing totalInvertidoFIAT/valorActualFIAT |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Tests fail after property removal | Med | Identify all test references to FIAT props before changing; update atomically |
| Missed view binding | Low | Grep `totalInvertidoFIAT`/`valorActualFIAT`/`totalValorFIAT` across all `.swift` before starting |

## Rollback Plan

Revert the commit. No data model migration — `valorTotalFiatAlterno` stays on SwiftData models. All removed properties are computed, not persisted.

## Dependencies

None — self-contained domain layer fix.

## Success Criteria

- [ ] `CryptoDetail` no longer has `totalInvertidoFIAT` or `valorActualFIAT` fields
- [ ] `MainPortfolioCalculator` sums `totalInvertidoUSD` from crypto details, not `totalInvertidoFIAT`
- [ ] All KPI cards in main portfolio display correct USD-only values (manual verification with mixed FIAT test data)
- [ ] Unit tests pass with updated fixtures (no FIAT property references)
- [ ] No regression in entry forms (`MovimientoEntradaFormView`, `MovimientoSalidaFormView`)
