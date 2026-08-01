import Foundation
import SwiftData

// MARK: - Modelos de Portfolio
struct CryptoDetail: Identifiable {
    var id: UUID { crypto.id }
    let crypto: Crypto
    var totalCryptoIngresado: Decimal    // Total de crypto ingresado (entradas + swaps destino)
    var totalCryptoVendido: Decimal      // Total de crypto vendido (salidas + swaps origen)
    var totalCryptoTransferido: Decimal  // Balance neto de transferencias
    var balanceActual: Decimal
    var totalInvertidoUSD: Decimal       // Total USD invertido en entradas
    var valorUSD: Decimal
    var ganancia: Decimal
    
    // Calcular el porcentaje de ganancia/pérdida
    var porcentajeGanancia: Decimal {
        guard totalInvertidoUSD != 0 else { return 0 }
        return ((valorUSD - totalInvertidoUSD) / totalInvertidoUSD) * 100
    }
}

struct CarteraDetail: Identifiable {
    var id: UUID { cartera.id }
    let cartera: Cartera
    var cryptoDetails: [CryptoDetail]
    
    var valorTotalUSD: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.valorUSD }
    }
    
    var totalInvertidoUSD: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.totalInvertidoUSD }
    }
    
    var gananciaTotal: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.ganancia }
    }
    
    var rentabilidadTotal: Decimal {
        guard totalInvertidoUSD > 0 else { return 0 }
        return ((valorTotalUSD - totalInvertidoUSD) / totalInvertidoUSD) * 100
    }
}
