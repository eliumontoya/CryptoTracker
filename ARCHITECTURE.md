# Arquitectura de Crypto Tracker

Referencia técnica para cualquier desarrollador (humano o agente IA) que se
incorpore al proyecto. Describe la arquitectura objetivo del sistema.

## Stack

- **Lenguaje**: Swift 5.0+
- **Plataforma**: macOS 14.0+ e iOS 17.0+ (multiplataforma)
- **UI**: SwiftUI (100%, sin UIKit/AppKit)
- **Persistencia**: SwiftData (schema versionado con migraciones explícitas)
- **Concurrencia**: async/await para I/O, Combine para bindings reactivos
- **Dependencias**: CoreXLSX (importación Excel), Swift Charts (gráficos nativos)
- **IDE**: Xcode 16.2+
- **Bundle ID**: emm.Crypto-Tracker

## Arquitectura de alto nivel

```
┌─────────────────────────────────────────────────────────────┐
│                        Views (SwiftUI)                       │
│  NavigationSplitView (macOS) / TabView (iOS) + Sheets       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ViewModels (ObservableObject)             │
│  @Published properties, Combine bindings, async/await       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Use Cases (Domain Layer)                  │
│  RegisterMovementUseCase, EditMovementUseCase,              │
│  DeleteMovementUseCase, SwapMovementUseCase,                │
│  MoveBetweenWalletsUseCase, AdjustHoldingUseCase            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Services (Infrastructure)                 │
│  PriceService, BalanceService, BackupService, ImportService │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Model (SwiftData @Model entities)               │
│  Portfolio, Cartera, Crypto, FIAT, Movimiento, Holding      │
└─────────────────────────────────────────────────────────────┘
```

## Patrón de arquitectura

**MVVM + Clean Architecture** con las siguientes capas:

### Capa de presentación (Views + ViewModels)
- **Views**: componentes SwiftUI reutilizables, sin lógica de negocio.
- **ViewModels**: `ObservableObject` con `@Published` properties, coordinan use cases.
- **Navegación**: `NavigationSplitView` con sidebar (macOS), `TabView` (iOS).
- **Layout adaptable**: usar `@Environment(\.horizontalSizeClass)` para detectar plataforma.
- **Sheets**: para flujos secundarios (formularios, detalles). En iOS usar push navigation o full-screen covers.

### Capa de dominio (Use Cases)
- **Use cases** encapsulan operaciones de negocio completas.
- **Protocolos** para inyección de dependencias y testing.
- **Atomicidad**: cada use case que modifica movimiento + holding lo hace en una transacción.
- **Invariantes**: validación de no-negatividad de holdings, consistencia de balances.

**Use cases del sistema**:
- `RegisterMovementUseCase`: crear movimiento + actualizar holding
- `EditMovementUseCase`: editar movimiento + revertir y aplicar holding
- `DeleteMovementUseCase`: borrar movimiento + revertir holding
- `SwapMovementUseCase`: par swapEntrada + swapSalida con groupId
- `MoveBetweenWalletsUseCase`: par transferenciaEntrada + transferenciaSalida con groupId
- `AdjustHoldingUseCase`: ajuste manual de holding a valor absoluto

### Capa de infraestructura (Services)
- **PriceService**: protocolo para sync de precios (implementación CoinGecko).
- **BalanceService**: consultas de balances materializados (Holding).
- **BackupService**: exportación/importación JSON de todo el portafolio.
- **ImportService**: parsers CSV/Excel para catálogos y movimientos.

### Capa de datos (SwiftData)
- **Entidades @Model** con relaciones y restricciones.
- **ModelContext** inyectado vía `AppDependencyContainer`.
- **Migraciones explícitas** con `SchemaMigrationPlan`.

## Modelo de datos

### Entidades principales

**Portfolio**
- Agrupación de carteras
- `isDefault`: marca el portfolio principal
- Relación uno-a-muchos con `Cartera`

**Cartera** (Wallet)
- Wallet de criptomonedas
- `isMain`: marca la cartera principal dentro de un portfolio (una sola por portfolio)
- Relación muchos-a-uno con `Portfolio`

**Crypto**
- Criptomoneda con precio actual
- `coingeckoId`: identificador para API de precios
- `ultimaActualizacion`: timestamp del último sync

**FIAT**
- Moneda fiat con precio en USD
- Usado para conversiones en movimientos con FIAT alterno

**Holding**
- Balance materializado de una crypto en una cartera
- Índice único compuesto: `portfolioId|carteraId|cryptoId`
- `cantidad >= 0` (invariante)
- Se actualiza atómicamente con cada movimiento

**Movimiento**
- Entidad unificada para todos los tipos de operaciones
- `tipo: TipoMovimiento` enum con 8 valores:
  - `entrada`: compra de crypto
  - `salida`: venta de crypto
  - `transferenciaEntrada`: recepción de transferencia
  - `transferenciaSalida`: envío de transferencia
  - `swapEntrada`: recepción en swap
  - `swapSalida`: envío en swap
  - `ajuste`: corrección manual de balance
  - `comision`: fee de transacción
- `groupId: UUID?` para agrupar pares (swap, transferencia)
- Campos opcionales según el tipo:
  - Transferencias: `carteraOrigen`, `carteraDestino`, `cantidadCryptoOrigen`, `cantidadCryptoDestino`
  - Swaps: `cryptoDestino`, `precioUSDDestino`
  - FIAT alterno: `fiatAlterno`, `precioFiatAlterno`, `valorTotalFiatAlterno`

