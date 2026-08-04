import Foundation
import SwiftUI
import SwiftData

@MainActor
class AppDependencyContainer {
    // Contexto de modelo
    let modelContext: ModelContext
    
    // Servicios
    let transactionRunner: TransactionRunner
    let holdingService: HoldingServiceProtocol
    let priceService: PriceService
    let snapshotService: SnapshotService
    let backupService: BackupService
    let registerMovementUseCase: RegisterMovementUseCaseProtocol
    
    // Use cases
    let editMovementUseCase: EditMovementUseCaseProtocol
    
    // Use cases
    let deleteMovementUseCase: DeleteMovementUseCaseProtocol
    
    // Use cases
    let moveBetweenWalletsUseCase: MoveBetweenWalletsUseCaseProtocol
    
    // Use cases
    let swapMovementUseCase: SwapMovementUseCaseProtocol
    
    // Use cases
    let adjustHoldingUseCase: AdjustHoldingUseCaseProtocol
    
    // ViewModels compartidos
    let movimientoEntradaViewModel: MovimientoEntradaViewModel
    let movimientosEntradaListViewModel: MovimientosEntradaListViewModel
    let portfolioViewModel: PortfolioViewModel
    let portfolioPorCryptosViewModel: PortfolioPorCryptosViewModel
    let portfolioDetalleViewModel: PortfolioDetalleViewModel
    let adminCarterasViewModel: AdminCarterasViewModel
    let adminCryptosViewModel: AdminCryptosViewModel
    let adminFiatViewModel: AdminFiatViewModel
    let adminPortfoliosViewModel: AdminPortfoliosViewModel
    let cryptoSyncViewModel: CryptoSyncViewModel
    let cargaCatalogosViewModel: CargaCatalogosViewModel
    let cargaMovimientosViewModel: CargaMovimientosViewModel
    let eliminarDataViewModel: EliminarDataViewModel
    let backupViewModel: BackupViewModel
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Inicializar servicios
        self.transactionRunner = ModelContextTransactionRunner(modelContext: modelContext)
        self.holdingService = HoldingService()
        self.priceService = CoinGeckoPriceService()
        self.snapshotService = SwiftDataSnapshotService()
        self.backupService = JSONBackupService()
        self.registerMovementUseCase = RegisterMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar use cases
        self.editMovementUseCase = EditMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar use cases
        self.deleteMovementUseCase = DeleteMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar use cases
        self.moveBetweenWalletsUseCase = MoveBetweenWalletsUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar use cases
        self.swapMovementUseCase = SwapMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar use cases
        self.adjustHoldingUseCase = AdjustHoldingUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        
        // Inicializar ViewModels individuales
        self.movimientoEntradaViewModel = MovimientoEntradaViewModel(
            modelContext: modelContext,
            registerUseCase: registerMovementUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
        
        // Inicializar ViewModel de lista
        self.movimientosEntradaListViewModel = MovimientosEntradaListViewModel(
            modelContext: modelContext
        )
        
        // Portfolio
        self.portfolioViewModel = PortfolioViewModel(
            modelContext: modelContext,
            snapshotService: snapshotService
        )
        self.portfolioPorCryptosViewModel = PortfolioPorCryptosViewModel(
            modelContext: modelContext,
            registerUseCase: registerMovementUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
        self.portfolioDetalleViewModel = PortfolioDetalleViewModel(
            modelContext: modelContext
        )
        
        // Administración
        self.adminCarterasViewModel = AdminCarterasViewModel(modelContext: modelContext)
        self.adminCryptosViewModel = AdminCryptosViewModel(modelContext: modelContext)
        self.adminFiatViewModel = AdminFiatViewModel(modelContext: modelContext)
        self.adminPortfoliosViewModel = AdminPortfoliosViewModel(modelContext: modelContext)
        self.cryptoSyncViewModel = CryptoSyncViewModel(modelContext: modelContext, priceService: priceService)
        
        // Setup inicial
        self.cargaCatalogosViewModel = CargaCatalogosViewModel(modelContext: modelContext)
        self.cargaMovimientosViewModel = CargaMovimientosViewModel(modelContext: modelContext, holdingService: holdingService)
        self.eliminarDataViewModel = EliminarDataViewModel(modelContext: modelContext)
        self.backupViewModel = BackupViewModel(
            modelContext: modelContext,
            backupService: backupService
        )
    }
    
    // MARK: - ViewModel Factories
    
    func makeMovimientoEntradaViewModel(movimiento: Movimiento? = nil) -> MovimientoEntradaViewModel {
        MovimientoEntradaViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            registerUseCase: registerMovementUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
    }
    
    func makeMovimientoSalidaViewModel(movimiento: Movimiento? = nil) -> MovimientoSalidaViewModel {
        MovimientoSalidaViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            registerUseCase: registerMovementUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
    }
    
    func makeMovimientoEntreCarterasViewModel(movimiento: Movimiento? = nil) -> MovimientoEntreCarterasViewModel {
        MovimientoEntreCarterasViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            moveBetweenWalletsUseCase: moveBetweenWalletsUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
    }
    
    func makeMovimientoSwapViewModel(movimiento: Movimiento? = nil) -> MovimientoSwapViewModel {
        MovimientoSwapViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            swapUseCase: swapMovementUseCase,
            editUseCase: editMovementUseCase,
            deleteUseCase: deleteMovementUseCase
        )
    }
    
