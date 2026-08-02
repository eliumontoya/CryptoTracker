# Tasks: 34-unified-movement

Issue #34 — feat(domain): unificar 4 entidades de movimiento en una sola con TipoMovimiento

Replace `MovimientoIngreso`, `MovimientoEgreso`, `MovimientoEntreCarteras`, `MovimientoSwap`
with a single `@Model class Movimiento` using `enum TipoMovimiento` (8 valores).

## Explore

- [x] E1. Read Model.swift completely — 4 movement classes + inverse relationships on FIAT/Crypto/Cartera
- [x] E2. Map all files referencing old movement types (39 files: views, VMs, services, parsers, tests)
- [x] E3. Design unified `Movimiento` (union of ALL fields as optionals + `groupId` for pairs)
- [x] E4. Verify Xcode project uses `PBXFileSystemSynchronizedRootGroup` (new files auto-registered)
- [x] E5. Persist `exploration.md`

## Implement — Model layer

- [x] I1. `Model/Model.swift` — add `enum TipoMovimiento: String, Codable` (8 casos) + unified `Movimiento`
- [x] I2. `Model/Model.swift` — keep 4 old classes marked DEPRECATED (doc comment) for migration
- [x] I3. `Model/Model.swift` — add unified inverse arrays `movimientos` (y roles origen/destino) a Cartera/Crypto/FIAT
- [x] I4. `Model/MovimientoMigration.swift` (NUEVO) — copia v3→v4: 1 registro por entrada/salida, PAR con `groupId` por transferencia/swap (idempotente)
- [x] I5. `App/Crypto_TrackerApp.swift` — schema version `3.0.0 → 4.0.0`, registra `Movimiento`, llama `MovimientoMigration.apply`
- [x] I6. `Model/PreviewContainer.swift` — registra `Movimiento`; seed con `Movimiento.entrada`
- [x] I7. Calculadores unificados: `BalanceCalculator`, `PortfolioCryptoCalculator`, `PortfolioCalculatorService`, `MainPortfolioCalculator` leen `cartera.movimientos` + filtro por `tipo`

## Implement — Services & Parsers

- [x] S1. `Movimientos/MovimientosEntradaService.swift` — protocolo e impl sobre `Movimiento`
- [x] S2. Parsers: `MovimientoEntradaParser` → `[Movimiento]` `.entrada`; `MovimientoSalidaParser` → `[Movimiento]` `.salida`
- [x] S3. `MovimientoEntreCarterasParser` → `[Movimiento]` (2 piernas por fila, mismo `groupId`)
- [x] S4. `MovimientoSwapParser` → `[Movimiento]` (2 piernas por fila, mismo `groupId`)
- [x] S5. `CargaMovimientos{Entrada,Salida,EntreCarteras,Swap}Service` — sin cambios de tipo (insertan `[Movimiento]`)

## Implement — ViewModels

- [x] V1. `MovimientoEntradaViewModel` / `MovimientoSalidaViewModel` — guardan/editan `Movimiento` (`.entrada` / `.salida`)
- [x] V2. `MovimientoEntreCarterasViewModel` — crea/edita/elimina el PAR (salida+entrada) con `groupId`
- [x] V3. `MovimientoSwapViewModel` — crea/edita/elimina el PAR (swapSalida+swapEntrada) con `groupId`
- [x] V4. `EliminarDataViewModel` — borra `Movimiento` (tabla unificada)
- [x] V5. `AdminCarterasViewModel` / `AdminFiatViewModel` — validaciones vía `cartera.movimientos` / `fiat.movimientos`
- [x] V6. `CarteraMovimientosViewModel`, `CarteraCryptoDetailViewModel`, `CryptoDetailViewModel` — construyen `MovimientoDetalle` desde `Movimiento` (swap renderiza solo pierna `.swapSalida`)
- [x] V7. `AppDependencyContainer.swift` — factories con `movimiento: Movimiento?`

## Implement — Views

- [x] W1. `MovimientosEntradaView` / `MovimientosSalidaView` — `@Query` con `#Predicate { $0.tipoRaw == "entrada"/"salida" }`
- [x] W2. `MovimientosEntreCarterasView` / `MovimientosSwapsView` — 1 fila por operación lógica (pierna salida + su par por `groupId`); delete borra ambas piernas
- [x] W3. `MovimientoForms.swift` — `EditMovementMode.movimiento(Movimiento)`; routing por `tipo`; `EntradaEditView` wrapper
- [x] W4. `Views/Admin/CryptoSyncView.swift` — FIX pre-existente (llave `}` sobrante línea 10) que bloqueaba el build

## Implement — Tests

