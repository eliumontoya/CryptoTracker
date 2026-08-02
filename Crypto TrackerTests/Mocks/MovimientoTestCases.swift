import Foundation
import SwiftData
@testable import Crypto_Tracker

/// Reusable test scenarios for movement forms.
@MainActor
enum MovimientoTestCases {
    /// Invalid form-validation scenarios.
    static let invalidValidationScenarios: [(MovimientoSalidaViewModel) -> Void] = [
        // No selected crypto
        { viewModel in
            viewModel.selectedCartera = Cartera.mock()
            viewModel.cantidadCrypto = 50
            assert(!viewModel.formIsValid)
        },
        // No selected wallet
        { viewModel in
            viewModel.selectedCrypto = Crypto.mock()
            viewModel.cantidadCrypto = 50
            assert(!viewModel.formIsValid)
        }
    ]
}
