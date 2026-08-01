# Tasks: Adapt Navigation per Platform (iOS push / macOS sheets)

**Issue**: #24 — Adapt navigation per platform. macOS: sheets. iOS: push navigation or fullScreenCover.

## Phase 1: Detail views from lists → iOS push, macOS sheet

- [x] 1.1 **PortfolioViewsComponents.swift CarteraDetailView** — Wallet name header opens `CarteraMovimientosView` via `NavigationLink` on iOS; keep `.sheet` on macOS. Crypto rows open `CarteraCryptoDetailView` via `NavigationLink` on iOS; keep `.sheet` on macOS.
- [x] 1.2 **PortfolioViewsComponents.swift CarteraDetailView** — Wrap iOS body in `NavigationStack` and remove detail `.sheet` for iOS; retain `.sheet` for macOS.
- [x] 1.3 **PortfolioPorCryptosView.swift** — Crypto rows open `CryptoDetailView` via `NavigationLink` on iOS; keep `.sheet(item: $viewModel.selectedCrypto)` on macOS. Wrap iOS body in `NavigationStack`.
- [x] 1.4 **CarteraMovimientosView.swift** — Movement rows open `MovimientoSearchView` via `NavigationLink` on iOS; keep `.sheet` on macOS. Wrap iOS body in `NavigationStack`.
- [x] 1.5 **CarteraCryptoDetailView.swift** — Movement rows open `MovimientoSearchView` via `NavigationLink` on iOS; keep `.sheet` on macOS. Wrap iOS body in `NavigationStack`.
- [x] 1.6 **CryptoDetailViews.swift** — Movement rows open `MovimientoSearchView` via `NavigationLink` on iOS; keep `.sheet` on macOS. Wrap iOS body in `NavigationStack`.

## Phase 2: Movement forms from "+" menus → iOS fullScreenCover, macOS sheet

- [x] 2.1 **PortfolioViewsComponents.swift applyMovimientoSheets** — Replace movement-form `.sheet` modifiers with `.fullScreenCover` on iOS; keep `.sheet` on macOS.
- [x] 2.2 **PortfolioPorCryptosView.swift applyMovimientoSheets** — Replace movement-form `.sheet` modifiers with `.fullScreenCover` on iOS; keep `.sheet` on macOS.
- [x] 2.3 **MovimientosEntradaView.swift** — Add and edit movement forms use `.fullScreenCover` on iOS; keep `.sheet` on macOS.
- [x] 2.4 **MovimientosSalidaView.swift** — Add and edit movement forms use `.fullScreenCover` on iOS; keep `.sheet` on macOS.
- [x] 2.5 **MovimientosEntreCarterasView.swift** — Add and edit movement forms use `.fullScreenCover` on iOS; keep `.sheet` on macOS.
- [x] 2.6 **MovimientosSwapsView.swift** — Add and edit movement forms use `.fullScreenCover` on iOS; keep `.sheet` on macOS.

## Verification

- [x] 3.1 **macOS build compiles** — `xcodebuild -scheme "Crypto Tracker" -destination "platform=macOS" build` (or Xcode) reports no errors.
- [x] 3.2 **iOS build compiles** — `xcodebuild -scheme "Crypto Tracker" -destination "platform=iOS Simulator" build` (or Xcode) reports no errors.
- [x] 3.3 **No sheet regressions on macOS** — Detail views and forms still present as sheets on macOS (code path preserved behind `#else`).
- [x] 3.4 **iOS detail navigation is push-based** — Tapping wallets, cryptos, and movements pushes a new view via `NavigationLink` inside `NavigationStack`.
- [x] 3.5 **iOS forms use fullScreenCover** — Movement forms from "+" menus and toolbar buttons present full-screen on iOS.

## Notes

- Admin forms (AdminCryptosView, AdminFiatView, AdminCarterasView) and setup/price-history sheets are out of scope; they are not detail views or movement forms from "+" menus.
- iOS bodies are wrapped in `NavigationStack` only where `NavigationLink` push is introduced.
- Use `#if os(iOS)` / `#else` conditional compilation to preserve macOS behavior.
- The project targets iOS 17.0 (set in #21), so `NavigationStack` and `NavigationLink` are available.
