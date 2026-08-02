# Tasks: 42-register-exit-usecase

Issue #42 — feat(domain): RegisterMovementUseCase (salida) con validación de fondos

Extend `RegisterMovementUseCase` to support `.salida` movements with the same atomic
movement + holding pattern as `.entrada`, but validating that the wallet holds enough
crypto before subtracting.

## Implement

- [x] I1. `Domain/UseCases/Movements/RegisterMovementUseCase.swift` — generalize
      `RegisterMovementInput` comment for entry/exit movements
- [x] I2. `Domain/UseCases/Movements/RegisterMovementUseCase.swift` — add
      `RegisterMovementError.insufficientHoldings` (LocalizedError, Equatable)
- [x] I3. `Domain/UseCases/Movements/RegisterMovementUseCase.swift` — add
      `RegisterMovementUseCaseProtocol.registerSalida(_:)` requirement
- [x] I4. `Domain/UseCases/Movements/RegisterMovementUseCase.swift` — implement
      `RegisterMovementUseCase.registerSalida` using `Movimiento.salida`,
      validating `holding.cantidad >= cantidadCrypto` before the transaction
      commits, then applying the negative holding delta via `HoldingService`
      and stamping `holding.updatedAt` with the movement date
- [x] I5. `Crypto TrackerTests/RegisterMovementUseCaseTests.swift` — add tests for
      successful salida, holding deletion at zero, missing holding, insufficient
      funds, FIAT alterno, and rollback on validation failure

## Verify

- [x] V1. `xcodebuild build` → BUILD SUCCEEDED
- [x] V2. `xcodebuild test` targeted suite `RegisterMovementUseCaseTests` → passes

## Files changed

| File | Change |
|------|--------|
| `Crypto Tracker/Domain/UseCases/Movements/RegisterMovementUseCase.swift` | Added error enum, `registerSalida` protocol method + implementation, validation helper |
| `Crypto TrackerTests/RegisterMovementUseCaseTests.swift` | Added 6 tests for `.salida` registration |

## Notes

- `HoldingService` already produces the negative delta for `.salida`; the new use case
  adds the domain-level funds guard so an oversale fails fast instead of silently
  clamping the holding to zero.
- The validation is performed inside the same `TransactionRunner` block so the check
  and the mutation are atomic.
- `MovimientoSalidaViewModel` still contains its own inline salida logic; wiring it to
  the new use case is left for a follow-up refactor.
