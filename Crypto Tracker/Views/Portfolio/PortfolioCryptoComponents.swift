import SwiftUI

// MARK: - Componentes reutilizables para la vista de portafolio por cryptos
struct CryptoPortfolioHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Crypto")
                .frame(width: 80, alignment: .leading)
            Text("Disponible")
                .frame(width: 120, alignment: .trailing)
            Text("Precio USD")
                .frame(width: 120, alignment: .trailing)
            Text("USD Adquirido")
                .frame(width: 120, alignment: .trailing)
            Text("Valor USD")
                .frame(width: 120, alignment: .trailing)
            Text("USD Ventas")
                .frame(width: 120, alignment: .trailing)
            Text("Ganancia")
                .frame(width: 120, alignment: .trailing)
            Text("%")
                .frame(width: 80, alignment: .trailing)
        }
        .font(.caption)
        .bold()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
    }
}

struct CryptoPortfolioRow: View {
    let summary: CryptoPortfolioSummary
    
    var body: some View {
        HStack(spacing: 0) {
            Text(summary.crypto.simbolo)
                .frame(width: 80, alignment: .leading)
            Text(summary.totalDisponible.formatted())
                .frame(width: 120, alignment: .trailing)
            Text(summary.precioActual.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
            Text(summary.totalUSDAdquirido.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
            Text(summary.valorActualUSD.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
            Text(summary.totalUSDVentas.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
            Text(summary.gananciaUSD.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(summary.gananciaUSD >= 0 ? .green : .red)
            Text(summary.porcentajeGanancia.formatted(.number.precision(.fractionLength(2))) + "%")
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(summary.porcentajeGanancia >= 0 ? .green : .red)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct CryptoPortfolioTotalRow: View {
    let summaries: [CryptoPortfolioSummary]
    
    private var totalUSDAdquirido: Decimal {
        summaries.reduce(0) { $0 + $1.totalUSDAdquirido }
    }
    
    private var totalValorActual: Decimal {
        summaries.reduce(0) { $0 + $1.valorActualUSD }
    }
    
    private var totalUSDVentas: Decimal {
        summaries.reduce(0) { $0 + $1.totalUSDVentas }
    }
    
    private var totalGanancia: Decimal {
        summaries.reduce(0) { $0 + $1.gananciaUSD }
    }
    
    private var porcentajeGananciaTotal: Decimal {
        guard totalUSDAdquirido > 0 else { return 0 }
        return ((totalValorActual - totalUSDAdquirido) / totalUSDAdquirido) * 100
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
            Text(totalUSDAdquirido.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(totalValorActual.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(totalUSDVentas.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
                .bold()
            Text(totalGanancia.formatted(.currency(code: "USD")))
                .frame(width: 120, alignment: .trailing)
                .bold()
                .foregroundColor(totalGanancia >= 0 ? .green : .red)
            Text(porcentajeGananciaTotal.formatted(.number.precision(.fractionLength(2))) + "%")
                .frame(width: 80, alignment: .trailing)
                .bold()
                .foregroundColor(porcentajeGananciaTotal >= 0 ? .green : .red)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
    }
}
