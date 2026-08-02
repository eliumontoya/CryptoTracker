import Foundation
import SwiftData
extension Cartera {
    func getCryptoDisponible(crypto: Crypto, movimientoActual: Decimal = 0) -> Decimal {
        BalanceCalculator.balance(crypto: crypto, en: self, movimientoActual: movimientoActual)
    }
}
