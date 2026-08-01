# Project Context — Crypto Tracker

## Stack
- **Language**: Swift 6.3.3 (arm64-apple-macosx26.0)
- **Framework**: SwiftUI + SwiftData
- **Build**: Xcode project (.xcodeproj), no SPM Package.swift
- **Platform**: macOS desktop (future iOS)

## Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **DI**: `AppDependencyContainer` — manual dependency injection via constructor
- **Persistence**: SwiftData (`ModelContainer`, `ModelContext`, schema versioning at v2.0.0)
- **Folder structure**:
  - `App/` — App entry point, DI container
  - `Views/` — SwiftUI views organized by domain (Portfolio, Movimientos, Admin)
  - `ViewModels/` — ViewModels organized by domain
  - `Model/` — SwiftData models, calculators, extensions
  - `Services/` — Business logic services (SetupInicial, CargaMovimientos, Parsers)
  - `Utilities/` — Shared utilities and error types

## Domain Model
- `FIAT` — Fiat currencies (USD, EUR, MXN)
- `Crypto` — Cryptocurrencies (BTC, ETH, SOL)
- `Cartera` — Wallets/portfolios (Binance, MetaMask, Phantom)
- `MovimientoIngreso` — Buy/deposit movements
- `MovimientoEgreso` — Sell/withdraw movements
- `MovimientoEntreCarteras` — Transfer between wallets
- `MovimientoSwap` — Crypto-to-crypto exchange
- `PrecioHistorico` — Historical prices
- `CryptoSyncConfig` — Sync configuration

## Testing
- **Framework**: Swift Testing (`import Testing`, `@Test` macro)
- **Test target**: `Crypto TrackerTests`
- **Test files**: 18 test files covering ViewModels, Parsers, Services
- **Mocks**: `TestSetup.createModelContext()` for in-memory SwiftData context, `EntityMocks` for mock entities
- **Strict TDD**: NOT supported from CLI
  - `xcodebuild` unavailable (active developer directory is CommandLineTools, not Xcode)
  - `swift test` unavailable (no Package.swift)
  - Tests must be run from Xcode IDE

## Conventions
- Code comments and UI strings in Spanish
- Domain model named in Spanish (Cartera, Movimiento, etc.)
- ViewModels follow `{Domain}ViewModel` naming
- Views follow `{Domain}View` naming
- Services follow `{Domain}Service` naming with protocol definitions

## Risks
- CLI test execution requires `sudo xcode-select -s /Applications/Xcode.app` or equivalent
- No shared Xcode schemes — schemes are user-specific only
- Swift 6.3 strict concurrency may affect parallelism patterns
