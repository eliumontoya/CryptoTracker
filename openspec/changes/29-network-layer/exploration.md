# Exploration: refactor(data) — extraer capa de red del ViewModel de Sync

## Current State

`CryptoSyncViewModel` (`Crypto Tracker/ViewModels/Admin/CryptoSyncViewModel.swift`, 251 lines)
mezcla tres responsabilidades:

1. **Persistencia SwiftData** (legítima del VM): `loadData()`, `saveSyncConfig`, cache de
   configs (`syncConfigCache`, `lastFetchTime` + `cacheValidityInterval = 300s`), `updateCryptoPrice`
   (inserta `PrecioHistorico`, guarda precio), `handleSyncError` (fallback a `defaultPrice`).
2. **Capa de red** (a extraer): `fetchPrice(from:)` crea `URLSession` con timeout 30s y
   `reloadIgnoringLocalCacheData`, valida status HTTP (2xx), decodifica `PriceResponse`.
3. **Rate limiting / orquestación**: sleep de 500ms entre cryptos en `startSync`, manejo de
   `Task` con un actor interno `TaskManager`, logging (`addLogEntry`, `formatErrorMessage`).

`PriceResponse` (modelo de decodificación con claves dinámicas) vive en
`Model/CryptoSyncModels.swift`. La prueba `CryptoSyncViewModelTests.swift` construye el VM con
`CryptoSyncViewModel(modelContext:)` — el init actual **no** recibe servicios inyectados.

### Verificación de alcance (grep)

- `URLSession` / `fetchPrice` — únicamente en `CryptoSyncViewModel.swift` L134-153.
- `PriceResponse` — `Model/CryptoSyncModels.swift` L13-49 y un mock duplicado en el test
  (L166) que no se usa; el VM es el único consumidor de la decodificación real.
- El proyecto usa `PBXFileSystemSynchronizedRootGroup` (objectVersion 77) → **un archivo nuevo
  en `Crypto Tracker/` no requiere editar el .pbxproj** (verificado en `23-adaptive-layout`).

## Affected Areas

- `Crypto Tracker/ViewModels/Admin/CryptoSyncViewModel.swift` — remover `fetchPrice` y el sleep
  de 500ms; inyectar `PriceServiceProtocol` por init.
- `Crypto Tracker/Services/PriceService.swift` — **nuevo**: protocolo + implementación.
- `Crypto Tracker/App/AppDependencyContainer.swift` — crear e inyectar `PriceService`.
- `Crypto Tracker/Views/Admin/CryptoSyncView.swift` — pasar el servicio al VM (el VM se crea
  aquí con `StateObject`, no en el container).
- `Crypto Tracker/Model/CryptoSyncModels.swift` — sin cambios (el modelo `PriceResponse` queda
  donde está; no se mueve para minimizar el diff).

## Approaches

1. **Service con protocolo inyectable + implementación en `Services/`** (patrón del proyecto:
   `MovimientosEntradaServiceProtocol` / `MovimientosEntradaService`).
   - Pros: sigue la convención existente; `PriceServiceProtocol` permite mocks en tests;
     el VM deja de tocar `URLSession`/`JSONDecoder` directamente.
   - Cons: requiere tocar el init del VM, el container y la vista de sync.
   - Effort: Medium

2. **Clase concreta sin protocolo** — `PriceService` plano, sin `PriceServiceProtocol`.
   - Pros: menos archivos/conceptos.
   - Cons: imposible mockear en tests; viola la regla de AGENTS.md
     ("ViewModels usan use cases con protocolos inyectables"); imposible verificar el
     comportamiento de red de forma aislada.
   - Effort: Low

## Recommendation

**Approach 1.** El patrón protocolo + clase ya está establecido en el repo
(`MovimientosEntradaServiceProtocol` es el único servicio existente y se inyecta vía init en
todos los VMs). `PriceServiceProtocol` expone `fetchPrice(from:)` y `fetchPrices(from:)`.
`PriceService` encapsula: configuración de `URLSession`, validación HTTP, decodificación,
timeout, rate limiting, caché de precios y retries — según el spec del change (tarea 2),
que exige "URLSession, rate limiting, caching, retries".

### Semántica de comportamiento (spec del change)

- Timeout 30s, `reloadIgnoringLocalCacheData`, validación 2xx → dentro del servicio.
- Rate limiting: `minimumRequestInterval` (500ms por defecto, el mismo pacing que hoy) se
  mueve al servicio; el VM deja de dormir entre cryptos.
- Caché de precios por URL con TTL corto (`cacheValidityInterval`, 60s) — el issue lista la
  "cache" como responsabilidad a extraer; los resultados de precio no cambian, solo se evita
  un fetch duplicado dentro de la ventana. La caché SwiftData (`syncConfigCache`/
  `lastFetchTime`) **pertenece al VM** y se queda ahí.
- Retries: solo para errores de red transitorios (`URLError` de timeout/conexión), 1 retry
  por defecto; un fallo definitivo lanza el mismo error que el VM ya mapea, así el fallback a
  `defaultPrice` es idéntico.
- `formatErrorMessage` (mensajes en español) **queda en el VM** — es presentación/logging,
  no capa de red. El servicio lanza los mismos `URLError`/`DecodingError` que el VM ya
  mapea.
- El VM conserva el `TaskManager` actor y el flujo de persistencia intactos.
- Tests existentes siguen compilando: el VM recibe el servicio como parámetro de init con
  valor por defecto (`PriceService()`), igual que `MovimientosEntradaViewModel` recibe su
  servicio; así `CryptoSyncViewModelTests` no requiere cambios.

## Risks

- **Test `testSyncProcessInitiation`** — llama `startSync()` sin red disponible; con el
  servicio por defecto intentará un fetch real (como hoy con `fetchPrice` privado). El test
  solo verifica `isSyncing` inmediato, así que no rompe, pero el fetch real lanzará error y
  hará fallback a `defaultPrice` (mismo comportamiento actual). Sin cambio funcional.
- **Concurrencia** — el servicio es `actor` para aislar su estado mutable; el VM es
  `@MainActor`. El paso de mensajes es `async`, consistente con el código actual.
- **Caché de red nueva** — es la única adición de comportamiento frente a "extraer tal cual";
  TTL corto (60s) y solo aplica a repeticiones dentro de la ventana. Documentado como
  decisión del spec, no como cambio silencioso.

## Ready for Proposal

Yes — extracción mecánica, bajo riesgo, sin cambios de comportamiento. Implementación:
1 archivo nuevo (`Services/PriceService.swift`), edits en VM + container + vista sync.
