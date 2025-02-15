import Foundation
import SwiftData
@testable import Crypto_Tracker

extension Crypto {
    /// Mock para crear una instancia de Crypto para pruebas
    static func mock(
        nombre: String = "TEST_Bitcoin",
        simbolo: String = "TEST_BTC",
        precio: Decimal = 50000,
        ultimaActualizacion: Date = Date()
    ) -> Crypto {
        let crypto = Crypto(nombre: nombre, simbolo: simbolo, precio: precio)
        crypto.ultimaActualizacion = ultimaActualizacion
        return crypto
    }
}

extension Cartera {
    /// Mock para crear una instancia de Cartera para pruebas
    static func mock(
        nombre: String = "TEST_Cartera Principal",
        simbolo: String = "TEST_MAIN"
    ) -> Cartera {
        return Cartera(nombre: nombre, simbolo: simbolo)
    }
    
    /// Método de prueba para simular saldo de crypto
    func getCryptoDisponible(crypto: Crypto, movimientoActual: Decimal? = nil) -> Decimal {
        // Implementación para pruebas, puedes ajustar según necesites
        return 100
    }
}

extension FIAT {
    /// Mock para crear una instancia de FIAT para pruebas
    static func mock(
        nombre: String = "TEST_Dólar",
        simbolo: String = "TEST_USD",
        precioUSD: Decimal = 1.0
    ) -> FIAT {
        return FIAT(nombre: nombre, simbolo: simbolo, precioUSD: precioUSD)
    }
}
