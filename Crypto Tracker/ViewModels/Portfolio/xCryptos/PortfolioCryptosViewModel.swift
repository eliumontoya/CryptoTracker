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
    
    private let modelContext: ModelContext
    private let registerUseCase: RegisterMovementUseCaseProtocol
    private let editUseCase: EditMovementUseCaseProtocol
    private let deleteUseCase: DeleteMovementUseCaseProtocol

    init(modelContext: ModelContext,
         registerUseCase: RegisterMovementUseCaseProtocol,
         editUseCase: EditMovementUseCaseProtocol,
         deleteUseCase: DeleteMovementUseCaseProtocol) {
        self.modelContext = modelContext
        self.registerUseCase = registerUseCase
        self.editUseCase = editUseCase
        self.deleteUseCase = deleteUseCase
    }
    
    // MARK: - Public Methods
    func actualizarPortfolio() {
        isLoading = true
        
        guard let portfolio = PortfolioQueries.defaultPortfolio(in: modelContext) else {
            cryptoSummaries = []
            isLoading = false
            return
        }
        
        cryptoSummaries = PortfolioCryptoCalculator.calcularResumenPorCrypto(
            portfolioId: portfolio.id,
            in: modelContext
        )
        isLoading = false
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
                modelContext: self.modelContext,
                registerUseCase: self.registerUseCase,
                editUseCase: self.editUseCase,
                deleteUseCase: self.deleteUseCase
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
