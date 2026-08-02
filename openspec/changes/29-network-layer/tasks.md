# Tasks: refactor(data) — extraer capa de red del ViewModel de Sync (Issue #29)

## Scope
- `CryptoSyncViewModel` contenía URLSession, fetchPrice, parsing JSON, rate limiting y caché
  en ~400 líneas. Extraer todo eso a `PriceService` con protocolo `PriceServiceProtocol`.

## Implementación

- [x] 1. Leer `ViewModels/Admin/CryptoSyncViewModel.swift` — identificar código de red,
      parsing y rate limiting (líneas 134-153, sleep 500ms en `startSync`).
- [x] 2. Crear `Crypto Tracker/Services/PriceService.swift`:
      - `protocol PriceServiceProtocol` con `fetchPrice(from:) async throws -> Double`
        y `fetchPrices(from:) async throws -> [String: Double]`.
      - `actor PriceService` implementando: URLSession (timeout 30s,
        `reloadIgnoringLocalCacheData`), validación HTTP 2xx, decodificación `PriceResponse`,
        rate limiting (`minimumRequestInterval` 0.5s), caché de precios por URL (TTL 60s)
        y retry (1 reintento en errores de red transitorios).
- [x] 3. Refactorizar `CryptoSyncViewModel`:
      - `init(modelContext:priceService:)` con `PriceServiceProtocol` inyectado
        (default `PriceService()` para no romper call sites/tests existentes).
      - Eliminar `fetchPrice(from:)`, la configuración de URLSession y el sleep de 500ms
        (el rate limiting ahora vive en el servicio).
      - `syncCrypto` usa `priceService.fetchPrice`; `formatErrorMessage` y el flujo de
        persistencia (PrecioHistorico, fallback defaultPrice) quedan intactos.
- [x] 4. `AppDependencyContainer`: añadir `let priceService: PriceServiceProtocol`
      inicializado como `PriceService()` y expuesto para inyección.
- [x] 5. `CryptoSyncView` acepta `priceService` (default `PriceService()`); `ContentView`
      pasa `dependencies.priceService` en ambos call sites (macOS sidebar + iOS TabView).
- [x] 6. Verificar build macOS (Debug) → SUCCEEDED, sin warnings nuevos en archivos tocados.
- [x] 7. Verificar build iOS Simulator → SUCCEEDED (ContentView compartido).
- [x] 8. Verificar test target compila: único fallo es `CargaMovimientosTests.swift`
      (main-actor isolation) — pre-existente, ajeno a este cambio.
- [x] 9. Actualizar este tasks.md y guardar progreso en Engram
      (`sdd/29-network-layer/apply-progress`, project `cryptotracker`).

## Verificación
- `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` → **BUILD SUCCEEDED**.
- `xcodebuild build -scheme "Crypto Tracker" -destination "generic/platform=iOS Simulator"` → **BUILD SUCCEEDED**.
- `xcodebuild build-for-testing` → falla solo por `CargaMovimientosTests.swift` (Swift 6
  main-actor isolation), pre-existente en base (documentado en change #23).

## Notas
- El pbxproj usa `PBXFileSystemSynchronizedRootGroup` → el archivo nuevo no requiere editar
  el proyecto (mismo patrón que change #23).
- `PriceService` es un `actor` (mismo patrón que `TaskManager` interno del VM) — el VM
  `@MainActor` lo consume con `await`.
- Comportamiento idéntico: timeout 30s, política de caché de URLSession, validación 2xx,
  pacing 500ms entre cryptos y mensajes de error en español (`formatErrorMessage`).
- Adición de comportamiento pedida por el spec: caché de precios (TTL 60s) y 1 retry en
  errores de red transitorios — solo afectan repeticiones dentro de la ventana de caché.
