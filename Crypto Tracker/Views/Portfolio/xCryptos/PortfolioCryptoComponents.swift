import SwiftUI

// MARK: - Header Row Component
struct CryptoPortfolioHeaderRow: View {
    private let viewModel = PortfolioCryptoComponentsViewModel()
    private let headerData = PortfolioCryptoComponentsViewModel.HeaderData()
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(headerData.titles.enumerated()), id: \.element.title) { _, title in
                Text(title.title)
                    .frame(width: title.width, alignment: title.alignment)
            }
        }
        .font(.caption)
        .bold()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
    }
}

// MARK: - Row Component
struct CryptoPortfolioRow: View {
    let summary: CryptoPortfolioSummary
    private let viewModel: PortfolioCryptoComponentsViewModel.RowData
    
    init(summary: CryptoPortfolioSummary) {
        self.summary = summary
        self.viewModel = PortfolioCryptoComponentsViewModel.RowData(summary: summary)
    }
    var body: some View {
        HStack(spacing: 0) {
            Text(summary.crypto.simbolo)
                .frame(width: 80, alignment: .leading)
            Text(viewModel.formatearCantidad(summary.totalDisponible))
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(summary.precioActual))
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(summary.totalUSDAdquirido))
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(summary.valorActualUSD))
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(summary.totalUSDVentas))
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(summary.gananciaUSD))
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(viewModel.isGananciaPositive ? .green : .red)
            Text(viewModel.formatearPorcentaje(summary.porcentajeGanancia))
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(viewModel.isPorcentajePositive ? .green : .red)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Total Row Component
struct CryptoPortfolioTotalRow: View {
    let summaries: [CryptoPortfolioSummary]
    private let viewModel: PortfolioCryptoComponentsViewModel.TotalRowData
    
    init(summaries: [CryptoPortfolioSummary]) {
        self.summaries = summaries
        self.viewModel = PortfolioCryptoComponentsViewModel.TotalRowData(summaries: summaries)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text("TOTAL")
                .frame(width: 80, alignment: .leading)
                .bold()
            Text("")
                .frame(width: 120, alignment: .trailing)
            Text("")
                .frame(width: 120, alignment: .trailing)
            Text(viewModel.formatearUSD(viewModel.totalUSDAdquirido))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(viewModel.formatearUSD(viewModel.totalValorActual))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(viewModel.formatearUSD(viewModel.totalUSDVentas))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(viewModel.formatearUSD(viewModel.totalGanancia))
                .frame(width: 120, alignment: .trailing)
                .bold()
                .foregroundColor(viewModel.isGananciaPositive ? .green : .red)
            Text(viewModel.formatearPorcentaje(viewModel.porcentajeGananciaTotal))
                .frame(width: 80, alignment: .trailing)
                .bold()
                .foregroundColor(viewModel.isPorcentajePositive ? .green : .red)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
    }
}
