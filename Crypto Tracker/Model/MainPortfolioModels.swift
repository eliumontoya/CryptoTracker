import SwiftUI

// MARK: - Modelos para Gráficos
struct MainChartData: Identifiable {
    let id = UUID()
    let nombre: String
    let valor: Double
    let porcentaje: Double
    let color: Color
}

// MARK: - Modelos de Portfolio Principal
struct MainPortfolioSummary {
    let totalInvertidoUSD: Decimal
    let valorActualUSD: Decimal
    let totalVentasUSD: Decimal
    let gananciaTotal: Decimal
    let rendimientoTotal: Decimal
    
    var isGanancia: Bool {
        rendimientoTotal >= 0
    }
}

// MARK: - Modelos para Distribución
struct MainCryptoDistribution: Identifiable {
    let id = UUID()
    let cryptoId: UUID
    let nombre: String
    let ganancia: Decimal
    let valorTotal: Decimal
    let porcentaje: Decimal
}
