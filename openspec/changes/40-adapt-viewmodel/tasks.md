# Tasks: Adapt MovimientosEntradaViewModel to movement use cases

**Issue**: #40 — `refactor(ui): adaptar MovimientosEntradaViewModel a use cases`.
Replace the inline `TransactionRunner` + `HoldingService` orchestration in
`MovimientoEntradaViewModel` with the 3 domain use cases from
`Domain/UseCases/Movements/` (Register #37, Edit #38, Delete #39).

## Phase 1: Exploration

- [x] 1.1 **Read current VM** — `MovimientosEntradaViewModel.swift`: `save()` inlines
      edit (snapshot + mutate + `updateHoldingForMovement(_:previous:in:)`) and create
      (`Movimiento.entrada` + insert + `updateHoldingForMovement(_:in:)`) inside
      `transactionRunner.run`; `delete()` inlines revert + `context.delete`. Init takes
      optional `transactionRunner`/`holdingService` defaulted to
      `ModelContextTransactionRunner` + `HoldingService`.
- [x] 1.2 **Read the 3 use cases** — `RegisterMovementUseCase` (protocol
      `register(_:) -> Movimiento`), `EditMovementUseCase` (protocol `execute(_:)` with
      `EditMovementInput(movement:updated:)`), `DeleteMovementUseCase` (protocol
      `delete(_:)`). All internal structs, all already wired in
      `AppDependencyContainer` as `registerMovementUseCase`/`editMovementUseCase`/
      `deleteMovementUseCase`.
- [x] 1.3 **Approach chosen** — optional init params with defaults, mirroring the
      existing `transactionRunner`/`holdingService` convention: container injects the
      shared use cases explicitly; tests, `MovimientosEntradaListViewModel`, and
      `PortfolioPorCryptosViewModel` keep compiling untouched.

## Phase 2: Implementation

- [x] 2.1 **`Crypto Tracker/Movimientos/MovimientosEntradaViewModel.swift`** —
      Replaced `transactionRunner` + `holdingService` properties with
      `registerUseCase`/`editUseCase`/`deleteUseCase` (protocol types). Init accepts
      them as optional params, defaulting to use cases built from one shared
      `ModelContextTransactionRunner` + `HoldingService`.
- [x] 2.2 **save() → use cases** — edit path calls
      `editUseCase.execute(EditMovementInput(movement:updated:))` mapping form fields
      into `EditMovementValues` (`crypto` before `cartera` per the value struct);
      create path calls `registerUseCase.register(RegisterMovementInput(...))` and
      stores the returned `Movimiento` in `self.movimiento`.
- [x] 2.3 **delete() → use case** — `deleteUseCase.delete(movimiento)` then
      `unloadMovimiento()` + `.success`; same `defer { isLoading = false }` and error
      handling preserved.
- [x] 2.4 **UI state preserved** — all `@Published` form/state properties, Combine
      bindings (`setupBindings`), `formIsValid`, `precioFiatAlterno`,
      `validateForm()`, `loadMovimiento`/`unloadMovimiento` unchanged.
- [x] 2.5 **`Crypto Tracker/App/AppDependencyContainer.swift`** — both creation sites
      (shared `movimientoEntradaViewModel` + `makeMovimientoEntradaViewModel`) now
      inject `registerMovementUseCase`/`editMovementUseCase`/`deleteMovementUseCase`.
- [x] 2.6 **No test changes needed** — optional init params keep the 3 test
      instantiation sites, `MovimientosEntradaListViewModel`, and
      `PortfolioPorCryptosViewModel` compiling unchanged.

## Phase 3: Verification

- [x] 3.1 **macOS build compiles** — `xcodebuild build -scheme "Crypto Tracker"
      -destination "platform=macOS"` → BUILD SUCCEEDED (0 errors, only pre-existing
      preview warnings).
- [x] 3.2 **Test target builds** — `xcodebuild build-for-testing` → TEST BUILD
      SUCCEEDED.
- [x] 3.3 **MovimientoEntradaViewModelTests** — 9/9 pass (serial
      `-parallel-testing-enabled NO`), identical on baseline and after the change.
- [x] 3.4 **AppDependencyContainerTests** — 9/9 pass (serial), identical on baseline
      and after the change.
- [x] 3.5 **No regressions from change** — Swift Testing suites
      (Register/Edit/DeleteMovementUseCaseTests) are flaky under CLI in this Xcode
      26.x environment: fatal SwiftData "Already have an objectID registered" crash
      in ModelCoders reproduces identically on BASELINE (change stashed), so it is
      pre-existing/environmental, not a regression. When they execute cleanly they
      pass (Register 5/5 observed; Delete 4/4 in #39's session).

## Notes

- Behavioral deltas adopted deliberately (use cases are the new source of truth):
  register stamps `holding.updatedAt = movimiento.fecha`; edit/delete pre-validate
  holding non-negativity and throw Spanish `EditMovementError` /
  `DeleteMovementError` instead of the silent `Holding.cantidad` clamp. Error strings
  flow through the existing `errorMessage`/`hasError` UI unchanged.
- `MovimientosEntradaListViewModel`/`PortfolioPorCryptosViewModel` keep their own
  default-constructed services — out of scope, unchanged behavior.
- Test invocation quirk: the scheme's test target is `"Crypto TrackerTests"` (with a
  space); `-only-testing:"Crypto TrackerTests/<Suite>"` is required.
- Diff: 2 files, +46/−37 lines — far below the 400-line review budget.
