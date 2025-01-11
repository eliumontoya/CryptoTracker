import Foundation
import SwiftData
extension Cartera {
    func getCryptoDisponible(crypto: Crypto, movimientoActual: Decimal = 0) -> Decimal {
        let ingresos = movimientosIngreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }
        
        let egresos = movimientosEgreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCrypto }
        
        let transferenciasEntrada = movimientosEntrada
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoEntrada }
        
        let transferenciasSalida = movimientosSalida
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadCryptoSalida }
        
        let swapsEntrada = swaps
            .filter { $0.cryptoDestino?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadDestino }
        
        let swapsSalida = swaps
            .filter { $0.cryptoOrigen?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 += $1.cantidadOrigen }
        
        return ingresos + transferenciasEntrada + swapsEntrada + movimientoActual -
               (egresos + transferenciasSalida + swapsSalida)
    }
}
