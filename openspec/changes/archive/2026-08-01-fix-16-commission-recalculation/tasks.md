# Tasks: Fix Commission Recalculation on Edit EntreCarteras

## Phase 1: Apply Fix

- [x] 1.1 Add `existingMovimiento.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada` after line 116 in `Crypto Tracker/ViewModels/Movimientos/MovimientoEntreCarterasViewModel.swift`

## Verification

- [x] 1.2 Confirm the edit path in `save()` now recalculates commission before persisting
