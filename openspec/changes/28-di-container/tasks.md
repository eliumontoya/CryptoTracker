# Tasks: Complete AppDependencyContainer for All ViewModels

**Issue**: #28 — `AppDependencyContainer` only covers MovimientosEntrada and PortfolioPorCryptos. All other ViewModels get `ModelContext` directly or via `@Environment(\.modelContext)`, making dependencies implicit and testing harder.

## Phase 1: AppDependencyContainer

- [x] 1.1 **App/AppDependencyContainer.swift** — Add shared instances: `portfolioDetalleViewModel`, `adminCarterasViewModel`, `adminCryptosViewModel`, `adminFiatViewModel`, `cryptoSyncViewModel`, `cargaCatalogosViewModel`, `cargaMovimientosViewModel`, `eliminarDataViewModel`.
- [x] 1.2 **App/AppDependencyContainer.swift** — Add ViewModel factories: `makeMovimientoEntradaViewModel(movimiento:)`, `makeMovimientoSalidaViewModel(movimiento:)`, `makeMovimientoEntreCarterasViewModel(movimiento:)`, `makeMovimientoSwapViewModel(movimiento:)`, `makeCarteraMovimientosViewModel(cartera:)`, `makeCarteraCryptoDetailViewModel(crypto:cartera:)`, `makeCryptoDetailViewModel(crypto:carteras:)`.
- [x] 1.3 **App/AppDependencyContainer.swift** — Add view factories for every screen: portfolio (`makePortfolioView`, `makePortfolioPorCryptosView`, `makePortfolioDetalleView`, `makeCarteraDetailView`, `makeCarteraMovimientosView`, `makeCarteraCryptoDetailView`, `makeCryptoDetailView`), movimientos (`makeMovimientosEntradaView`, form factories, `makeMovimientosSalidaView`, `makeMovimientosEntreCarterasView`, `makeMovimientosSwapsView`, `makeMovimientoSearchView`), admin (`makeAdminCryptosView`, `makeAdminCarterasView`, `makeAdminFiatView`, `makeCryptoSyncView`, `makeSetupInicialView`, `makeCargaCatalogosView`, `makeEliminarDataView`, `makeCargaMovimientosInicialesView`).

## Phase 2: Inject ModelContext explicitly instead of @Environment

- [x] 2.1 **ContentView.swift** — Replace all destinations with `dependencies.makeX()`; remove `@Environment(\.modelContext)` and `.environment(\.modelContext, modelContext)` modifiers.
- [x] 2.2 **PortfolioView.swift** — Remove unused `@Environment(\.modelContext)`.
- [x] 2.3 **PortfolioPorCryptosView.swift** — Take `dependencies:`; remove `@Environment` and the redundant `viewModel.modelContext = modelContext` onAppear assignment; use `dependencies.makeCryptoDetailView(crypto:)`.
- [x] 2.4 **PortfolioDetalleView.swift** — Take `viewModel:` + `dependencies:`; build `CarteraDetailView` cards via `dependencies.makeCarteraDetailView`.
- [x] 2.5 **PortfolioViewsComponents.swift (CarteraDetailView + applyMovimientoSheets)** — Take `dependencies:`; all sheets/forms via container factories; remove `@Environment`.
- [x] 2.6 **CarteraMovimientosView.swift** — Take `dependencies:`; VM from `dependencies.modelContext`; `MovimientoSearchView` via factory.
- [x] 2.7 **CarteraCryptoDetailView.swift** — Take `dependencies:`; `MovimientoSearchView` via factory; update preview.
- [x] 2.8 **CryptoDetailViews.swift** — Take `dependencies:`; `MovimientoSearchView` via factory; update preview.
- [x] 2.9 **MovimientoForms.swift (MovimientoSearchView + EditMovimientoView)** — Take `dependencies:`; build form ViewModels via container factories; remove `@Environment`.
- [x] 2.10 **MovimientosSalidaView / MovimientosEntreCarterasView / MovimientosSwapsView** — Take `dependencies:`; forms via factories; delete uses `dependencies.modelContext`; remove `@Environment`.
- [x] 2.11 **MovimientosEntradaView.swift** — Remove unused `@Environment(\.modelContext)`.
- [x] 2.12 **AdminCryptosView / AdminCarterasView / AdminFiatView / CryptoSyncView** — Take `viewModel:` instead of `modelContext:`; remove `@Environment`.
- [x] 2.13 **SetupInicialView.swift** — Take `dependencies:`; `SetupOption.createDestination` becomes `() -> AnyView` capturing dependencies; remove `@Environment`.
- [x] 2.14 **CargaCatalogosView / EliminarDataView / CargaMovimientosInicialesView** — Take `dependencies:`; VMs from container; remove `@Environment` and dead `modelContext` properties.
- [x] 2.15 **PortfolioCryptosViewModel.swift** — Make `modelContext` `private let` (was `var`, mutated from view onAppear).

## Phase 3: Testability

- [x] 3.1 **Crypto TrackerTests/AppDependencyContainerTests.swift** — New test suite: container builds against in-memory context, all shared VMs instantiate, ViewModel factories produce fresh instances, view factories build.
- [x] 3.2 **Scheme + test infra** — Add shared scheme (`Crypto Tracker.xcodeproj/xcshareddata/xcschemes/`) so the test target is runnable from CLI (fixes documented "schemes are user-specific only" risk).
- [x] 3.3 **Pre-existing SwiftData test-host traps** — Fix `TestSetup.createModelContext()` (Schema-based `ModelContainer` + `ModelContext(container)` instead of `container.mainContext`) and same pattern in 5 test suites (CryptoSync, CargaMovimientosViewModel, EliminarData, CargaCatalogos, CargaMovimientos); add `@MainActor` to `CargaMovimientosTests` (mock conforms to `@MainActor` protocol).
- [x] 3.4 **CryptoSyncViewModel deinit trap** — Remove `deinit` that created a self-capturing `Task` (crashed every deallocation with SIGTRAP); removed dead `cleanupTask` property.

## Verification

- [x] 4.1 **macOS build compiles** — `xcodebuild -scheme "Crypto Tracker" -destination "platform=macOS" build` succeeds.
- [x] 4.2 **iOS build compiles** — `xcodebuild -scheme "Crypto Tracker" -destination "generic/platform=iOS Simulator" build` succeeds.
- [x] 4.3 **AppDependencyContainerTests pass** — 8/8 green via `xcodebuild test`.
- [x] 4.4 **No regressions** — All 73 tests passing on base still pass (108 pass total; 35 pre-existing tests fixed as collateral).
- [ ] 4.5 **Remaining pre-existing failures** — 19 tests in 6 suites (CargaCatalogos 1, CargaMovimientosTests 4, CargaMovimientosViewModel 5, EliminarData 2, MovimientoEntreCarteras 3, MovimientoSalida 4) fail on assertion/async-race/Excel-generation logic. Same suites fail on base commit. Out of scope for #28; tracked for a future test-fix issue.

## Notes

- `PortfolioCryptoComponentsViewModel` is stateless (no dependencies) — intentionally not containerized.
- `MovimientosEntradaServiceProtocol` remains the single service protocol; ModelContext-backed ViewModels stay testable via in-memory `ModelContext`.
- Fixed a latent SwiftData pitfall: `ModelContainer.mainContext` fetch traps (SIGTRAP) on macOS 26 in test hosts; use `ModelContext(container)` instead.
- Fixed a latent `CryptoSyncViewModel` deinit trap: `deinit { Task { await cleanup() } }` captured self and crashed on deallocation.
