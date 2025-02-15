import Foundation
import SwiftUI

@MainActor
final class PortfolioCryptoComponentsViewModel: ObservableObject {
    // MARK: - Header Row
    struct HeaderData {
        let titles: [(width: CGFloat, title: String, alignment: Alignment)] = [
            (80, "Crypto", .leading),
            (120, "Disponible", .trailing),
            (120, "Precio USD", .trailing),
            (120, "USD Adquirido", .trailing),
            (120, "Valor USD", .trailing),
            (120, "USD Ventas", .trailing),
            (120, "Ganancia", .trailing),
            (80, "%", .trailing)
        ]
    }
    
    // MARK: - Row Data
    struct RowData {
        let summary: CryptoPortfolioSummary
        
        var isGananciaPositive: Bool {
            summary.gananciaUSD >= 0
        }
        
        var isPorcentajePositive: Bool {
            summary.porcentajeGanancia >= 0
        }
        
        func formatearCantidad(_ cantidad: Decimal) -> String {
            cantidad.formatted()
        }
        
        func formatearUSD(_ cantidad: Decimal) -> String {
            cantidad.formatted(.currency(code: "USD"))
        }
        
        func formatearPorcentaje(_ porcentaje: Decimal) -> String {
            porcentaje.formatted(.number.precision(.fractionLength(2))) + "%"
        }
    }
    
    // MARK: - Total Row
    struct TotalRowData {
        let summaries: [CryptoPortfolioSummary]
        
        var totalUSDAdquirido: Decimal {
            summaries.reduce(0) { $0 + $1.totalUSDAdquirido }
        }
        
        var totalValorActual: Decimal {
            summaries.reduce(0) { $0 + $1.valorActualUSD }
        }
        
        var totalUSDVentas: Decimal {
            summaries.reduce(0) { $0 + $1.totalUSDVentas }
        }
        
        var totalGanancia: Decimal {
            summaries.reduce(0) { $0 + $1.gananciaUSD }
        }
        
        var porcentajeGananciaTotal: Decimal {
            guard totalUSDAdquirido > 0 else { return 0 }
            return ((totalValorActual - totalUSDAdquirido) / totalUSDAdquirido) * 100
        }
        
        var isGananciaPositive: Bool {
            totalGanancia >= 0
        }
        
        var isPorcentajePositive: Bool {
            porcentajeGananciaTotal >= 0
        }
        
        func formatearUSD(_ cantidad: Decimal) -> String {
            cantidad.formatted(.currency(code: "USD"))
        }
        
        func formatearPorcentaje(_ porcentaje: Decimal) -> String {
            porcentaje.formatted(.number.precision(.fractionLength(2))) + "%"
        }
    }
}