    func makeCarteraMovimientosViewModel(cartera: Cartera) -> CarteraMovimientosViewModel {
        CarteraMovimientosViewModel(cartera: cartera, modelContext: modelContext)
    }
    
    func makeCarteraCryptoDetailViewModel(crypto: Crypto, cartera: Cartera) -> CarteraCryptoDetailViewModel {
        CarteraCryptoDetailViewModel(crypto: crypto, cartera: cartera)
    }
    
    func makeCryptoDetailViewModel(crypto: Crypto, carteras: [Cartera] = []) -> CryptoDetailViewModel {
        CryptoDetailViewModel(crypto: crypto, carteras: carteras)
    }
    
    // MARK: - View Factories (Portfolio)
    
    func makePortfolioView() -> PortfolioView {
        PortfolioView(viewModel: portfolioViewModel)
    }
    
    func makePortfolioPorCryptosView() -> PortfolioPorCryptosView {
        PortfolioPorCryptosView(viewModel: portfolioPorCryptosViewModel, dependencies: self)
    }
    
    func makePortfolioDetalleView() -> PortfolioDetalleView {
        PortfolioDetalleView(viewModel: portfolioDetalleViewModel, dependencies: self)
    }
    
    func makeCarteraMovimientosView(cartera: Cartera) -> CarteraMovimientosView {
        CarteraMovimientosView(cartera: cartera, dependencies: self)
    }
    
    func makeCarteraDetailView(
        carteraDetail: CarteraDetail,
        onUpdateData: @escaping () -> Void
    ) -> CarteraDetailView {
        CarteraDetailView(carteraDetail: carteraDetail, onUpdateData: onUpdateData, dependencies: self)
    }
    
    func makeCarteraCryptoDetailView(crypto: Crypto, cartera: Cartera) -> CarteraCryptoDetailView {
        CarteraCryptoDetailView(crypto: crypto, cartera: cartera, dependencies: self)
    }
    
    func makeCryptoDetailView(crypto: Crypto) -> CryptoDetailView {
        CryptoDetailView(crypto: crypto, dependencies: self)
    }
    
    // MARK: - View Factories (Movimientos)
    
    func makeMovimientosEntradaView() -> MovimientosEntradaView {
        MovimientosEntradaView(viewModel: movimientosEntradaListViewModel)
    }
    
