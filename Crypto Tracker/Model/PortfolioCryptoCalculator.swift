import Foundation
import SwiftData

// MARK: - Servicio de cálculo para el portafolio por crypto
class PortfolioCryptoCalculator {
    static func calcularResumenPorCrypto(portfolioId: UUID, in context: ModelContext) -> [CryptoPortfolioSummary] {
        PortfolioQueries.portfolioByCryptos(portfolioId: portfolioId, in: context).map { aggregate in
            CryptoPortfolioSummary(
                crypto: aggregate.crypto,
                totalDisponible: aggregate.qty,
                precioActual: aggregate.crypto.precio,
                totalUSDAdquirido: aggregate.adquiridoUSD,
                valorActualUSD: aggregate.valorActualUSD,
                totalUSDVentas: aggregate.ventasUSD,
                gananciaUSD: aggregate.pnlUSD
            )
        }
    }
}
