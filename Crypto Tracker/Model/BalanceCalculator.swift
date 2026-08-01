import Foundation
import SwiftData

// MARK: - Servicio de cálculo de balance de cryptos
//
// Fuente única de verdad del algoritmo:
// balance = ingresos + transferenciasRecibidas + swapsRecibidos
//         - egresos - transferenciasEnviadas - swapsEnviados
enum BalanceCalculator {
    static func balance(crypto: Crypto, en cartera: Cartera, movimientoActual: Decimal = 0) -> Decimal {
        let ingresos = cartera.movimientosIngreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }

        let egresos = cartera.movimientosEgreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }

        let transferenciasRecibidas = cartera.movimientosEntrada
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoEntrada }

        let transferenciasEnviadas = cartera.movimientosSalida
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoSalida }

        let swapsRecibidos = cartera.swaps
            .filter { $0.cryptoDestino?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadDestino }

        let swapsEnviados = cartera.swaps
            .filter { $0.cryptoOrigen?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadOrigen }

        return ingresos + transferenciasRecibidas + swapsRecibidos + movimientoActual -
               (egresos + transferenciasEnviadas + swapsEnviados)
    }
}
