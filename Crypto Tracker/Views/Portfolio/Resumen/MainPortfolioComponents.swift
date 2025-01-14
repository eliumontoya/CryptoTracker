import SwiftUI

// MARK: - Tarjeta de Valor del Portfolio Principal
struct MainPortfolioCardView: View {
    let title: String
    let value: Decimal
    var secondaryText: String? = nil
    var isPositive: Bool? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icono y título
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            
            // Valor principal
            Text(value.formatted(.currency(code: "USD")))
                .font(.system(size: 24, weight: .bold))
            
            // Texto secundario (opcional)
            if let secondaryText = secondaryText {
                HStack(spacing: 4) {
                    Image(systemName: (isPositive ?? true) ? "arrow.up.right" : "arrow.down.right")
                    Text(secondaryText)
                }
                .foregroundStyle((isPositive ?? true) ? .green : .red)
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
        )
    }
}

// MARK: - Header del Portfolio Principal
struct MainPortfolioHeaderView: View {
    var body: some View {
        HStack {
            Text("Resumen del Portfolio")
                .font(.largeTitle)
                .bold()
            Spacer()
            Text(Date().formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom)
    }
}

// MARK: - Vista de Resumen del Portfolio Principal
struct MainPortfolioSummaryView: View {
    let summary: MainPortfolioSummary
    
    var body: some View {
        HStack(spacing: 20) {
            // USD Invertido
            MainPortfolioCardView(
                title: "USD Invertido",
                value: summary.totalInvertidoUSD,
                icon: "arrow.down.circle.fill",
                color: .blue
            )
            
            // Valor Actual
            MainPortfolioCardView(
                title: "Valor Actual",
                value: summary.valorActualUSD,
                secondaryText: "\(summary.rendimientoTotal.formatted(.number.precision(.fractionLength(2))))%",
                isPositive: summary.isGanancia,
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                color: summary.isGanancia ? .green : .red
            )
            
            // Total Ventas
            MainPortfolioCardView(
                title: "Total Ventas",
                value: summary.totalVentasUSD,
                icon: "arrow.up.circle.fill",
                color: .orange
            )
            
            // Ganancia Total
            MainPortfolioCardView(
                title: "Ganancia Total",
                value: summary.gananciaTotal,
                secondaryText: "\(summary.rendimientoTotal.formatted(.number.precision(.fractionLength(2))))%",
                isPositive: summary.isGanancia,
                icon: "chart.pie.fill",
                color: summary.isGanancia ? .green : .red
            )
        }
    }
}
