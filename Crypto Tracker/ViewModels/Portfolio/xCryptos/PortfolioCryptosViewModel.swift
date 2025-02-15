import Foundation
import SwiftData
import Combine

@MainActor
final class PortfolioPorCryptosViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var cryptoSummaries: [CryptoPortfolioSummary] = []
    @Published var selectedCrypto: Crypto?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Estados para forms de movimientos
    @Published var showingEntradaForm = false
    @Published var showingSalidaForm = false
    @Published var showingEntreCarterasForm = false
    @Published var showingSwapForm = false
    
    var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    func actualizarPortfolio(carteras: [Cartera], cryptos: [Crypto]) {
        isLoading = true
        
        do {
            cryptoSummaries = PortfolioCryptoCalculator.calcularResumenPorCrypto(
                carteras: carteras,
                cryptos: cryptos
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Navigation Methods
    func crearFormMovimientoEntrada() -> MovimientoEntradaFormView {
        MovimientoEntradaFormView(
            viewModel: MovimientoEntradaViewModel(
                modelContext: self.modelContext
            )
        )
    }
    
    func crearFormMovimientoSalida() -> MovimientoSalidaFormView {
        MovimientoSalidaFormView(
            viewModel: MovimientoSalidaViewModel(
                modelContext: self.modelContext
            )
        )
    }
    
    func crearFormMovimientoEntreCarteras() -> MovimientoEntreCarterasFormView {
        MovimientoEntreCarterasFormView(
            viewModel: MovimientoEntreCarterasViewModel(
                modelContext: self.modelContext
            )
        )
    }
    
    func crearFormMovimientoSwap() -> MovimientoSwapFormView {
        MovimientoSwapFormView(
            viewModel: MovimientoSwapViewModel(
                modelContext: self.modelContext
            )
        )
    }
}
