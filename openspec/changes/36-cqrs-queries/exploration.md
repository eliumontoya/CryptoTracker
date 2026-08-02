## Exploration: 36-cqrs-queries

### Current State

`feat/36-cqrs` was based on #32 (Portfolio entity). The Holding materialized table
(#33) and the unified `Movimiento` entity (#34) existed as sibling branches one
commit ahead of the base. Before this change, all portfolio KPIs were computed by
summing N movements per wallet×crypto in three calculators:

- `MainPortfolioCalculator.calcularResumen` — sum of `CarteraDetail` totals + sales (salidas + swapSalida)
- `PortfolioCalculatorService.calcularDetallesCartera` — per-crypto breakdown over 4 old relationship arrays
- `PortfolioCryptoCalculator.calcularResumenPorCrypto` — per-crypto totals over cartera relationship arrays

Each calculator walked `cartera.movimientos` multiple times (`BalanceCalculator` filters
6 movement categories per crypto×wallet pair). There was no read layer: view models
pulled `carteras`/`cryptos` via `@Query` and passed them into calculators.

### Affected Areas

- `Crypto Tracker/Domain/Queries/PortfolioQueries.swift` — NEW: 4 read queries + 3 read models (CQRS-lite read layer)
- `Crypto Tracker/Model/MainPortfolioCalculator.swift` — rewrite to query-backed, signature `(portfolioId:in:)`
- `Crypto Tracker/Model/PortfolioCalculatorService.swift` — rewrite to query-backed wallet breakdown
- `Crypto Tracker/Model/PortfolioCryptoCalculator.swift` — rewrite to query-backed per-crypto summary
- `Crypto Tracker/ViewModels/Portfolio/xCartera/PortfolioDetalleViewModel.swift` — `actualizarPortfolio()` resolves default portfolio
- `Crypto Tracker/ViewModels/Portfolio/xCryptos/PortfolioCryptosViewModel.swift` — same, plus dead `do/catch` removal
- `Crypto Tracker/Views/Portfolio/Resumen/PortfolioView.swift`, `xCartera/PortfolioDetalleView.swift`, `xCryptos/PortfolioPorCryptosView.swift` — drop unused `@Query`/imports
- `Crypto Tracker/App/Crypto_TrackerApp.swift`, `Model/Model.swift`, `Model/PreviewContainer.swift`, `Crypto TrackerTests/{CargaMovimientosTests,TestHelpers}.swift` — merge conflicts resolved to register both `Holding` + `Movimiento`

### Approaches

1. **Query layer on materialized `Holding` (CQRS-lite) — chosen**
   - Balances (qty) come from `FetchDescriptor<Holding>` (no N-movement sums for balance)
   - Cost basis (adquirido/ventas USD) aggregated in one pass over movements
   - Pros: matches issue intent, predictable performance, read models decouple UI from persistence
   - Cons: cost basis still needs movement aggregation (Holding stores only qty — schema change out of scope)
   - Effort: Medium

2. **Extend Holding with cost columns**
   - Pros: fully materialized reads
   - Cons: schema v4→v5 + migration + write-path changes; belongs to #35/#34 territory; larger blast radius
   - Effort: High (rejected for this change)

3. **Keep calculators as-is**
   - Pros: zero risk
   - Cons: does not implement the issue
   - Effort: Low (rejected)

### Recommendation

Approach 1. New `Domain/Queries/PortfolioQueries.swift` (auto-registered by the
synchronized root group) with `FetchDescriptor` + `#Predicate`; calculators become
thin adapters mapping query read models to the existing UI structs (`MainPortfolioSummary`,
`CryptoPortfolioSummary`, `CarteraDetail`); view models resolve the default portfolio
(`Portfolio.isDefault`) since the app is single-portfolio today.

### Risks

- `#Predicate` key-path traversal on relationships (`$0.portfolio.id`) is supported by SwiftData but validated by the compiler only at runtime — covered by build + full test run (0 new failures)
- Portfolio scoping: single active portfolio via `defaultPortfolio`; multi-portfolio UI is future work
- Preview container seeds holdings, so previews show data; real holdings get written by #35 transaction-runner wiring (follow-up)

### Ready for Proposal

Yes — exploration complete; implementation compiled (app + test targets) with 0 new test regressions.