    func makeMovimientoEntradaFormView(movimiento: Movimiento? = nil) -> MovimientoEntradaFormView {
        // Si se proporciona un movimiento, creamos un ViewModel específico para él
        if let movimiento = movimiento {
            let viewModel = makeMovimientoEntradaViewModel(movimiento: movimiento)
            return MovimientoEntradaFormView(viewModel: viewModel)
        } else {
            // Para nuevos movimientos, usamos el ViewModel compartido
            // pero reseteando su estado
            movimientoEntradaViewModel.unloadMovimiento()
            return MovimientoEntradaFormView(viewModel: movimientoEntradaViewModel)
        }
    }
    
    func makeMovimientoSalidaFormView(movimiento: Movimiento? = nil) -> MovimientoSalidaFormView {
        MovimientoSalidaFormView(viewModel: self.makeMovimientoSalidaViewModel(movimiento: movimiento))
    }
    
    func makeMovimientoEntreCarterasFormView(movimiento: Movimiento? = nil) -> MovimientoEntreCarterasFormView {
        MovimientoEntreCarterasFormView(viewModel: self.makeMovimientoEntreCarterasViewModel(movimiento: movimiento))
    }
    
    func makeMovimientoSwapFormView(movimiento: Movimiento? = nil) -> MovimientoSwapFormView {
        MovimientoSwapFormView(viewModel: self.makeMovimientoSwapViewModel(movimiento: movimiento))
    }
    
    func makeMovimientosSalidaView() -> MovimientosSalidaView {
        MovimientosSalidaView(dependencies: self)
    }
    
    func makeMovimientosEntreCarterasView() -> MovimientosEntreCarterasView {
        MovimientosEntreCarterasView(dependencies: self)
    }
    
    func makeMovimientosSwapsView() -> MovimientosSwapsView {
        MovimientosSwapsView(dependencies: self)
    }

    func makeMovimientosSearchFilterView() -> MovimientosSearchFilterView {
        MovimientosSearchFilterView(dependencies: self)
    }
    
    func makeMovimientoSearchView(movimientoDetalle: MovimientoDetalle) -> MovimientoSearchView {
        MovimientoSearchView(movimientoDetalle: movimientoDetalle, dependencies: self)
    }
    
    // MARK: - View Factories (Admin)
    
    func makeAdminCryptosView() -> AdminCryptosView {
        AdminCryptosView(viewModel: adminCryptosViewModel)
    }
    
    func makeAdminCarterasView() -> AdminCarterasView {
        AdminCarterasView(viewModel: adminCarterasViewModel)
    }
    
    func makeAdminFiatView() -> AdminFiatView {
        AdminFiatView(viewModel: adminFiatViewModel)
    }
    
    func makeAdminPortfoliosView() -> AdminPortfoliosView {
        AdminPortfoliosView(viewModel: adminPortfoliosViewModel)
    }

    func recargarCatalogosAdmin() {
        adminCarterasViewModel.loadCarteras()
        adminCarterasViewModel.loadPortfolios()
        adminCryptosViewModel.loadCryptos()
        adminFiatViewModel.loadFiats()
        adminPortfoliosViewModel.loadPortfolios()

        adminCarterasViewModel.clearCache()
        adminCryptosViewModel.clearCache()
        adminFiatViewModel.clearCache()

        // Limpiar portfolios para evitar referencias a objetos eliminados
        portfolioPorCryptosViewModel.cryptoSummaries = []
        portfolioDetalleViewModel.carterasDetail = []
        portfolioViewModel.clear()
    }
    
    func makeCryptoSyncView() -> CryptoSyncView {
        CryptoSyncView(viewModel: cryptoSyncViewModel)
    }
    
    func makeSetupInicialView() -> SetupInicialView {
        SetupInicialView(dependencies: self)
    }
    
    func makeCargaCatalogosView() -> CargaCatalogosView {
        CargaCatalogosView(dependencies: self)
    }
    
    func makeEliminarDataView() -> EliminarDataView {
        EliminarDataView(dependencies: self)
    }
    
    func makeBackupView() -> BackupView {
        BackupView(viewModel: backupViewModel)
    }
    
    func makeCargaMovimientosInicialesView() -> CargaMovimientosInicialesView {
        CargaMovimientosInicialesView(dependencies: self)
    }
}
