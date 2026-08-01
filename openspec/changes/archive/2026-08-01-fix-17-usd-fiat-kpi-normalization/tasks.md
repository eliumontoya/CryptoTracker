# Tasks: Fix USD/FIAT KPI Normalization in Portfolio

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50 (additions + deletions) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-always |
| Chain strategy | N/A |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Remove FIAT layer from models, calculator, and callers — all KPIs compute in USD | PR 1 | `xcodebuild test -scheme Crypto-Tracker` | N/A — no existing tests cover PortfolioCalculator; manual KPI card verification with mixed-fiat data | Revert single commit; all changes are computed-property renames with no persisted data impact |

## Phase 1: Model Layer — Remove FIAT Properties

- [x] 1.1 In `Model/PortofolioModel.swift`: Remove `totalInvertidoFIAT` and `valorActualFIAT` stored properties from `CryptoDetail` (lines 14–15). Update `porcentajeGanancia` (lines 19–22) to use `totalInvertidoUSD` and `valorUSD` instead of FIAT counterparts, with guard `totalInvertidoUSD != 0`.
- [x] 1.2 In `Model/PortofolioModel.swift`: Remove `totalInvertidoFIAT` computed property (lines 34–36) and `totalValorFIAT` computed property (lines 38–40) from `CarteraDetail`. Add `totalInvertidoUSD` computed property: `cryptoDetails.reduce(0) { $0 + $1.totalInvertidoUSD }`. Update `rentabilidadTotal` (lines 46–49) to use `totalInvertidoUSD` and `valorTotalUSD`, with guard `totalInvertidoUSD > 0`.

## Phase 2: Calculator — Drop FIAT Aggregation and `fiats` Parameter

- [x] 2.1 In `Model/PortfolioCalculatorService .swift`: Remove `fiats: [FIAT]` parameter from `calcularDetallesCartera` signature (line 6). Delete the FIAT aggregation block (lines 57–66) and the FIAT conversion block (lines 68–70). Change `CryptoDetail` init: remove `totalInvertidoFIAT` and `valorActualFIAT` arguments; set `ganancia: valorUSD - totalInvertidoUSD`.
- [x] 2.2 In `Model/PortfolioCalculatorService .swift`: Remove `fiats: [FIAT]` parameter from `calcularDetallesPortfolio` signature (line 92). Remove `fiats: fiats` from the inner `calcularDetallesCartera` call (line 94).

## Phase 3: Fix Bug and Update Callers

- [x] 3.1 In `Model/MainPortfolioCalculator.swift` line 5: Change `$1.totalInvertidoFIAT` to `$1.totalInvertidoUSD`.
- [x] 3.2 In `Views/Portfolio/xCartera/PortfolioViewsComponents.swift` line 27: Change `summary.totalInvertidoFIAT` to `summary.totalInvertidoUSD`.
- [x] 3.3 In `ViewModels/Portfolio/xCartera/PortfolioDetalleViewModel.swift`: Remove `fiats: [FIAT]` parameter from `actualizarPortfolio` signature (line 20). Remove `fiats: fiats` from the `calcularDetallesPortfolio` call (line 27).
- [x] 3.4 In `Views/Portfolio/Resumen/PortfolioView.swift`: Remove `fiats: fiats` from the `calcularDetallesPortfolio` call (line 66).
- [x] 3.5 In `Views/Portfolio/xCartera/PortfolioDetalleView.swift`: Remove `fiats: fiats` from the `actualizarPortfolio` call in `.onAppear` (line 33). The two other calls (lines 59–63, 74–78) are inside a commented-out block — update them as well for consistency.

## Phase 4: Verification

- [ ] 4.1 Run `xcodebuild build` — must compile with zero errors and zero new warnings. *(attempted; blocked by unaccepted Xcode license — `sudo xcodebuild -license` required)*
- [ ] 4.2 Run `xcodebuild test` — all existing tests must pass (no test changes needed; no existing tests reference FIAT properties on CryptoDetail/CarteraDetail). *(attempted; blocked by unaccepted Xcode license)*
- [x] 4.3 Grep for `totalInvertidoFIAT`, `valorActualFIAT`, `totalValorFIAT` across all `.swift` files — must return zero matches in production code.
