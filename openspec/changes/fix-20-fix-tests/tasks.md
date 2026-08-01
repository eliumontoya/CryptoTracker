# Tasks — fix(tests): arreglar tests rotos y mocks inexactos

Issue: #20

## Phase 1: Fix delegate protocol mismatch in `CargaMovimientosTests.swift`

- [x] 1.1 Add missing `PrecioHistorico` and `CryptoSyncConfig` to the `setUp` `ModelContainer` schema so all 9 entities are registered.
- [x] 1.2 Update `MockCargaMovimientosDelegate`:
  - Rename `didCompleteTask(_ task: String, total: Int)` to `didCompleteTask(_ type: String, total: Int)`.
  - Rename `didReceiveErrorMessage(_ error: Error)` to `didEncounterError(_ error: Error)`.
- [x] 1.3 Remove the local redeclaration of `CargaMovimientosDelegate` (lines 261–267).
- [x] 1.4 Change `XCTAssertTrue(mockDelegate.didReceiveError)` (L97) to `XCTAssertFalse` because the service throws on invalid data instead of notifying the delegate.

## Phase 2: Fix hardcoded mock in `EntityMocks.swift`

- [x] 2.1 Delete the `Cartera.getCryptoDisponible(...)` test override (lines 28–33) so tests use the real implementation from `CarteraExtension.swift` via `@testable import`.

## Phase 3: Fix incomplete schema in `TestHelpers.swift`

- [x] 3.1 Register all 9 entities in `TestSetup.createModelContext`:
  `Crypto`, `Cartera`, `FIAT`, `MovimientoIngreso`, `MovimientoEgreso`, `MovimientoEntreCarteras`, `MovimientoSwap`, `PrecioHistorico`, `CryptoSyncConfig`.

## Phase 4: Fix `PreviewContainer.swift`

- [x] 4.1 Add `CryptoSyncConfig.self` to the `PreviewContainer` schema to match the app container.
