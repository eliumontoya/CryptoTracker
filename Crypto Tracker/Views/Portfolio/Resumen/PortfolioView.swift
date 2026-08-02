import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var portfolioSummary: MainPortfolioSummary?
    @State private var distribucionGanancias: [MainCryptoDistribution] = []
    
    // Colores para el gráfico
    private let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .yellow, .red, .cyan, .mint, .indigo
    ]
    
    private var chartData: [MainChartData] {
        distribucionGanancias.enumerated().map { index, item in
            MainChartData(
                nombre: item.nombre,
                valor: NSDecimalNumber(decimal: item.ganancia).doubleValue,
                porcentaje: NSDecimalNumber(decimal: item.porcentaje).doubleValue,
                color: chartColors[index % chartColors.count]
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                MainPortfolioHeaderView()
                
                // Resumen
                if let summary = portfolioSummary {
                    MainPortfolioSummaryView(summary: summary)
                }
                
                // Gráfico de distribución de ganancias
                MainChartContainerView(title: "Distribución de Ganancias por Crypto") {
                    HStack(alignment: .top, spacing: 20) {
                        // Gráfico circular
                        MainPieChartView(data: chartData)
                            .frame(width: 250, height: 250)
                        
                        // Leyenda
                        MainChartLegendView(data: chartData)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            actualizarPortfolio()
        }
    }
    
    private func actualizarPortfolio() {
        guard let portfolio = PortfolioQueries.defaultPortfolio(in: modelContext) else { return }
        
        // Calcular resumen
        portfolioSummary = MainPortfolioCalculator.calcularResumen(
            portfolioId: portfolio.id,
            in: modelContext
        )
        
        // Calcular distribución de ganancias
        distribucionGanancias = MainPortfolioCalculator.calcularDistribucionGanancias(
            portfolioId: portfolio.id,
            in: modelContext
        )
    }
}

#Preview {
    PortfolioView()
        .withPreviewContainer()
}
