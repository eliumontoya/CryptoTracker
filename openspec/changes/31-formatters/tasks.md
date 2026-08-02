# Tareas — Issue #31: Unificar cálculo de fechas, monedas y formateo

## Fase 1: Exploración
- [x] 1.1 Buscar formateo inline en Views (`.formatted()`, `.currency(code:)`, `DateFormatter`)

## Fase 2: Implementación
- [x] 2.1 Crear `Helpers/Format.swift` con los formatters unificados (`usd`, `currency`, `crypto`, `date`, `percent`)
- [x] 2.2 Reemplazar formatos USD en vistas y ViewModels por `Format.usd(...)`
- [x] 2.3 Reemplazar cantidades de crypto/fiat por `Format.crypto(...)` / `Format.currency(...)`
- [x] 2.4 Reemplazar fechas por `Format.date(...)`
- [x] 2.5 Reemplazar porcentajes por `Format.percent(...)`

## Fase 3: Verificación
- [x] 3.1 Ejecutar `xcodebuild build` y confirmar éxito

## Notas
- Se agregó sobrecarga de `Double` para `usd`, `currency`, `crypto` y `percent` porque `MainChartData.porcentaje` es `Double`.
- Se dejaron sin cambio los `TextField` que usan `format: .currency(code:)` porque son bindings de edición, no texto de presentación.
- Se dejaron sin cambio los `DateFormatter` de los parsers de Excel porque son parsing, no presentación.
- Se dejaron sin cambio los timestamps de logs en ViewModels de Setup Inicial (`date: .omitted, time: .standard`).

## Archivos modificados
- `Crypto Tracker/Helpers/Format.swift` (creado)
- `Crypto Tracker/Views/Portfolio/xCartera/PortfolioViewsComponents.swift`
- `Crypto Tracker/Views/Admin/AdminCryptosView.swift`
- `Crypto Tracker/Views/Admin/CryptoPreciosHistoricosView.swift`
- `Crypto Tracker/Views/Admin/AdminCarterasView.swift`
- `Crypto Tracker/Views/Admin/AdminFiatView.swift`
- `Crypto Tracker/Views/Admin/CryptoSyncComponents.swift`
- `Crypto Tracker/Views/Portfolio/Resumen/MainPortfolioComponents.swift`
- `Crypto Tracker/Views/Portfolio/Resumen/MainPortfolioCharts.swift`
- `Crypto Tracker/Views/Portfolio/xCryptos/PortfolioCryptoComponents.swift`
- `Crypto Tracker/Views/Movimientos/MovimientoComponents.swift`
- `Crypto Tracker/Views/Movimientos/MovimientosSwapsView.swift`
- `Crypto Tracker/Views/Movimientos/MovimientosSalidaView.swift`
- `Crypto Tracker/Views/Movimientos/MovimientosEntreCarterasView.swift`
- `Crypto Tracker/Views/Movimientos/Forms/MovimientoEntreCarterasFormView.swift`
- `Crypto Tracker/Views/Movimientos/Forms/MovimientoSwapFormView.swift`
- `Crypto Tracker/Views/Movimientos/Forms/MovimientoSalidaFormView.swift`
- `Crypto Tracker/Movimientos/MovimientosEntradaView.swift`
- `Crypto Tracker/Movimientos/MovimientoEntradaFormView.swift`
- `Crypto Tracker/ViewModels/Portfolio/xCartera/CarteraDetailViewModel.swift`
- `Crypto Tracker/ViewModels/Portfolio/xCryptos/PortfolioCryptoComponentsViewModel.swift`

## Comando de verificación
```bash
xcodebuild -scheme "Crypto Tracker" -project "Crypto Tracker.xcodeproj" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```
Resultado: `** BUILD SUCCEEDED **`
