import SwiftUI
import SwiftData

struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel

    // Colores para el gráfico
    private let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .yellow, .red, .cyan, .mint, .indigo
    ]

    private var chartData: [MainChartData] {
        viewModel.distribution.enumerated().map { index, item in
            MainChartData(
                nombre: item.nombre,
                valor: NSDecimalNumber(decimal: item.ganancia).doubleValue,
                porcentaje: NSDecimalNumber(decimal: item.porcentaje).doubleValue,
                color: chartColors[index % chartColors.count]
            )
        }
    }

    init(viewModel: PortfolioViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                // Header
                MainPortfolioHeaderView()

                // Resumen
                if let summary = viewModel.summary {
                    MainPortfolioSummaryView(summary: summary)
                }

                // Gráfico de evolución del valor del portfolio
                MainChartContainerView(title: "Portfolio Value Over Time") {
                    PortfolioValueChartView(snapshots: viewModel.snapshots)
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
        .accessibilityIdentifier("portfolio-view")
        .onAppear {
            viewModel.loadPortfolio()
        }
    }
}

#Preview { @MainActor in
    let container = PreviewContainer.shared
    let viewModel = PortfolioViewModel(modelContext: container.context)
    return PortfolioView(viewModel: viewModel)
        .withPreviewContainer()
}
