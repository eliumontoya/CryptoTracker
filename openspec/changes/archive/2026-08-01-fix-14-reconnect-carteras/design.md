# Design: Reconnect "Desglose por Carteras"

## Technical Approach

Trivial single-file edit: uncomment the 2-column wallet grid in
`PortfolioDetalleView.swift` and remove one stale parameter. No new code,
no architectural changes.

The entire `contenidoPortfolio` body (lines 49-85) is wrapped in `/* ... */`.
Once uncommented, the `ForEach` loop renders `viewModel.carterasDetail` as
`CarteraDetailView` cards in a two-column layout. The ViewModel,
`CarteraDetailView`, navigation chain, and movement sheets are all already
implemented and functional.

## Architecture Decisions

This is a reconnect, not a redesign — no decisions to document.

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Uncomment + delete stale param | Zero-risk restore of authored code | **Chosen** |
| Rebuild UI from scratch | Wasted effort; all components already exist | Rejected |

## Component Relationship

```
PortfolioDetalleView
 └─ ForEach(0..<viewModel.numeroRenglones)
     └─ HStack (2-col row)
         ├─ CarteraDetailView (col 1)
         │   ├─ headerWithMenu ──→ CarteraMovimientosView (sheet)
         │   ├─ tablaCryptos row tap ──→ CarteraCryptoDetailView (sheet)
         │   └─ "+" menu ──→ applyMovimientoSheets
         │       ├─ Entrada sheet
         │       ├─ Salida sheet
         │       ├─ Entre Carteras sheet
         │       └─ Swap sheet
         └─ CarteraDetailView (col 2, same structure)
```

All navigation and sheet presentation is handled inside `CarteraDetailView`
via `@StateObject var viewModel: CarteraDetailViewModel` and the
`.applyMovimientoSheets` modifier. Nothing changes at any layer but the view.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `Views/Portfolio/xCartera/PortfolioDetalleView.swift` | Modify | Remove `/*` (line 49) and `*/` (line 85). Delete `movimientoService: movimientoService` on line 56. |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | macOS target compiles without errors | `xcodebuild build` on macOS scheme |
| UI (manual) | Grid renders wallet cards when wallets exist | Visual verification after uncomment |
| UI (manual) | Empty state with no wallets (no crash) | Visual verification |

No unit tests needed — logic is unchanged. The change restores UI that was
already authored and tested before being commented out.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file
classification, or process-integration boundary.

## Migration / Rollout

No migration required. Rollback: re-comment lines 49-85 and restore line 56.

## Open Questions

None.
