import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var portfolioDetails: [CarteraDetail] = []
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
        // Calcular detalles del portfolio
        portfolioDetails = PortfolioCalculator.calcularDetallesPortfolio(
            carteras: carteras,
            cryptos: cryptos,
            fiats: fiats
        )
        
        // Calcular resumen
        portfolioSummary = MainPortfolioCalculator.calcularResumen(
            portfolioDetails: portfolioDetails,
            carteras: carteras
        )
        
        // Calcular distribución de ganancias
        distribucionGanancias = MainPortfolioCalculator.calcularDistribucionGanancias(
            portfolioDetails: portfolioDetails
        )
    }
}

#Preview {
    PortfolioView()
        .withPreviewContainer()
}