**PrecioHistorico**
- Histórico de precios de una crypto
- Usado para análisis de rendimiento

**PortfolioSnapshot**
- Snapshot diario del valor del portfolio
- Usado para gráficos de evolución
- Máximo 365 snapshots (un año)

**CryptoSyncConfig**
- Configuración de sync de precios por crypto
- `syncUrl`: endpoint personalizado
- `defaultPrice`: fallback si la API falla

### Reglas de negocio

**Movimientos**
- Crear/editar/borrar movimiento + actualizar holding en una sola transacción atómica.
- Validación de fondos: usar `Holding.cantidad` (materializado), no calcular on-the-fly.
- `groupId` para pares (swap, transferencia) que deben tratarse como una sola operación lógica.
- Comisión en transferencias: `cantidadEnviada - cantidadRecibida`.

**Holdings**
- Balance materializado con índice único `portfolioId|carteraId|cryptoId`.
- Invariante: `cantidad >= 0` siempre. Si una operación viola esto, se revierte.
- Actualización atómica con el movimiento que la causa.

**Multi-portfolio**
- Portfolio agrupa carteras, con `isDefault`.
- Cartera tiene `isMain` (una sola por portfolio).
- Migración: carteras existentes → "Portafolio Principal" default.

## Capa de red

**PriceService** (protocolo)
- Implementación concreta: CoinGecko API gratuita.
- Endpoint: `https://api.coingecko.com/api/v3/simple/price?ids={ids}&vs_currencies=usd`
- Batch fetch: múltiples cryptos en una sola request.
- Rate limiting: max 30 calls/minuto.
- Cache persistente en SwiftData (`PrecioHistorico`).
- Auto-sync configurable (BGTaskScheduler en iOS, Timer en macOS).
- Fallback a `defaultPrice` si la API falla.

## Persistencia

**SwiftData**
- Único mecanismo de persistencia.
- `ModelContainer` creado en `Crypto_TrackerApp.init` con schema versionado.
- Migraciones explícitas con `SchemaMigrationPlan`.
- Sin UserDefaults, Keychain, ni archivos para datos propios.

**Importación**
- CSV: catálogos (carteras, cryptos, FIATs, sync config).
- Excel: movimientos (parsers por tipo).
- `.fileImporter` para selección de archivos (multiplataforma).

**Exportación**
- Backup JSON con todas las entidades.
- `.fileExporter` para guardar archivos.

## UI

**Multiplataforma**
- macOS: `NavigationSplitView` con sidebar.
- iOS: `TabView` con tabs principales.
- Layout adaptable con `@Environment(\.horizontalSizeClass)`.
- Sin frames fijos (`minWidth`/`minHeight`).

**Componentes**
- Design system con tokens de colores, espaciados, tipografía.
- Colores semánticos: `.gain`, `.loss`, `.neutral`, `.primary`.
- Componentes reutilizables: `Card`, `StatCard`, `ChipRow`, `ToggleRow`.

**Gráficos**
- Swift Charts (nativo iOS 16+/macOS 13+).
- Pie chart: distribución de ganancias por crypto.
- Línea de evolución: valor del portfolio en el tiempo.
- Bar charts: distribución por cartera y por crypto.

## Estructura de carpetas

```
Crypto Tracker/
├── App/
│   ├── Crypto_TrackerApp.swift          # @main, ModelContainer
│   ├── AppDependencyContainer.swift     # DI container
│   ├── Assets.xcassets/                 # Iconos y colores
│   └── Crypto_Tracker.entitlements      # Permisos
├── Domain/
│   ├── UseCases/
│   │   ├── Movements/                   # Use cases de movimientos
│   │   ├── Portfolio/                   # Use cases de portfolio
│   │   └── Wallet/                      # Use cases de carteras
│   ├── Queries/                         # Queries de lectura (CQRS-lite)
│   └── Models/                          # Modelos de dominio (no persistidos)
├── Data/
│   ├── Entities/                        # Entidades SwiftData @Model
│   ├── Repositories/                    # Implementaciones de repos
│   └── Migrations/                      # SchemaMigrationPlan
├── Services/
│   ├── PriceService.swift               # Sync de precios
│   ├── BalanceService.swift             # Consultas de balances
│   ├── BackupService.swift              # Export/import JSON
│   └── Import/                          # Parsers CSV/Excel
├── UI/
│   ├── Components/                      # Componentes reutilizables
│   ├── Screens/                         # Pantallas principales
│   │   ├── Portfolio/
│   │   ├── Movements/
│   │   └── Admin/
│   └── ViewModels/                      # ViewModels por pantalla
└── Utilities/
    ├── DesignSystem.swift               # Tokens de diseño
    ├── Formatters.swift                 # Formateo de monedas/fechas
    └── Extensions/                      # Extensiones de Swift
```

## Testing

**Tests unitarios**
- Cobertura de use cases, servicios, y calculadoras.
- Mocks con cálculo real, no valores hardcodeados.
- Coverage objetivo: >70% en capa de dominio.

**Tests de UI**
- Flujos críticos: navegación, CRUDs principales.
- Usan testTags/accessibility identifiers para localizar elementos.

**Previews**
- `PreviewContainer` in-memory con seed de datos de ejemplo.
- No usar el container real en previews.

## Entornos

- **Producción**: App Store (macOS + iOS).
- **Desarrollo**: Xcode 16.2+, macOS 14.0+, iOS 17.0+.
- **Verificación**: `xcodebuild build` y `xcodebuild test` deben pasar limpios.
