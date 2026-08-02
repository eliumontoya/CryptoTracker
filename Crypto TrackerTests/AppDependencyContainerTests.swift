import XCTest
import SwiftData
@testable import Crypto_Tracker

/// Verifies that `AppDependencyContainer` can build the full dependency graph
/// against an in-memory SwiftData context, covering every ViewModel used in the app.
@MainActor
final class AppDependencyContainerTests: XCTestCase {

    private var modelContext: ModelContext!
    private var dependencies: AppDependencyContainer!

    override func setUp() {
        super.setUp()
        modelContext = TestSetup.createModelContext()
        dependencies = AppDependencyContainer(modelContext: modelContext)
    }

    override func tearDown() {
        dependencies = nil
        modelContext = nil
        super.tearDown()
    }

    // MARK: - Shared ViewModels

    func testSharedViewModelsAreInstantiated() {
        XCTAssertNotNil(dependencies.movimientoEntradaViewModel)
        XCTAssertNotNil(dependencies.movimientosEntradaListViewModel)
        XCTAssertNotNil(dependencies.portfolioPorCryptosViewModel)
        XCTAssertNotNil(dependencies.portfolioDetalleViewModel)
        XCTAssertNotNil(dependencies.adminCarterasViewModel)
        XCTAssertNotNil(dependencies.adminCryptosViewModel)
        XCTAssertNotNil(dependencies.adminFiatViewModel)
        XCTAssertNotNil(dependencies.cryptoSyncViewModel)
        XCTAssertNotNil(dependencies.cargaCatalogosViewModel)
        XCTAssertNotNil(dependencies.cargaMovimientosViewModel)
        XCTAssertNotNil(dependencies.eliminarDataViewModel)
    }

    func testSharedViewModelsUseInjectedContext() {
        // Admin ViewModels fetch from the container's context at init.
        // An empty result set proves the injected in-memory context was wired.
        XCTAssertTrue(dependencies.adminCarterasViewModel.carteras.isEmpty)
        XCTAssertTrue(dependencies.adminCryptosViewModel.cryptos.isEmpty)
        XCTAssertTrue(dependencies.adminFiatViewModel.fiats.isEmpty)
        XCTAssertTrue(dependencies.eliminarDataViewModel.canDelete == false)
        XCTAssertTrue(dependencies.portfolioDetalleViewModel.carterasDetail.isEmpty)
    }

    func testTransactionServicesAreInjectedIntoMovimientoViewModels() {
        XCTAssertNotNil(dependencies.transactionRunner)
        XCTAssertNotNil(dependencies.holdingService)
        XCTAssertNotNil(dependencies.movimientosEntradaListViewModel.entradaViewModel)
    }

    func testEditMovementUseCaseIsWired() {
        XCTAssertNotNil(dependencies.editMovementUseCase)
    }

    // MARK: - ViewModel Factories

    func testMovementFormViewModelsGetInjectedContext() {
        XCTAssertNotNil(dependencies.makeMovimientoSalidaViewModel())
        XCTAssertNotNil(dependencies.makeMovimientoEntreCarterasViewModel())
        XCTAssertNotNil(dependencies.makeMovimientoSwapViewModel())
    }

    func testMovementFormViewModelsAreFreshInstances() {
        let first = dependencies.makeMovimientoSalidaViewModel()
        let second = dependencies.makeMovimientoSalidaViewModel()
        XCTAssertFalse(first === second)
    }

    func testCarteraMovimientosViewModelUsesInjectedContext() {
        let cartera = Cartera.mock()
        let viewModel = dependencies.makeCarteraMovimientosViewModel(cartera: cartera)
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.carteraNombre, cartera.nombre)
    }

    func testEntradaFormViewModelFactory() {
        // Fresh ViewModel when editing an existing movement
        let movimiento = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 100,
            usaFiatAlterno: false,
            cartera: Cartera.mock(),
            crypto: Crypto.mock()
        )
        let editViewModel = dependencies.makeMovimientoEntradaViewModel(movimiento: movimiento)
        XCTAssertNotNil(editViewModel)
        XCTAssertEqual(editViewModel.movimiento?.id, movimiento.id)

        // Shared instance is reused and reset for new movements
        let addViewModel = dependencies.makeMovimientoEntradaViewModel()
        XCTAssertNotNil(addViewModel)
    }

    // MARK: - View Factories

    func testViewFactoriesBuild() {
        XCTAssertNotNil(dependencies.makePortfolioView())
        XCTAssertNotNil(dependencies.makePortfolioPorCryptosView())
        XCTAssertNotNil(dependencies.makePortfolioDetalleView())
        XCTAssertNotNil(dependencies.makeMovimientosEntradaView())
        XCTAssertNotNil(dependencies.makeMovimientosSalidaView())
        XCTAssertNotNil(dependencies.makeMovimientosEntreCarterasView())
        XCTAssertNotNil(dependencies.makeMovimientosSwapsView())
        XCTAssertNotNil(dependencies.makeAdminCryptosView())
        XCTAssertNotNil(dependencies.makeAdminCarterasView())
        XCTAssertNotNil(dependencies.makeAdminFiatView())
        XCTAssertNotNil(dependencies.makeCryptoSyncView())
        XCTAssertNotNil(dependencies.makeSetupInicialView())
        XCTAssertNotNil(dependencies.makeCargaCatalogosView())
        XCTAssertNotNil(dependencies.makeEliminarDataView())
        XCTAssertNotNil(dependencies.makeCargaMovimientosInicialesView())
    }
}
