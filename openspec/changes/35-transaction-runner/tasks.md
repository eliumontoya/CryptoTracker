# Tasks: TransactionRunner — movement ↔ holding atomicity

**Issue**: #35 — `feat(domain): implementar atomicidad movimiento ↔ holding (TransactionRunner)`.
Introduce a `TransactionRunner` protocol that guarantees movement + holding updates persist atomically by wrapping SwiftData's atomic `ModelContext.save()` with proper error handling.

## Phase 1: TransactionRunner

- [x] 1.1 **`Crypto Tracker/Services/Domain/TransactionRunner.swift`** — Create `protocol TransactionRunner { func run<T>(_ block: (ModelContext) throws -> T) async throws -> T }` exactly as specified in the issue.
- [x] 1.2 **`ModelContextTransactionRunner`** — Create `struct ModelContextTransactionRunner: TransactionRunner` holding the injected `ModelContext`; `run` executes the block, calls `try modelContext.save()` on success, and propagates any thrown error (nothing is persisted on failure).

## Phase 2: Verification

- [x] 2.1 **Fix pre-existing build break** — `CryptoSyncView.swift` stray `}` at line 10 (blocks every build on this branch; same bug fixed on #33/#34, never merged to main). Drive-by 1-line fix.
- [x] 2.2 **macOS build compiles** — `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` succeeds (0 errors).
- [x] 2.3 **Test target builds** — `xcodebuild build-for-testing` succeeds (0 errors).
- [x] 2.4 **Focused tests pass** — `TransactionRunnerTests` 3/3 green: block result returned; mutations persisted on success; block-throw triggers `rollback()` + error propagation (test FAILED before rollback was added — proven RED→GREEN).
- [x] 2.5 **No regressions** — full suite: 20 failures, all pre-existing in 6 baseline suites (CargaCatalogos, CargaMovimientos, CargaMovimientosViewModel, EliminarData, MovimientoEntreCarteras, MovimientoSalida); TransactionRunnerTests 3/3 pass.

## Notes

- `Services/Domain/` is a new folder; Xcode 16+ `PBXFileSystemSynchronizedRootGroup` auto-registers the new file — no pbxproj edit.
- Branch base `26fea14` predates #33 (Holding) and #34 (unified Movimiento); `TransactionRunner` is generic over `ModelContext`, so it is independent of those merges.
- Rewiring the 4 `CargaMovimientos*` services and 3 movement ViewModels to use the runner is a follow-up, out of scope here.
- **Rollback discovered as required**: a failing block leaves pending inserts in the context; without `modelContext.rollback()` in the catch path, a later `save()` persists the partial write. The rollback test fails on the naive implementation and passes with rollback.
- `TransactionRunnerTests.swift` added under `Crypto TrackerTests/` (auto-registered; uses `TestSetup.createModelContext()` in-memory pattern).
