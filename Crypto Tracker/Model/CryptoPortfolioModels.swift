import Foundation
import SwiftData

// MARK: - Modelo de datos para el resumen por crypto
struct CryptoPortfolioSummary: Identifiable {
    var id: UUID { crypto.id }
    let crypto: Crypto
    var totalDisponible: Decimal
    var precioActual: Decimal
    var totalUSDAdquirido: Decimal
    var valorActualUSD: Decimal
    var totalUSDVentas: Decimal
    var gananciaUSD: Decimal
    
    var porcentajeGanancia: Decimal {
        guard totalUSDAdquirido > 0 else { return 0 }
        return ((valorActualUSD - totalUSDAdquirido) / totalUSDAdquirido) * 100
    }
}
