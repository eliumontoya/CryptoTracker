# Exploration: fix(tests) — arreglar tests rotos y mocks inexactos

## Current State

The test target `Crypto TrackerTests` has 4 broken/misaligned files. The root causes are:
1. A local redeclaration of the app's `CargaMovimientosDelegate` protocol with a WRONG signature.
2. A mock that hardcodes `getCryptoDisponible` instead of using the real calculation.
3. Test schema definitions missing SwiftData entities (unresolved relationships crash `ModelContainer`).
4. `PreviewContainer` schema missing `CryptoSyncConfig` (app schema v2.0.0 includes it).

## Affected Areas

- `Crypto TrackerTests/CargaMovimientosTests.swift` — redeclared protocol + incomplete setUp schema
- `Crypto TrackerTests/Mocks/EntityMocks.swift` — hardcoded `getCryptoDisponible` mock
- `Crypto TrackerTests/Mocks/TestHelpers.swift` — `createModelContext` missing 5 entities
- `Crypto Tracker/Model/PreviewContainer.swift` — schema missing `CryptoSyncConfig`

## Findings

### a) CargaMovimientosTests.swift — protocol redeclared with wrong signature (L261–267)

Local redeclaration:
```swift
protocol CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String)
    func didCompleteTask(_ task: String, total: Int)   // L265 — label "task"
    func didReceiveErrorMessage(_ error: Error)        // L266 — wrong name
}
```

Real protocol (`Services/SetupInicial/CargaMovimientos/CargaMovimientosDelegate.swift` L3–7):
```swift
protocol CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String)
    func didCompleteTask(_ type: String, total: Int)   // label "type"
    func didEncounterError(_ error: Error)             // name "didEncounterError"
}
```

**Fix**:
- Delete L261–267 (the app protocol is visible via `@testable import`; redeclaring = `invalid redeclaration`).
- Update mock (L243–259) to conform to the real protocol: L252 `didCompleteTask(_ type: String, total: Int)`; L256 rename to `didEncounterError(_ error: Error)`.

**Additional issues in this file** (out of the 4-file scope but same file):
- setUp schema (L15–23) missing `PrecioHistorico` and `CryptoSyncConfig` → `try! ModelContainer` crashes (Crypto ↔ PrecioHistorico relationship unresolved).
- `testCargaMovimientosEntradaConDatosInvalidos` asserts `mockDelegate.didReceiveError` (L97) but services never call `didEncounterError` — they throw (`try await`). Assertion will fail regardless of protocol fix.

### b) EntityMocks.swift — hardcoded getCryptoDisponible (L28–32)

```swift
func getCryptoDisponible(crypto: Crypto, movimientoActual: Decimal? = nil) -> Decimal {
    return 100   // hardcoded
}
```

Real implementation (`Model/CarteraExtension.swift` L4–31):
```swift
func getCryptoDisponible(crypto: Crypto, movimientoActual: Decimal = 0) -> Decimal {
    // ingresos + transferenciasEntrada + swapsEntrada + movimientoActual
    //   - (egresos + transferenciasSalida + swapsSalida)
}
```

Problems:
- `Decimal? = nil` vs real `Decimal = 0` → overload; calls omitting `movimientoActual` become **ambiguous** (both have defaults).
- Hardcoded `100` violates AGENTS.md ("Mocks deben usar el cálculo real, no valores hardcodeados").

**Fix**: Delete L28–32 entirely. The real method is available to tests via `@testable import`; `Crypto.mock`/`Cartera.mock`/`FIAT.mock` factories are legitimate and stay.

### c) TestHelpers.swift — createModelContext missing entities (L9–19)

Schema only registers 4: `Crypto`, `Cartera`, `FIAT`, `MovimientoEgreso`.
Missing 5: `MovimientoIngreso`, `MovimientoEntreCarteras`, `MovimientoSwap`, `PrecioHistorico`, `CryptoSyncConfig`.

`Cartera` relationships reference all movement types (Model.swift L116–120); `Crypto` references `PrecioHistorico`/`MovimientoSwap` (L57–61). Unresolved relationship → `try! ModelContainer` crash.

**Fix**: register all 9 entities in `createModelContext`.

### d) PreviewContainer.swift — missing CryptoSyncConfig (L12–21)

Schema has 8 entities, missing `CryptoSyncConfig`. App container (`App/Crypto_TrackerApp.swift` L13–23) includes it.

**Fix**: add `CryptoSyncConfig.self` to the schema.

## Entity Inventory (9 total)

- `Model.swift` defines 8: `FIAT` (L20), `Crypto` (L45), `PrecioHistorico` (L89), `Cartera` (L106), `MovimientoIngreso` (L135), `MovimientoEgreso` (L179), `MovimientoEntreCarteras` (L223), `MovimientoSwap` (L253).
- The 9th — `CryptoSyncConfig` — is in `Model/CryptoSyncConfigModel.swift` (L5–18), a separate file.

## Approaches

1. **Minimal surgical fix (recommended)** — delete the bogus protocol redeclaration and mock override, add missing entities to the 3 schemas, fix the mock's signature labels.
   - Pros: matches real behavior, resolves ambiguity + redeclaration compile errors, small diff
   - Cons: `didReceiveError` assertion (L97) still needs a decision
   - Effort: Low

2. **Refactor tests to Swift Testing + fix mocks** — rewrite the broken test file entirely.
   - Pros: aligns with project-context.md (Swift Testing)
   - Cons: much larger diff, out of scope for a "fix broken tests" issue
   - Effort: High

## Recommendation

Approach 1. Fix the 4 files exactly as described. Additionally decide on the L97 assertion: either drop it (service throws instead of notifying) or have the service call `didEncounterError` before throwing.

## Risks

- `testCargaMovimientosEntradaConDatosInvalidos` L97 assertion will still fail after the protocol fix — needs a follow-up decision (service notification vs assertion removal).
- PreviewContainer/TestHelpers schema changes are safe but must keep entity count consistent (9) across all containers to avoid runtime crashes.

## Ready for Proposal

Yes — all 4 issues have exact locations and fixes. The orchestrator should also flag the L97 assertion decision (drop vs service-side `didEncounterError` call) to the user.
