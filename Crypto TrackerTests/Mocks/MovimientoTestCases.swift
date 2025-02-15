import Foundation
import SwiftData
@testable import Crypto_Tracker

/// Estructura para definir casos de prueba reutilizables
@MainActor
enum MovimientoTestCases {
    /// Escenarios de validación inválida
    static let invalidValidationScenarios: [(MovimientoSalidaViewModel) -> Void] = [
        // Sin crypto seleccionada
        { viewModel in
            viewModel.selectedCartera = Cartera.mock()
            viewModel.cantidadCrypto = 50
            assert(!viewModel.formIsValid)
        },
        // Sin cartera seleccionada
        { viewModel in
            viewModel.selectedCrypto = Crypto.mock()
            viewModel.cantidadCrypto = 50
            assert(!viewModel.formIsValid)
        }
    ]
    
    /// Escenarios de casos límite
    static let edgeCaseScenarios: [(ModelContext) -> Void] = [
        // Prueba con cantidades muy pequeñas
        { context in
            let (crypto, cartera, _) = TestSetup.setupComplexScenario(in: context, cryptoAmount: 0.00001)
            let viewModel = MovimientoSalidaViewModel(modelContext: context)
            viewModel.selectedCrypto = crypto
            viewModel.selectedCartera = cartera
            viewModel.cantidadCrypto = 0.000005
            
            assert(viewModel.formIsValid)
        }
    ]
}
