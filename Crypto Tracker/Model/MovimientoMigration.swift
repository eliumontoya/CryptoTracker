import Foundation
import SwiftData

/// Migración de datos v3 → v4: copia los movimientos de las 4 tablas antiguas
/// (`MovimientoIngreso`, `MovimientoEgreso`, `MovimientoEntreCarteras`,
/// `MovimientoSwap`) a la tabla unificada `Movimiento`.
///
/// El cambio de esquema en sí (nueva entidad `Movimiento`, nuevas relaciones en
/// `Cartera`/`Crypto`/`FIAT`) es aditivo y SwiftData lo migra de forma ligera.
/// Este helper completa la migración de *datos*:
/// - `MovimientoIngreso` → 1 `Movimiento` `.entrada`
/// - `MovimientoEgreso` → 1 `Movimiento` `.salida`
/// - `MovimientoEntreCarteras` → par `.transferenciaSalida` + `.transferenciaEntrada` (mismo `groupId`)
/// - `MovimientoSwap` → par `.swapSalida` + `.swapEntrada` (mismo `groupId`)
///
/// Es idempotente: si ya existen registros en `Movimiento`, no vuelve a copiar.
@MainActor
enum MovimientoMigration {
    /// Copia los datos de las tablas antiguas a `Movimiento`.
    /// Devuelve el número de registros creados (0 si ya estaba migrado).
    @discardableResult
    static func apply(in context: ModelContext) -> Int {
        // Idempotencia: si ya hay movimientos unificados, no repetir.
        let existing = (try? context.fetchCount(FetchDescriptor<Movimiento>())) ?? 0
        guard existing == 0 else { return 0 }

        var created = 0

        // 1) Entradas (compras)
        if let ingresos = try? context.fetch(FetchDescriptor<MovimientoIngreso>()) {
            for ingreso in ingresos {
                guard let cartera = ingreso.cartera, let crypto = ingreso.crypto else { continue }
                context.insert(
                    Movimiento.entrada(
                        fecha: ingreso.fecha,
                        cantidadCrypto: ingreso.cantidadCrypto,
                        precioUSD: ingreso.precioUSD,
                        usaFiatAlterno: ingreso.usaFiatAlterno,
                        precioFiatAlterno: ingreso.precioFiatAlterno,
                        valorTotalFiatAlterno: ingreso.valorTotalFiatAlterno,
                        cartera: cartera,
                        crypto: crypto,
                        fiatAlterno: ingreso.fiatAlterno
                    )
                )
                created += 1
            }
        }

        // 2) Salidas (ventas)
        if let egresos = try? context.fetch(FetchDescriptor<MovimientoEgreso>()) {
            for egreso in egresos {
                guard let cartera = egreso.cartera, let crypto = egreso.crypto else { continue }
                context.insert(
                    Movimiento.salida(
                        fecha: egreso.fecha,
                        cantidadCrypto: egreso.cantidadCrypto,
                        precioUSD: egreso.precioUSD,
                        usaFiatAlterno: egreso.usaFiatAlterno,
                        precioFiatAlterno: egreso.precioFiatAlterno,
                        valorTotalFiatAlterno: egreso.valorTotalFiatAlterno,
                        cartera: cartera,
                        crypto: crypto,
                        fiatAlterno: egreso.fiatAlterno
                    )
                )
                created += 1
            }
        }

        // 3) Transferencias entre carteras → par con groupId
        if let transferencias = try? context.fetch(FetchDescriptor<MovimientoEntreCarteras>()) {
            for transferencia in transferencias {
                guard let origen = transferencia.carteraOrigen,
                      let destino = transferencia.carteraDestino,
                      let crypto = transferencia.crypto else { continue }
                let par = Movimiento.transferencia(
                    fecha: transferencia.fecha,
                    cantidadCryptoSalida: transferencia.cantidadCryptoSalida,
                    cantidadCryptoEntrada: transferencia.cantidadCryptoEntrada,
                    carteraOrigen: origen,
                    carteraDestino: destino,
                    crypto: crypto
                )
                context.insert(par.salida)
                context.insert(par.entrada)
                created += 2
            }
        }

        // 4) Swaps → par con groupId
        if let swaps = try? context.fetch(FetchDescriptor<MovimientoSwap>()) {
            for swap in swaps {
                guard let cartera = swap.cartera,
                      let origen = swap.cryptoOrigen,
                      let destino = swap.cryptoDestino else { continue }
                let par = Movimiento.swap(
                    fecha: swap.fecha,
                    cantidadOrigen: swap.cantidadOrigen,
                    cantidadDestino: swap.cantidadDestino,
                    precioUSDOrigen: swap.precioUSDOrigen,
                    precioUSDDestino: swap.precioUSDDestino,
                    cartera: cartera,
                    cryptoOrigen: origen,
                    cryptoDestino: destino
                )
                context.insert(par.salida)
                context.insert(par.entrada)
                created += 2
            }
        }

        if created > 0 {
            try? context.save()
        }
        return created
    }
}
