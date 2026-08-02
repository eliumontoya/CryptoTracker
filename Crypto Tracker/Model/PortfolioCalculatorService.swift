import Foundation
import SwiftData

// MARK: - Servicio de Cálculos de Portfolio
class PortfolioCalculator {
    static func calcularDetallesCartera(_ cartera: Cartera, in context: ModelContext) -> CarteraDetail {
        let holdings = PortfolioQueries.holdingsByWallet(walletId: cartera.id, in: context)
        let movimientos = PortfolioQueries.movementsByWallet(walletId: cartera.id, in: context)

        let cryptoDetails = holdings.holdings.map { holding -> CryptoDetail? in
            let movimientosCrypto = movimientos.filter { movimiento in
                movimiento.crypto?.id == holding.crypto.id
            }

            // Desglose de cantidades por tipo (fuente: movimientos de la cartera)
            let ingresosPorEntradas = movimientosCrypto
                .filter { $0.tipo == .entrada }
                .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }

            let ingresosPorSwaps = movimientosCrypto
                .filter { $0.tipo == .swapEntrada }
                .reduce(Decimal(0)) { $0 + $1.cantidadDestino }

            let totalCryptoIngresado = ingresosPorEntradas + ingresosPorSwaps

            let egresosPorVentas = movimientosCrypto
                .filter { $0.tipo == .salida }
                .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }

            let egresosPorSwaps = movimientosCrypto
                .filter { $0.tipo == .swapSalida }
                .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }

            let totalCryptoVendido = egresosPorVentas + egresosPorSwaps

            let transferenciasEntrada = movimientosCrypto
                .filter { $0.tipo == .transferenciaEntrada }
                .reduce(Decimal(0)) { $0 + $1.cantidadCryptoEntrada }

            let transferenciasSalida = movimientosCrypto
                .filter { $0.tipo == .transferenciaSalida }
                .reduce(Decimal(0)) { $0 + $1.cantidadCryptoSalida }

            let balanceTransferencias = transferenciasEntrada - transferenciasSalida

            guard holding.cantidad != 0 else { return nil }

            return CryptoDetail(
                crypto: holding.crypto,
                totalCryptoIngresado: totalCryptoIngresado,
                totalCryptoVendido: totalCryptoVendido,
                totalCryptoTransferido: balanceTransferencias,
                balanceActual: holding.cantidad,
                totalInvertidoUSD: holding.invertidoUSD,
                valorUSD: holding.valorUSD,
                ganancia: holding.gananciaUSD
            )
        }

        return CarteraDetail(
            cartera: cartera,
            cryptoDetails: cryptoDetails.compactMap { $0 }
        )
    }

    static func calcularDetallesPortfolio(portfolioId: UUID, in context: ModelContext) -> [CarteraDetail] {
        let carteras = PortfolioQueries.carteras(portfolioId: portfolioId, in: context)
        let carterasDetail = carteras.map { cartera in
            calcularDetallesCartera(cartera, in: context)
        }
        // Filtrar carteras sin cryptos
        return carterasDetail.filter { !$0.cryptoDetails.isEmpty }
    }
}
