# Tasks: Layout adaptable — NavigationSplitView → TabView en iOS

## Scope
- Cambiar `ContentView` para que use `@Environment(\.horizontalSizeClass)`:
  - `.compact` (iPhone) → TabView con tabs `Portfolio | Movimientos | Admin`.
  - Regular (macOS, iPad a ancho completo) → `NavigationSplitView` actual sin cambios.
- Eliminar los frames hardcodeados (500×700 / 300×200) en iOS vía un modifier compartido
  que solo aplica en macOS.

## Implementación

- [x] 1. Crear `Crypto Tracker/Views/Main/AdaptiveSheetFrame.swift` con
      `View.adaptiveSheetFrame(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)`
      que aplica el frame solo con `#if os(macOS)` (defaults: 500×700).
- [x] 2. `Views/Main/ContentView.swift`:
      - Añadir `@Environment(\.horizontalSizeClass)`.
      - Extraer la sidebar actual a `macSidebar` (sin cambios de comportamiento).
      - Añadir `iosTabView` (TabView, 3 tabs, cada uno `NavigationStack` + `List`).
      - `body` → `Group { if horizontalSizeClass == .compact { iosTabView } else { macSidebar } }`.
- [x] 3. Reemplazar frames de forms (4 archivos):
      `MovimientoEntradaFormView`, `MovimientoSalidaFormView`, `MovimientoSwapFormView`,
      `MovimientoEntreCarterasFormView` → `.adaptiveSheetFrame(minWidth: 500, idealWidth: 600,
      maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)`.
- [x] 4. Reemplazar frames de sheets 500×700 (6 archivos):
      `PortfolioViewsComponents` (×4), `PortfolioPorCryptosView` (×4),
      `MovimientosSwapsView` (×2), `MovimientosSalidaView` (×2),
      `MovimientosEntreCarterasView` (×2), `MovimientoForms` (×1) → `.adaptiveSheetFrame()`.
- [x] 5. Reemplazar frames de Admin 300×200 (3 archivos):
      `AdminCryptosView`, `AdminFiatView`, `AdminCarterasView` →
      `.adaptiveSheetFrame(minWidth: 300, minHeight: 200)`.
- [x] 6. Verificar build: macOS (Debug) y iOS Simulator (iPhone SE, iOS 17) — ambos SUCCEEDED.
- [x] 7. Verificar que `horizontalSizeClass` no introdujo warnings nuevos ni código muerto
      (los warnings de `NavigationLink(destination:tag:selection:)` ya existían en base).
- [x] 8. Actualizar este tasks.md marcando completados y guardar progreso en Engram.

## Verificación
- `xcodebuild build -scheme "Crypto Tracker" -destination "platform=macOS"` → **BUILD SUCCEEDED**.
- `xcodebuild build -scheme "Crypto Tracker" -destination "id=448423C3-C499-4705-835C-CE92ED93D0BC"` (iPhone SE, iOS 17) → **BUILD SUCCEEDED**.
- Diff revisado: macOS sin cambios de comportamiento; frames solo en la rama macOS.
- Nota: `xcodebuild test` falla en base por `CargaMovimientosTests.swift` (main-actor isolation,
  Swift 6) — pre-existente, ajeno a este cambio.

## Notas
- El pbxproj usa `PBXFileSystemSynchronizedRootGroup` → el archivo nuevo no requiere editar
  el proyecto.
- Los labels de tabs siguen el issue: `Portfolio`, `Movimientos`, `Admin`.
