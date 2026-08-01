# Proposal: Fix Commission Recalculation on Edit EntreCarteras

## Intent

When editing a `MovimientoEntreCarteras`, the `cantidadCryptoComision` field is not recalculated. The `save()` method updates `fecha`, `cantidadCryptoSalida`, `cantidadCryptoEntrada`, `carteraOrigen`, `carteraDestino`, and `crypto` but omits `cantidadCryptoComision`. The commission is derived from `cantidadCryptoSalida - cantidadCryptoEntrada` (set once during `init`) — editing without recalculation leaves it stale with the creation-time value.

## Scope

### In Scope
- Add `existingMovimiento.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada` to the edit path in `save()` at `MovimientoEntreCarterasViewModel.swift:116`

### Out of Scope
- New creation path (already correct — init calculates it)
- Delete path (no commission involved)
- Any other ViewModel or movement type

## Capabilities

### New Capabilities
None

### Modified Capabilities
None — pure bug fix. No spec-level requirement changes.

## Approach

Single-line addition to `MovimientoEntreCarterasViewModel.save()`, insert after line 116:

```swift
existingMovimiento.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada
```

This mirrors the existing derived-property `comision` (line 22-24) which already computes this value on-the-fly but is never persisted back to the model during edits. The fix ensures the persisted field stays synchronized with the computed field.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Crypto Tracker/ViewModels/Movimientos/MovimientoEntreCarterasViewModel.swift` | Modified | 1-line addition in save() edit path |
| `Crypto TrackerTests/MovimientoEntreCarterasViewModelTests.swift` | Modified | Add test asserting commission updates on edit |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| None — derived field, no side effects | Low | Existing `formIsValid` constrains `cantidadCryptoEntrada ≤ cantidadCryptoSalida`, preventing negative commission |

## Rollback Plan

Remove the added line. No migration or schema change required.

## Dependencies

None.

## Success Criteria

- [ ] `xcodebuild build` passes
- [ ] Editing an existing `MovimientoEntreCarteras` and saving recalculates `cantidadCryptoComision` to `cantidadCryptoSalida - cantidadCryptoEntrada`
- [ ] Existing test `MovimientoEntreCarterasViewModelTests` passes (or updated to cover edit path)
- [ ] No regressions in creation path