- [x] T1. Schemas de test registran `Movimiento` (`TestHelpers`, `CargaMovimientosTests`, `EliminarDataViewModelTests`)
- [x] T2. Seeds de parser tests usan `Movimiento.entrada` (balance visible al `BalanceCalculator` unificado)
- [x] T3. VM tests: fetch/creación con `Movimiento` + predicados por `tipoRaw`
- [x] T4. Parser tests de transferencia/swap: `count == 2` (par = 2 piernas)

## Verify

- [x] V1. `xcodebuild build` macOS → BUILD SUCCEEDED (sin errores nuevos)
- [x] V2. `xcodebuild build-for-testing` → TEST BUILD SUCCEEDED
- [x] V3. `xcodebuild build` iOS Simulator (generic) → BUILD SUCCEEDED
- [x] V4. Suite completa: 19 fallos — IDÉNTICOS al baseline del commit pristine (0 regresiones nuevas)
- [x] V5. Cero warnings nuevos vs baseline
- [x] V6. Persist apply progress en Engram `sdd/34-unified-movement/apply-progress` (project `cryptotracker`)

## Detalle por archivo (42 archivos: 41 modificados + 1 nuevo)

| Archivo | Cambio |
|---|---|
| `Model/Model.swift` | Enum TipoMovimiento + Movimiento unificado + clases viejas deprecadas + inverses nuevos |
| `Model/MovimientoMigration.swift` | NUEVO — migración de datos v3→v4 idempotente |
| `Model/BalanceCalculator.swift` | balance desde `cartera.movimientos` + tipo |
| `Model/PortfolioCalculatorService.swift` | detalles por crypto desde Movimiento |
| `Model/PortfolioCryptoCalculator.swift` | resumen por crypto desde Movimiento |
| `Model/MainPortfolioCalculator.swift` | ventas totales desde Movimiento |
| `Model/PreviewContainer.swift` | schema + seed Movimiento |
| `App/Crypto_TrackerApp.swift` | schema v4 + migración |
| `App/AppDependencyContainer.swift` | factories → Movimiento |
| `Movimientos/MovimientosEntradaService.swift` | protocolo+impl → Movimiento |
| `Movimientos/MovimientosEntradaViewModel.swift` | VM entrada → Movimiento |
| `Movimientos/lib/MovimientosEntradaListViewModel.swift` | list VM → Movimiento |
| `Movimientos/MovimientosEntradaView.swift` | @Query tipoRaw=="entrada" |
| `ViewModels/Movimientos/MovimientoSalidaViewModel.swift` | VM salida → Movimiento |
| `ViewModels/Movimientos/MovimientoEntreCarterasViewModel.swift` | VM transferencia → par con groupId |
| `ViewModels/Movimientos/MovimientoSwapViewModel.swift` | VM swap → par con groupId |
| `ViewModels/Admin/AdminCarterasViewModel.swift` | validaciones vía cartera.movimientos |
| `ViewModels/Admin/AdminFiatViewModel.swift` | validación vía fiat.movimientos |
| `ViewModels/Admin/SetupInicial/EliminarDataViewModel.swift` | borra tabla Movimiento |
| `ViewModels/Portfolio/xCartera/CarteraMovimientosViewModel.swift` | MovimientoDetalle desde Movimiento |
| `ViewModels/Portfolio/xCartera/CarteraCryptoDetailViewModel.swift` | ídem por crypto/cartera |
| `ViewModels/Portfolio/xCryptos/CryptoDetailViewModel.swift` | ídem por crypto |
| `Services/.../Parsers/MovimientoEntradaParser.swift` | → Movimiento.entrada |
| `Services/.../Parsers/MovimientoSalidaParser.swift` | → Movimiento.salida |
| `Services/.../Parsers/MovimientoEntreCarterasParser.swift` | → par transferencia |
| `Services/.../Parsers/MovimientoSwapParser.swift` | → par swap |
| `Views/Movimientos/MovimientosSalidaView.swift` | @Query tipoRaw=="salida" |
| `Views/Movimientos/MovimientosEntreCarterasView.swift` | filas por par + delete del par |
| `Views/Movimientos/MovimientosSwapsView.swift` | filas por par + delete del par |
| `Views/Movimientos/MovimientoForms.swift` | EditMovementMode + routing por tipo |
| `Views/Admin/CryptoSyncView.swift` | fix build pre-existente |
| Tests (11): `TestHelpers`, `CargaMovimientosTests`, `EliminarDataViewModelTests`, `AdminCarterasViewModelTests`, `AppDependencyContainerTests`, `MovimientoEntradaViewModelTests`, `MovimientoSalidaViewModelTests`, `MovimientoEntreCarterasViewModelTests`, `MovimientoEntradaParserTests`(sin cambios), `MovimientoSalidaParserTests`, `MovimientoEntreCarterasParserTests`, `MovimientoSwapParserTests` | schema + seeds + fetch Movimiento + counts de par |

Nota: `MovimientoEntradaParserTests` no requirió cambios (campos homónimos en Movimiento y count=1).
