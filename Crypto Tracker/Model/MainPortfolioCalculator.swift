import Foundation
import SwiftData

class MainPortfolioCalculator {
    static func calcularResumen(portfolioId: UUID, in context: ModelContext) -> MainPortfolioSummary {
        let summary = PortfolioQueries.portfolioSummary(portfolioId: portfolioId, in: context)

        return MainPortfolioSummary(
            totalInvertidoUSD: summary.invertidoUSD,
            valorActualUSD: summary.valorActualUSD,
            totalVentasUSD: summary.totalVentasUSD,
            gananciaTotal: summary.gananciaUSD,
            rendimientoTotal: summary.rendimientoPct
        )
    }

    static func calcularDistribucionGanancias(portfolioId: UUID, in context: ModelContext) -> [MainCryptoDistribution] {
        let aggregates = PortfolioQueries.portfolioByCryptos(portfolioId: portfolioId, in: context)

        // Calcular el total absoluto para los porcentajes
        let totalAbsoluto = aggregates.reduce(Decimal(0)) { $0 + abs($1.pnlUSD) }

        return aggregates.map { aggregate in
            MainCryptoDistribution(
                cryptoId: aggregate.crypto.id,
                nombre: aggregate.simbolo,
                ganancia: aggregate.pnlUSD,
                valorTotal: aggregate.valorActualUSD,
                porcentaje: totalAbsoluto != 0 ? (aggregate.pnlUSD / totalAbsoluto) * 100 : 0
            )
        }.sorted { $0.ganancia > $1.ganancia }
    }
}
