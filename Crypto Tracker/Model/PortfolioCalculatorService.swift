import Foundation
import SwiftData

// MARK: - Servicio de Cálculos de Portfolio
class PortfolioCalculator {
    static func calcularDetallesCartera(_ cartera: Cartera, cryptos: [Crypto]) -> CarteraDetail {
        let cryptoDetails = cryptos.compactMap { crypto -> CryptoDetail? in
            // Calcular totales por crypto
            let ingresosPorEntradas = cartera.movimientos
                .filter { $0.tipo == .entrada && $0.crypto?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }

            let ingresosPorSwaps = cartera.movimientos
                .filter { $0.tipo == .swapEntrada && $0.cryptoDestino?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadDestino }

            let totalCryptoIngresado = ingresosPorEntradas + ingresosPorSwaps

            let egresosPorVentas = cartera.movimientos
                .filter { $0.tipo == .salida && $0.crypto?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }

            let egresosPorSwaps = cartera.movimientos
                .filter { $0.tipo == .swapSalida && $0.cryptoOrigen?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }

            let totalCryptoVendido = egresosPorVentas + egresosPorSwaps

            // Transferencias entre carteras (entradas y salidas)
            let transferenciasEntrada = cartera.movimientos
                .filter { $0.tipo == .transferenciaEntrada && $0.crypto?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadCryptoEntrada }

            let transferenciasSalida = cartera.movimientos
                .filter { $0.tipo == .transferenciaSalida && $0.crypto?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.cantidadCryptoSalida }

            // Balance neto de transferencias (positivo = más entradas, negativo = más salidas)
            let balanceTransferencias = transferenciasEntrada - transferenciasSalida

            // Calcular balance total
            let balanceActual = BalanceCalculator.balance(crypto: crypto, en: cartera)

            // Si no hay movimientos, no incluir esta crypto
            guard balanceActual != 0 else { return nil }

            // Calcular total USD invertido en entradas
            let totalInvertidoUSD = cartera.movimientos
                .filter { $0.tipo == .entrada && $0.crypto?.id == crypto.id }
                .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }

            // Calcular valor actual en USD
            let valorUSD = balanceActual * crypto.precio

            return CryptoDetail(
                crypto: crypto,
                totalCryptoIngresado: totalCryptoIngresado,
                totalCryptoVendido: totalCryptoVendido,
                totalCryptoTransferido: balanceTransferencias,
                balanceActual: balanceActual,
                totalInvertidoUSD: totalInvertidoUSD,
                valorUSD: valorUSD,
                ganancia: valorUSD - totalInvertidoUSD
            )
        }

        return CarteraDetail(
            cartera: cartera,
            cryptoDetails: cryptoDetails
        )
    }

    static func calcularDetallesPortfolio(carteras: [Cartera], cryptos: [Crypto]) -> [CarteraDetail] {
        let carterasDetail = carteras.map { cartera in
            calcularDetallesCartera(cartera, cryptos: cryptos)
        }
        // Filtrar carteras sin cryptos
        return carterasDetail.filter { !$0.cryptoDetails.isEmpty }
    }
}
