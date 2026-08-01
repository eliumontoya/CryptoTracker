# Design: Fix USD/FIAT KPI Normalization in Portfolio

## Technical Approach

Remove the FIAT aggregation layer from `CryptoDetail` and `CarteraDetail`. All portfolio KPIs (investment, value, gain, return) compute from USD-only values already available on every movement. `PortfolioCalculator` drops the `fiats` parameter and its FIAT-conversion block. `MainPortfolioCalculator` line 5 is corrected to sum `totalInvertidoUSD` instead of `totalInvertidoFIAT`.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Remove FIAT computed props entirely | Clean model; no mixed-currency math | **Chosen** — per spec and proposal |
| Keep FIAT props but recalculate correctly | More refactor risk; data model carries dead code | Rejected — dead code |
| Add `totalInvertidoUSD` to `CarteraDetail` | Computed, consistent with existing `valorTotalUSD` | **Chosen** — mirrors existing pattern |

## Data Flow

```
MovimientoIngreso.valorTotalUSD ──→ PortfolioCalculator
                                        │
                                        ├─ CryptoDetail.totalInvertidoUSD
                                        ├─ CryptoDetail.valorUSD (balance * precio)
                                        └─ CryptoDetail.ganancia = valorUSD - totalInvertidoUSD
                                              │
                                              ▼
                                     CarteraDetail
                                        ├─ totalInvertidoUSD (sum of above)
                                        └─ gananciaTotal (sum of ganancia)
                                              │
                                              ▼
                                   MainPortfolioCalculator
                                        └─ MainPortfolioSummary (all USD)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `Model/PortofolioModel.swift` | Modify | Remove `totalInvertidoFIAT`/`valorActualFIAT` from `CryptoDetail`; change `porcentajeGanancia` to use USD. Remove `totalInvertidoFIAT`/`totalValorFIAT` from `CarteraDetail`; add `totalInvertidoUSD`; update `rentabilidadTotal`. |
| `Model/PortfolioCalculatorService .swift` | Modify | Drop `fiats` parameter, delete FIAT aggregation block (lines 57–66) and conversion (68–70). `ganancia = valorUSD - totalInvertidoUSD`. |
| `Model/MainPortfolioCalculator.swift` | Modify | Line 5: `$1.totalInvertidoFIAT` → `$1.totalInvertidoUSD`. |
| `Views/Portfolio/xCartera/PortfolioViewsComponents.swift` | Modify | Line 27: `summary.totalInvertidoFIAT` → `summary.totalInvertidoUSD`. |
| `ViewModels/Portfolio/xCartera/PortfolioDetalleViewModel.swift` | Modify | Remove `fiats` argument from `calcularDetallesPortfolio` call (line 27). |
| `Views/Portfolio/Resumen/PortfolioView.swift` | Modify | Remove `fiats` argument from `calcularDetallesPortfolio` call (line 66). |

## Interfaces / Contracts

### CryptoDetail (before → after)

```swift
// REMOVED
var totalInvertidoFIAT: Decimal
var valorActualFIAT: Decimal

// CHANGED
var ganancia: Decimal  // was: valorActualFIAT - totalInvertidoFIAT
                        // now: valorUSD - totalInvertidoUSD

// CHANGED
var porcentajeGanancia: Decimal {
    guard totalInvertidoUSD != 0 else { return 0 }       // was: totalInvertidoFIAT
    return ((valorUSD - totalInvertidoUSD) / totalInvertidoUSD) * 100  // was: FIAT
}
```

### CarteraDetail (before → after)

```swift
// ADDED
var totalInvertidoUSD: Decimal { cryptoDetails.reduce(0) { $0 + $1.totalInvertidoUSD } }

// REMOVED
var totalInvertidoFIAT: Decimal { ... }
var totalValorFIAT: Decimal { ... }

// CHANGED
var rentabilidadTotal: Decimal {
    guard totalInvertidoUSD > 0 else { return 0 }                          // was: totalInvertidoFIAT
    return ((valorTotalUSD - totalInvertidoUSD) / totalInvertidoUSD) * 100 // was: FIAT
}
```

### PortfolioCalculator (before → after)

```swift
// BEFORE
static func calcularDetallesCartera(_ cartera: Cartera, cryptos: [Crypto], fiats: [FIAT]) -> CarteraDetail

// AFTER
static func calcularDetallesCartera(_ cartera: Cartera, cryptos: [Crypto]) -> CarteraDetail
```

```swift
// BEFORE
static func calcularDetallesPortfolio(carteras: [Cartera], cryptos: [Crypto], fiats: [FIAT]) -> [CarteraDetail]

// AFTER
static func calcularDetallesPortfolio(carteras: [Cartera], cryptos: [Crypto]) -> [CarteraDetail]
```

Callers of these methods must remove the `fiats` argument.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | No existing tests reference FIAT properties (grep confirmed). No test changes needed. | N/A |
| Manual | Verify KPI cards show correct USD-only values with mixed-fiat test data | Manual verification per success criteria |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. All removed properties are computed, not persisted. `valorTotalFiatAlterno` stays on SwiftData models. Rollback: revert the commit.

## Open Questions

None — all decisions resolved in proposal.
