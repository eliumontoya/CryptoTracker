# Exploration: Complete AppDependencyContainer for All ViewModels

**Issue**: #28 — `AppDependencyContainer` only covers MovimientosEntrada and PortfolioPorCryptos. All other ViewModels get `ModelContext` directly or via `@Environment(\.modelContext)`, making dependencies implicit and testing harder.

## Current State

`AppDependencyContainer` (App/AppDependencyContainer.swift) currently exposes:

- **Services**: `movimientosEntradaService: MovimientosEntradaServiceProtocol`
- **ViewModels**: `movimientoEntradaViewModel`, `movimientosEntradaListViewModel`, `portfolioPorCryptosViewModel`
- **Factories**: `makeMovimientosEntradaView()`, `makeMovimientoEntradaFormView(movimiento:)`

All other ViewModels are constructed inside Views, either from `@Environment(\.modelContext)` or from a `modelContext:` init parameter threaded from ContentView. This spreads dependency construction across 15+ view files.

## ViewModel Inventory

### Covered by container (3)
| ViewModel | Deps |
|---|---|
| `MovimientoEntradaViewModel` | `MovimientosEntradaServiceProtocol` |
| `MovimientosEntradaListViewModel` | `MovimientosEntradaServiceProtocol` |
| `PortfolioPorCryptosViewModel` (file `PortfolioCryptosViewModel.swift`) | `ModelContext`, service |

### Uncovered (15)
| ViewModel | Init deps | Container role |
|---|---|---|
| `PortfolioDetalleViewModel` | `modelContext` | shared instance |
| `AdminCarterasViewModel` | `modelContext` | shared instance |
| `AdminCryptosViewModel` | `modelContext` | shared instance |
| `AdminFiatViewModel` | `modelContext` | shared instance |
| `CryptoSyncViewModel` | `modelContext` | shared instance |
| `CargaCatalogosViewModel` | `modelContext` | shared instance |
| `CargaMovimientosViewModel` | `modelContext` | shared instance |
| `EliminarDataViewModel` | `modelContext` | shared instance |
| `CarteraMovimientosViewModel` | `cartera`, `modelContext` | factory (`cartera:`) |
| `MovimientoSalidaViewModel` | `modelContext`, `movimiento?` | factory (`movimiento:`) |
| `MovimientoEntreCarterasViewModel` | `modelContext`, `movimiento?` | factory (`movimiento:`) |
| `MovimientoSwapViewModel` | `modelContext`, `movimiento?` | factory (`movimiento:`) |
| `CarteraCryptoDetailViewModel` | `crypto`, `cartera` (no context) | factory (`crypto:cartera:`) |
| `CarteraDetailViewModel` | `carteraDetail`, `onUpdateData` (no context) | factory |
| `CryptoDetailViewModel` | `crypto`, `carteras` (no context) | factory (`crypto:`) |

### Out of scope
- `PortfolioCryptoComponentsViewModel` — stateless value/naming holder, zero dependencies, instantiated inline as `PortfolioCryptoComponentsViewModel()`.

## @Environment(\.modelContext) Usage in Views (16 files)

| File | Usage | Action |
|---|---|---|
| ContentView.swift | passes `modelContext` to destinations + `.environment` | replace with `dependencies.makeX()`; drop env |
| PortfolioView.swift | declared but **unused** | drop dead property |
| PortfolioPorCryptosView.swift | `viewModel.modelContext = modelContext` onAppear | drop (container injects at init) |
| PortfolioDetalleView.swift | init `modelContext:` param → builds VM | take `viewModel:` + `dependencies` |
| PortfolioViewsComponents.swift (CarteraDetailView) | builds forms + CarteraMovimientosView in sheets | take `dependencies`; use container factories |
| CarteraMovimientosView.swift | builds `MovimientoSearchView` in sheet | take `dependencies` |
| CarteraCryptoDetailView.swift | builds `MovimientoSearchView` in sheet | take `dependencies` |
| CryptoDetailViews.swift | builds `MovimientoSearchView` in sheet | take `dependencies` |
| MovimientoForms.swift (SearchView/EditView) | SearchView builds entrada VM; EditView builds 3 form VMs | take `dependencies` |
| MovimientosSalidaView.swift | builds `MovimientoSalidaFormView`; `delete` uses context | take `dependencies`; delete via `dependencies.modelContext` |
| MovimientosEntreCarterasView.swift | same pattern | take `dependencies` |
| MovimientosSwapsView.swift | same pattern | take `dependencies` |
| AdminCryptosView.swift | `@Environment` **dead** (init already takes `modelContext:`) | take `viewModel:` |
| AdminCarterasView.swift | init `modelContext:` param | take `viewModel:` |
| AdminFiatView.swift | init `modelContext:` param | take `viewModel:` |
| CryptoSyncView.swift | init `modelContext:` param | take `viewModel:` |
| SetupInicialView.swift | `createDestination: (ModelContext) -> AnyView` | take `dependencies`; closures capture it |
| CargaCatalogosView.swift | env dead + init `modelContext:` param | take `dependencies` |
| EliminarDataView.swift | env dead + init `modelContext:` param | take `dependencies` |
| CargaMovimientosInicialesView.swift | env dead + init `modelContext:` param | take `dependencies` |
| MovimientosEntradaView.swift | `@Environment` **unused** | drop dead property |

## Approaches

1. **Full container + view rewiring (recommended)** — Add all 15 VMs to the container (8 shared instances + factory methods), rewire every view to receive `viewModel:`/`dependencies:` from container factories, remove all `@Environment(\.modelContext)` in views.
   - Pros: single DI source of truth; ViewModels testable in isolation; matches existing pattern already in ContentView; removes implicit deps.
   - Cons: touches ~22 files (mechanical churn); larger PR.
   - Effort: Medium

2. **Container only, no view rewiring** — Add VMs + factories to container but leave views constructing from `@Environment`.
   - Pros: tiny diff.
   - Cons: does NOT fix the issue (dependencies stay implicit); factories unused; tests unchanged. Rejected.

3. **Protocols for every service** — extract protocols for CargaMovimientos*, MovimientoSalida/Egreso/Swap persistence.
   - Pros: max mockability.
   - Cons: over-engineering for this issue; existing tests already mock via in-memory `ModelContext` (`TestSetup.createModelContext()`). Deferred.

## Recommendation

Approach 1. Keep `MovimientosEntradaServiceProtocol` as the one existing service protocol; ModelContext-backed VMs remain testable with the in-memory context (existing `TestSetup` pattern). Add `AppDependencyContainerTests` that builds the container against an in-memory context and asserts every shared ViewModel instantiates — this directly proves issue task 5 ("tests can instantiate ViewModels with mock dependencies").

## Risks

- **Preview breakage** — Previews calling `CryptoDetailView(crypto:)`, `CarteraCryptoDetailView(crypto:cartera:)`, `PortfolioDetalleView(modelContext:)` must be updated to build an `AppDependencyContainer` from `PreviewContainer.shared.context`.
- **@StateObject shared instances** — shared container VMs are wrapped in `@StateObject` in multiple views; acceptable (same pattern already used for `movimientosEntradaListViewModel`).
- **Xcode build required** — CLI `xcodebuild` unavailable (CommandLineTools active); verification by code review + in-IDE build per project-context.md.
- **Xcode 16 synchronized folders** — new test file auto-joins the target; no pbxproj edits.

## Ready for Proposal

Yes — scope confirmed, inventory complete, recommendation clear.
