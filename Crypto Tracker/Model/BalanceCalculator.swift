import Foundation
import SwiftData

// MARK: - Servicio de cálculo de balance de cryptos
//
// Fuente única de verdad del algoritmo:
// balance = ingresos + transferenciasRecibidas + swapsRecibidos
//         - egresos - transferenciasEnviadas - swapsEnviados
enum BalanceCalculator {
    static func balance(crypto: Crypto, en cartera: Cartera, movimientoActual: Decimal = 0) -> Decimal {
        let ingresos = cartera.movimientos
            .filter { $0.tipo == .entrada && $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }

        let egresos = cartera.movimientos
            .filter { $0.tipo == .salida && $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }

        let transferenciasRecibidas = cartera.movimientos
            .filter { $0.tipo == .transferenciaEntrada && $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoEntrada }

        let transferenciasEnviadas = cartera.movimientos
            .filter { $0.tipo == .transferenciaSalida && $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoSalida }

        let swapsRecibidos = cartera.movimientos
            .filter { $0.tipo == .swapEntrada && $0.cryptoDestino?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadDestino }

        let swapsEnviados = cartera.movimientos
            .filter { $0.tipo == .swapSalida && $0.cryptoOrigen?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadOrigen }

        return ingresos + transferenciasRecibidas + swapsRecibidos + movimientoActual -
               (egresos + transferenciasEnviadas + swapsEnviados)
    }
}
