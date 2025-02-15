import Foundation
import SwiftData
@testable import Crypto_Tracker

/// Clase de utilidades para configuración de pruebas
@MainActor
class TestSetup {
    /// Crea un contexto de modelo en memoria para pruebas
    static func createModelContext() -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Crypto.self,
            Cartera.self,
            FIAT.self,
            MovimientoEgreso.self,
            configurations: configuration
        )
        return container.mainContext
    }
    
    /// Configura un escenario de prueba complejo
    static func setupComplexScenario(
        in context: ModelContext,
        cryptoAmount: Decimal = 100,
        cryptoPrice: Decimal = 50000
    ) -> (Crypto, Cartera, FIAT) {
        let crypto = Crypto.mock(precio: cryptoPrice)
        let cartera = Cartera.mock()
        let fiat = FIAT.mock()
        
        context.insert(crypto)
        context.insert(cartera)
        context.insert(fiat)
        
        return (crypto, cartera, fiat)
    }
}
