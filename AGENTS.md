# Reglas para Agentes IA

Este documento establece las reglas y convenciones que deben seguir todos los
agentes IA al trabajar en este proyecto. Para contexto técnico y de negocio,
ver `ARCHITECTURE.md` y `PROJECT.md`.

## Lectura obligatoria antes de trabajar

Antes de hacer cualquier cambio, lee:
- `PROJECT.md` — contexto de negocio
- `ARCHITECTURE.md` — contexto técnico y arquitectura objetivo

Ambos viven en la raíz del repo.

## Convenciones de idioma

- **Código**: identificadores, comentarios, y strings de UI en **inglés**.
- **Documentación**: en **español** (PROJECT.md, ARCHITECTURE.md, AGENTS.md).
- **Commits**: en **inglés**, formato conventional commits (`feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`).
- **Issues/PRs**: en **español**.

## Estilo de código

- Seguir **Swift API Design Guidelines**.
- **Nombres**: descriptivos, en inglés, camelCase para variables/métodos, PascalCase para tipos.
- **Sin comentarios** salvo que expliquen un porqué no obvio.
- **Sin código muerto**: si no se usa, se borra.
- **Sin TODOs sin issue**: todo TODO debe referenciar un issue de GitHub (`// TODO(#42): ...`).

## Arquitectura

- **Vistas** no acceden a SwiftData directo — usan ViewModels.
- **ViewModels** usan use cases con protocolos inyectables.
- **Use cases** son atómicos: movimiento + holding en una transacción.
- **Inyección de dependencias** vía `AppDependencyContainer` para todos los ViewModels.
- **Capa de red** abstraída en servicios con protocolos (ej: `PriceServiceProtocol`).

## Testing

- **Tests unitarios** para toda lógica de negocio (use cases, servicios, calculadoras).
- **Tests de UI** para flujos críticos (navegación, CRUDs principales).
- **Mocks** deben usar el cálculo real, no valores hardcodeados.
- **Coverage objetivo**: >70% en capa de dominio.

## Git

- **Branches**: `main` (producción), `develop` (integración), feature branches (`feat/`, `fix/`, `refactor/`).
- **Commits**: atómicos, uno por cambio lógico.
- **PRs**: pequeños, enfocados en un solo tema. Vincular issue de GitHub.
- **No force-push** en branches compartidos.
- **No commitear** secrets, API keys, o datos sensibles.
- **No commitear** `.DS_Store`, `*.zip`, o archivos temporales.

## Checklist antes de commitear

- [ ] `xcodebuild build` pasa sin errores
- [ ] `xcodebuild test` pasa sin fallos
- [ ] No hay warnings nuevos
- [ ] No hay código muerto (archivos vacíos, imports sin uso)
- [ ] No hay TODOs sin issue de GitHub
- [ ] Commits en inglés, formato conventional commits
- [ ] PR vincula issue de GitHub
- [ ] Documentación actualizada si aplica (PROJECT.md, ARCHITECTURE.md)

## Errores comunes a evitar

1. No crear ModelContainers ad-hoc en inits de vistas.
2. No calcular balances on-the-fly sumando movimientos.
3. No mezclar USD/FIAT en KPIs sin normalizar.
4. No hardcodear cryptos, carteras, o portfolios en filtros/chips.
5. No dejar sheets vacíos o comentados.
6. No usar valores hardcodeados en mocks de tests.
7. No dejar archivos vacíos o sin uso.
8. No duplicar lógica de cálculo de balance.
9. No hacer operaciones no-atómicas que toquen movimiento + holding.

## Recursos

- **Repositorio**: https://github.com/eliumontoya/CryptoTracker
- **Issues**: https://github.com/eliumontoya/CryptoTracker/issues
- **SwiftUI**: https://developer.apple.com/documentation/swiftui
- **SwiftData**: https://developer.apple.com/documentation/swiftdata
- **Swift Charts**: https://developer.apple.com/documentation/charts
- **Swift API Guidelines**: https://swift.org/documentation/api-design-guidelines/
