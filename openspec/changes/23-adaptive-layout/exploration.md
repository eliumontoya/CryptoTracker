# Exploration: Layout adaptable — NavigationSplitView → TabView en iOS

## Current State

`Crypto Tracker` es un target multiplataforma (macOS 14+ / iOS 17+, configurado en #80).
El app compila para iOS hoy (verificado con `xcodebuild -destination iOS Simulator`), pero
el layout está roto en iPhone: `ContentView` fuerza un `NavigationSplitView` con sidebar y
los sheets/forms aplican mínimos de 500×700 (o 300×200 en Admin), que desbordan la pantalla
de un iPhone.

### ContentView.swift (167 líneas, único NavigationSplitView del app)

- `NavigationSplitView { List ... } detail: { PortfolioView() }`.
- La sidebar lista 3 secciones: Portfolio (Portafolio, Portafolio por Cryptos, Desglose por
  Carteras), Movimientos (Entrada, Salida, Entre Carteras, Swaps) y Administración (Cryptos,
  Carteras, FIAT, Sync Manual de Precios, Setup Inicial) usando `NavigationLink(destination:
  tag:selection:)` y `DisclosureGroup` con `SidebarListStyle`.
- Estado: `selectedMainMenu`, `selectedAdminMenu`, `selectedMovimientosMenu`.
- Las vistas destino ya son multiplataforma (PortfolioView, PortfolioPorCryptosView,
  PortfolioDetalleView, Movimientos*View, Admin*View, SetupInicialView) — el único código
  macOS-only del árbol está en CryptoSyncView y ya tiene guard `#if os(macOS)`.

### Frames hardcodeados (22 sitios en 12 archivos)

| Patrón | Sitios | Archivos |
|---|---|---|
| `.frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)` | 4 | MovimientoEntradaFormView, MovimientoSalidaFormView, MovimientoSwapFormView, MovimientoEntreCarterasFormView |
| `.frame(minWidth: 500, minHeight: 700)` | 15 | PortfolioViewsComponents (×4), MovimientosSwapsView (×2), MovimientosSalidaView (×2), MovimientosEntreCarterasView (×2), MovimientoForms (×1), PortfolioPorCryptosView (×4) |
| `.frame(minWidth: 300, minHeight: 200)` | 3 | AdminCryptosView (CryptoFormView), AdminFiatView (FiatFormView), AdminCarterasView (CarteraFormView) |

Todos son contenedores de sheets (NavigationStack dentro de `.sheet`) o contenido de forms.
El pbxproj usa `PBXFileSystemSynchronizedRootGroup` → un archivo Swift nuevo en
`Crypto Tracker/` se compila sin editar el proyecto.

## Affected Areas

- `Views/Main/ContentView.swift` — switch de layout por `horizontalSizeClass`.
- `Movimientos/MovimientoEntradaFormView.swift` — frame del form.
- `Views/Movimientos/Forms/MovimientoSalidaFormView.swift` — frame del form.
- `Views/Movimientos/Forms/MovimientoSwapFormView.swift` — frame del form.
- `Views/Movimientos/Forms/MovimientoEntreCarterasFormView.swift` — frame del form.
- `Views/Portfolio/xCartera/PortfolioViewsComponents.swift` — frames de sheets (×4).
- `Views/Portfolio/xCryptos/PortfolioPorCryptosView.swift` — frames de sheets (×4).
- `Views/Movimientos/MovimientosSwapsView.swift` — frames de sheets (×2).
- `Views/Movimientos/MovimientosSalidaView.swift` — frames de sheets (×2).
- `Views/Movimientos/MovimientosEntreCarterasView.swift` — frames de sheets (×2).
- `Views/Movimientos/MovimientoForms.swift` — frame de sheet (edición de movimiento).
- `Views/Admin/AdminCryptosView.swift`, `Views/Admin/AdminFiatView.swift`,
  `Views/Admin/AdminCarterasView.swift` — frames de forms de Admin (300×200).
- Nuevo: `Views/Main/AdaptiveSheetFrame.swift` — modifier compartido (auto-incluido por
  `PBXFileSystemSynchronizedRootGroup`, sin tocar el pbxproj).

## Approaches

1. **Modifier `adaptiveSheetFrame` con gate `#if os(macOS)` (recomendado)** — un
   `View.adaptiveSheetFrame(...)` que aplica los mínimos SOLO en macOS y los elimina en iOS.
   - Pros: macOS queda byte-igual; iOS no recibe mínimos; un solo punto de cambio por sitio;
     cero duplicación de lógica; iPad (regular) no recibe mínimos absurdos de 500×700.
   - Cons: introduce una abstracción nueva (justificada: 22 usos).
   - Effort: Low

2. **Gate inline `#if os(macOS)` en cada sitio** — guard en cada uno de los 22 frames.
   - Pros: cero abstracción nueva.
   - Cons: 22 bloques `#if` verbosos; más ruido de diff; fácil olvidar uno en el futuro.
   - Effort: Low

3. **`horizontalSizeClass` también en los frames** — aplicar mínimos solo cuando
   `!= .compact`.
   - Pros: consistente con el enfoque del issue.
   - Cons: iPad regular conservaría 500×700 en sheets (riesgo de clipping); el main switch ya
     cubre el caso; no aporta frente a la opción 1.
   - Effort: Low

Para el switch principal: TabView de 3 tabs (Portfolio | Movimientos | Admin), cada tab con
su `NavigationStack` + `List` de links (navegación push por tab). En macOS el
`NavigationSplitView` actual queda intacto.

## Recommendation

Opción 1: `horizontalSizeClass` para el contenedor principal (NavigationSplitView en
regular/macOS, TabView en compact/iOS) + modifier `adaptiveSheetFrame` con gate
`#if os(macOS)` para los 22 frames. Sin reuso de la sidebar macOS en iOS (los tags de
selección son específicos de macOS y duplicarían highlight en iOS).

## Risks

- Los forms con `.frame(maxWidth: .infinity, maxHeight: .infinity)` al ser drop-eados en iOS
  dependen del NavigationStack del sheet para expandirse — ya lo hacen hoy (el ScrollView se
  expande dentro del sheet).
- `horizontalSizeClass` en macOS es siempre `.regular` → rama macOS estable. iPad compact
  (Split View) recibe TabView, coherente con el issue.
- No hay tests de UI que verifiquen el layout iOS (los UITests apuntan al flujo macOS) —
  validación manual en simulador.

## Ready for Proposal

Yes — el cambio está mapeado línea por línea. Implementar directamente (explore + apply en
una sola pasada, como pidió el orquestador).
