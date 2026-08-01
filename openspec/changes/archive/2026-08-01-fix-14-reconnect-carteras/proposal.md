# Proposal: Reconnect "Desglose por Carteras"

## Intent

The 2-column wallet grid (Desglose por Carteras) is fully commented out in PortfolioDetalleView, making the navigation screen empty. The underlying components (CarteraDetailView, CarteraMovimientosView, CarteraCryptoDetailView) and ViewModels are complete but unreachable. This reconnects the UI in a single-file, 3-line fix.

## Scope

### In Scope
- Uncomment the ForEach block rendering the 2-column grid of CarteraDetailView cards
- Fix the stale `movimientoService: movimientoService` parameter to match current `CarteraDetailView.init(carteraDetail:onUpdateData:)`

### Out of Scope
- No new UI components, ViewModels, or data flow changes
- No iOS-specific layout adaptation (current grid works on both platforms)
- No behavior changes to navigation, forms, or calculations

## Capabilities

### New Capabilities
<!-- None — this restores already-implemented capability that was accidentally disabled -->
None

### Modified Capabilities
<!-- No spec-level behavior changes — pure reconnect of commented code -->
None

## Approach

**Single-file edit** in `PortfolioDetalleView.swift` lines 49–85:

1. Remove `/*` and `*/` comment delimiters
2. Replace line 56: `movimientoService: movimientoService\n` → empty (delete the line)

The second `CarteraDetailView` call is already correct; only the first one carries the stale parameter from a previous API.

Navigation chains reconnected: PortfolioDetalleView → CarteraDetailView → CarteraMovimientosView / CarteraCryptoDetailView. "+" menu → movement forms (entrada/salida/transferencia/swap). All backing code is ready.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Views/Portfolio/xCartera/PortfolioDetalleView.swift` | Modified | Uncomment grid, remove stale param |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Grid layout regression on macOS | Low | Layout is unchanged from original authored code; verify visually after uncommenting |
| Empty state shows 0 cards when no wallets exist | Low | Accepted UX — no wallets means nothing to render |

## Rollback Plan

Re-comment lines 49–85 and restore `movimientoService:` param on line 56. Single-commit revert.

## Dependencies

None. CarteraDetailView, CarteraDetailViewModel, PortfolioDetalleViewModel, PortfolioCalculator, and navigation sheets are all already implemented and functional.

## Success Criteria

- [ ] `Desglose por Carteras` screen shows a 2-column grid with one card per wallet
- [ ] Each card displays wallet name, USD total, crypto list, and balances
- [ ] Tapping a wallet header navigates to CarteraMovimientosView
- [ ] "+" menu opens movement creation sheets (entrada, salida, transferencia, swap)
- [ ] Build passes on macOS target without errors
