# Exploration: 34-unified-movement

Issue #34 — feat(domain): unificar 4 entidades de movimiento en una sola con TipoMovimiento

## Current State

El modelo de datos (Model.swift) tiene 4 entidades `@Model` de movimientos:
- `MovimientoIngreso` (compra): cantidadCrypto, precioUSD, valorTotalUSD, usaFiatAlterno, precioFiatAlterno, valorTotalFiatAlterno, cartera, crypto, fiatAlterno
- `MovimientoEgreso` (venta): mismos campos que Ingreso
- `MovimientoEntreCarteras` (transferencia): cantidadCryptoSalida, cantidadCryptoEntrada, cantidadCryptoComision, carteraOrigen, carteraDestino, crypto
- `MovimientoSwap`: cantidadOrigen, cantidadDestino, precioUSDOrigen, precioUSDDestino, cartera, cryptoOrigen, cryptoDestino

Cada entidad tiene relaciones inversas declaradas en `Cartera`, `Crypto` y `FIAT`
(movimientosIngreso, movimientosEgreso, movimientosSalida, movimientosEntrada, swaps,
swapsComoOrigen, swapsComoDestino). `BalanceCalculator` y los 3 calculadores de portfolio
suman balances recorriendo esas colecciones inversas.

Un `enum TipoMovimiento { ingreso, egreso, entreCarteras, swap }` existe en Model.swift pero es código muerto (0 referencias).

El esquema está en `Crypto_TrackerApp.swift` v3.0.0. La app arranca con `PortfolioMigration.apply`
(migración ligera de datos v2→v3). No hay infraestructura `VersionedSchema`/`SchemaMigrationPlan`.

## Affected Areas

- `Crypto Tracker/Model/Model.swift` — 4 entidades + relaciones inversas
- `Crypto Tracker/Model/{BalanceCalculator,PortfolioCalculatorService,PortfolioCryptoCalculator,MainPortfolioCalculator}.swift` — cálculo de balances/totales sobre las colecciones antiguas
- `Crypto Tracker/App/Crypto_TrackerApp.swift` — schema + bootstrap
- `Crypto Tracker/Model/PreviewContainer.swift` — schema + seed
- `Crypto Tracker/Movimientos/*` — service de entrada, VM de entrada, list VM, view de entrada
- `Crypto Tracker/ViewModels/Movimientos/{Salida,EntreCarteras,Swap}ViewModel.swift` — CRUD por tipo
- `Crypto Tracker/ViewModels/Portfolio/xCartera/*` y `xCryptos/*` — construyen `MovimientoDetalle`
- `Crypto Tracker/Views/Movimientos/*` — listas, formularios, `MovimientoForms` (EditMovementMode)
- `Crypto Tracker/ViewModels/Admin/{AdminCarteras,AdminFiat}ViewModel.swift` — validaciones de borrado
- `Crypto Tracker/ViewModels/Admin/SetupInicial/EliminarDataViewModel.swift` — borrado masivo
- `Crypto Tracker/Services/SetupInicial/CargaMovimientos/*` — 4 services + 4 parsers Excel
- `Crypto TrackerTests/` — 11 archivos (schemas, seeds, mocks, fetch descriptors)

## Approaches

1. **Migración pesada `SchemaMigrationPlan` (VersionedSchema)**
   - Pros: migración declarativa al arrancar, borra tablas viejas
   - Cons: no existe infraestructura de versiones en el repo; el repo usa migración ligera + bootstrap (patrón `PortfolioMigration`); alto riesgo de romper el container
   - Effort: Alto

2. **Entidad unificada + migración de datos en bootstrap (elegido)**
   - Nueva `Movimiento` (todas las columnas de las 4 tablas como opcionales + `tipoRaw` + `groupId`) con cambio aditivo de schema v3→v4 (lightweight migration automática)
   - Clases viejas se conservan DEPRECADAS solo para `MovimientoMigration.apply(in:)` que copia los datos en el primer arranque (idempotente, patrón PortfolioMigration)
   - Transferencia y swap = PAR de registros (pierna salida + pierna entrada) con `groupId` compartido, conservando info completa en cada pierna
   - Calculadores/VM/Views/tests se actualizan a `Movimiento`; se filtran por `tipoRaw` (String persistido, compatible con `#Predicate`)
   - Pros: sigue el patrón ya probado del repo, cambio aditivo sin borrar datos, rollback trivial
   - Cons: requiere tocar ~42 archivos; las tablas viejas permanecen en el schema (vestigiales)
   - Effort: Alto (pero mecánico y verificable)

3. **Solo añadir `Movimiento` sin migrar código existente**
   - Pros: mínimo esfuerzo
   - Cons: no cumple el issue (la app seguiría usando las 4 tablas); deuda duplicada
   - Effort: Bajo (descartado)

## Recommendation

Enfoque 2. `TipoMovimiento: String, Codable` con 8 casos; `Movimiento` con union de campos
+ `tipoRaw` (para predicados SwiftData) + `groupId`. Swap/transferencia = 2 piernas con
`groupId`. Migración de datos idempotente en el arranque. Actualizar TODOS los consumidores
(calculadores, VMs, views, parsers, tests). Compilar primero, corregir después.

## Risks

- SwiftData "circular reference" si se declara `inverse:` en ambos lados de una relación (declarar el inverse solo en el lado colección — patrón ya usado por `PrecioHistorico.crypto`)
- Los tests que siembran balance con las clases viejas quedan ciegos al `BalanceCalculator` unificado (se actualizaron los seeds a `Movimiento.entrada`)
- `MovimientoDetalle` (DTO de display) se mantiene con sus 4 tipos; ajuste/comisión no se renderizan como filas en las vistas de detalle (mismo comportamiento que antes)
- Las 4 tablas viejas permanecen en el schema como vestigio de migración; su limpieza queda para un cambio futuro

## Ready for Proposal

Yes — la exploración está completa y el diseño validado contra el compilador (macOS + iOS) y la suite de tests (0 regresiones vs baseline).
