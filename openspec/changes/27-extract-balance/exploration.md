# Exploration: Extract balance calculation to a single place

## Current State

The crypto-balance algorithm `ingresos + transferenciasRecibidas + swapsRecibidos - egresos - transferenciasEnviadas - swapsEnviados` is duplicated 3 times, plus 1 file that already delegates:

| # | Location | Function | Status |
|---|----------|----------|--------|
| 1 | `Model/CarteraExtension.swift` | `Cartera.getCryptoDisponible(crypto:movimientoActual:)` | Inline implementation |
| 2 | `ViewModels/Admin/AdminCarterasViewModel.swift` | `calcularBalanceCrypto(_:en:)` (private) | Inline implementation |
| 3 | `Model/PortfolioCalculatorService.swift` | `PortfolioCalculator.calcularDetallesCartera` → `balanceActual` | Inline implementation |
| 4 | `Model/PortfolioCryptoCalculator.swift` | `calcularResumenPorCrypto` | **Already delegates** to `cartera.getCryptoDisponible(crypto:)` |

All three implementations are mathematically identical:
- `ingresos`: `cartera.movimientosIngreso` filtered by `crypto.id`, sum `cantidadCrypto`
- `egresos`: `cartera.movimientosEgreso` filtered by `crypto.id`, sum `cantidadCrypto`
- `transferenciasRecibidas`: `cartera.movimientosEntrada` filtered by `crypto.id`, sum `cantidadCryptoEntrada`
- `transferenciasEnviadas`: `cartera.movimientosSalida` filtered by `crypto.id`, sum `cantidadCryptoSalida`
- `swapsRecibidos`: `cartera.swaps` filtered by `cryptoDestino.id`, sum `cantidadDestino`
- `swapsEnviados`: `cartera.swaps` filtered by `cryptoOrigen.id`, sum `cantidadOrigen`

`MainPortfolioCalculator` was checked and is NOT a 5th duplicate — it aggregates USD totals (`valorTotalUSD`, `cantidadOrigen * precioUSDOrigen`) already computed by `CarteraDetail`/`CryptoDetail`, not raw crypto balances.

## Affected Areas

- `Crypto Tracker/Model/BalanceCalculator.swift` — NEW: single source of truth
- `Crypto Tracker/Model/CarteraExtension.swift` — `getCryptoDisponible` delegates to `BalanceCalculator`
- `Crypto Tracker/ViewModels/Admin/AdminCarterasViewModel.swift` — remove private `calcularBalanceCrypto`, call `BalanceCalculator` directly
- `Crypto Tracker/Model/PortfolioCalculatorService.swift` — replace inline `balanceActual` computation
- `Crypto Tracker/Model/PortfolioCryptoCalculator.swift` — no change needed (already delegates)

Callers of `getCryptoDisponible` (8 sites: 3 parsers, `MovimientosEntradaService`, 3 movement ViewModels, `PortfolioCryptoCalculator`) are unaffected because the signature is preserved as a thin wrapper.

## Approaches

1. **Object-based service `BalanceCalculator.balance(crypto:en:movimientoActual:)`** — matches codebase pattern (all services take live model objects, e.g. `PortfolioCalculator.calcularDetallesCartera(_ cartera:cryptos:)`). All callers already hold `Cartera` + `Crypto` objects; no new dependencies; behavior identical with minimal churn.
   - Pros: zero caller changes, no ModelContext dependency, testable pure function, matches existing service conventions
   - Cons: deviates from the literal `(cryptoId: UUID, carteraId: UUID)` sketch in the issue
   - Effort: Low

2. **UUID-based service `balance(cryptoId:carteraId:modelContext:)`** — the literal issue signature. Requires fetching `Cartera` and `Crypto` from a `ModelContext` inside the calculator, changes every caller's structure (they currently pass objects they already have), and couples the calculator to persistence.
   - Pros: literal match to issue sketch
   - Cons: invasive, adds ModelContext dependency, fetch cost per call, breaks `movimientoActual` editing flow ergonomics
   - Effort: Medium/High

## Recommendation

Approach 1 (object-based). The issue's UUID signature is a conceptual sketch of the formula; the domain terms (ingresos, transferenciasRecibidas, swapsRecibidos, egresos, transferenciasEnviadas, swapsEnviados) are preserved exactly. This satisfies "single algorithm in one place" with identical behavior and zero risk to the 8 `getCryptoDisponible` callers.

## Risks

- **No direct unit tests** for the balance formula (only parser tests that exercise `getCryptoDisponible` indirectly via movement insertion). Mitigation: behavior-preserving refactor; `guard balanceActual != 0` in `calcularDetallesCartera` and `guard totalDisponible > 0` in `calcularResumenPorCrypto` are caller-level filters and must stay outside the calculator.
- **`movimientoActual` parameter** is used by 3 movement ViewModels for edit-form validation; must remain on the public `getCryptoDisponible` wrapper and the `BalanceCalculator.balance` API.
- **Synchronized root group** in `.pbxproj` (PBXFileSystemSynchronizedRootGroup) — new file in `Model/` is auto-included in the target, no pbxproj edit needed.

## Ready for Proposal

Yes — the approach is fixed (single object-based service, 4 files touched, behavior-preserving).
