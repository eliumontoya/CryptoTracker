# fix-18-remove-adhoc-containers

Refactor the four views that create ad-hoc `ModelContainer`s in their initializers so they use the injected `ModelContext` instead.

## Tasks

- [x] 1. `Crypto Tracker/Views/Admin/CryptoSyncView.swift`
  - Remove `try! ModelContainer(for: Crypto.self)` and ad-hoc `ModelContext` creation.
  - Change `init()` to `init(modelContext: ModelContext)` and pass the context to `CryptoSyncViewModel`.

- [x] 2. `Crypto Tracker/Views/Portfolio/xCartera/PortfolioDetalleView.swift`
  - Remove `try! ModelContainer(for: Cartera.self)` and ad-hoc `ModelContext` creation.
  - Change `init()` to `init(modelContext: ModelContext)` and pass the context to `PortfolioDetalleViewModel`.
  - Update `#Preview` to pass `PreviewContainer.shared.context`.

- [x] 3. `Crypto Tracker/Views/Portfolio/xCartera/CarteraMovimientosView.swift`
  - Remove `try! ModelContainer(for: Cartera.self)` and ad-hoc `ModelContext` creation.
  - Change `init(cartera:)` to `init(cartera:modelContext:)` and pass the context to `CarteraMovimientosViewModel`.

- [x] 4. `Crypto Tracker/Views/Movimientos/MovimientoForms.swift`
  - Add `@Environment(\.modelContext) private var modelContext` to `EditMovimientoView`.
  - Replace the three `ModelContext(try! ModelContainer(for: ...))` creations with `modelContext`.

- [x] 5. Update call sites to pass the injected `modelContext`
  - `ContentView`: `PortfolioDetalleView(modelContext:)` and `CryptoSyncView(modelContext:)`.
  - `PortfolioViewsComponents`: `CarteraMovimientosView(cartera:modelContext:)`.

- [x] 6. Verify no remaining `ModelContainer(try!` or `ModelContainer(for:` in the four affected files.

## Notes

- The original instruction suggested using `@Environment(\.modelContext)` directly inside the `init` of `StateObject`-based views. That pattern does not compile because `@Environment` is not available until the view body is evaluated; `StateObject` initialization would require `self` before all stored properties are initialized.
- The implemented fix uses the same injected context (`modelContext` from the environment at the call site) but passes it through the initializer, which is the pattern already used by the other admin views (`AdminCryptosView`, `AdminCarterasView`, etc.).
- `EditMovimientoView` is the only one of the four where the view models are created inside `body`, so it can correctly use `@Environment(\.modelContext)` there.
