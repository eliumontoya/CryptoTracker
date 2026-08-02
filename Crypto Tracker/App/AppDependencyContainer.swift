import Foundation
import SwiftUI
import SwiftData

@MainActor
class AppDependencyContainer {
    // Contexto de modelo
    let modelContext: ModelContext
    
    // Servicios
    let movimientosEntradaService: MovimientosEntradaServiceProtocol
    let priceService: PriceServiceProtocol
    
    // ViewModels compartidos
    let movimientoEntradaViewModel: MovimientoEntradaViewModel
    let movimientosEntradaListViewModel: MovimientosEntradaListViewModel
    let portfolioPorCryptosViewModel: PortfolioPorCryptosViewModel
    let portfolioDetalleViewModel: PortfolioDetalleViewModel
    let adminCarterasViewModel: AdminCarterasViewModel
    let adminCryptosViewModel: AdminCryptosViewModel
    let adminFiatViewModel: AdminFiatViewModel
    let cryptoSyncViewModel: CryptoSyncViewModel
    let cargaCatalogosViewModel: CargaCatalogosViewModel
    let cargaMovimientosViewModel: CargaMovimientosViewModel
    let eliminarDataViewModel: EliminarDataViewModel
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Inicializar servicios
        self.movimientosEntradaService = MovimientosEntradaService(modelContext: modelContext)
        self.priceService = PriceService()
        
        // Inicializar ViewModels individuales
        self.movimientoEntradaViewModel = MovimientoEntradaViewModel(
            movimientoService: movimientosEntradaService
        )
        
        // Inicializar ViewModel de lista
        self.movimientosEntradaListViewModel = MovimientosEntradaListViewModel(
            movimientoService: movimientosEntradaService
        )
        
        // Portfolio
        self.portfolioPorCryptosViewModel = PortfolioPorCryptosViewModel(
            modelContext: modelContext,
            movimientoService: movimientosEntradaService
        )
        self.portfolioDetalleViewModel = PortfolioDetalleViewModel(
            modelContext: modelContext
        )
        
        // Administración
        self.adminCarterasViewModel = AdminCarterasViewModel(modelContext: modelContext)
        self.adminCryptosViewModel = AdminCryptosViewModel(modelContext: modelContext)
        self.adminFiatViewModel = AdminFiatViewModel(modelContext: modelContext)
        self.cryptoSyncViewModel = CryptoSyncViewModel(modelContext: modelContext, priceService: priceService)
        
        // Setup inicial
        self.cargaCatalogosViewModel = CargaCatalogosViewModel(modelContext: modelContext)
        self.cargaMovimientosViewModel = CargaMovimientosViewModel(modelContext: modelContext)
        self.eliminarDataViewModel = EliminarDataViewModel(modelContext: modelContext)
    }
    
    // MARK: - ViewModel Factories
    
    func makeMovimientoEntradaViewModel(movimiento: Movimiento? = nil) -> MovimientoEntradaViewModel {
        if let movimiento = movimiento {
            return MovimientoEntradaViewModel(
                movimiento: movimiento,
                movimientoService: movimientosEntradaService
            )
        }
        return MovimientoEntradaViewModel(movimientoService: movimientosEntradaService)
    }
    
    func makeMovimientoSalidaViewModel(movimiento: Movimiento? = nil) -> MovimientoSalidaViewModel {
        MovimientoSalidaViewModel(modelContext: modelContext, movimiento: movimiento)
    }
    
    func makeMovimientoEntreCarterasViewModel(movimiento: Movimiento? = nil) -> MovimientoEntreCarterasViewModel {
        MovimientoEntreCarterasViewModel(modelContext: modelContext, movimiento: movimiento)
    }
    
    func makeMovimientoSwapViewModel(movimiento: Movimiento? = nil) -> MovimientoSwapViewModel {
        MovimientoSwapViewModel(modelContext: modelContext, movimiento: movimiento)
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
        PortfolioView()
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
    
    func makeCargaMovimientosInicialesView() -> CargaMovimientosInicialesView {
        CargaMovimientosInicialesView(dependencies: self)
    }
}
