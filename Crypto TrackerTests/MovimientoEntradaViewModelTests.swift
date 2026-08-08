import XCTest
@testable import Crypto_Tracker
import SwiftData

// MARK: - Tests

@MainActor
class MovimientoEntradaViewModelTests: XCTestCase {
    fileprivate var modelContext: ModelContext!
    fileprivate var viewModel: MovimientoEntradaViewModel!
    fileprivate var portfolio: Portfolio!
    fileprivate var cartera: Cartera!
    fileprivate var crypto: Crypto!
    fileprivate var fiat: FIAT!

    override func setUpWithError() throws {
        try super.setUpWithError()
        modelContext = TestSetup.createModelContext()
        portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(fiat)
        try modelContext.save()

        viewModel = MovimientoEntradaViewModel(modelContext: modelContext)
    }

    override func tearDown() {
        viewModel = nil
        modelContext = nil
        super.tearDown()
    }

    private func holding() throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try modelContext.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    // MARK: - Tests de Validación
    func testFormValidationWithValidData() {
        viewModel.selectedCrypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        viewModel.selectedCartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000

        XCTAssertTrue(viewModel.formIsValid)
    }

    func testFormValidationWithInvalidData() {
        viewModel.selectedCrypto = nil
        viewModel.selectedCartera = nil
        viewModel.cantidadCrypto = 0
        viewModel.precioUSD = 0

        XCTAssertFalse(viewModel.formIsValid)
    }

    func testFormValidationWithFIATAlterno() {
        viewModel.selectedCrypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        viewModel.selectedCartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        viewModel.valorTotalFiatAlterno = 45000

        XCTAssertTrue(viewModel.formIsValid)
    }

    // MARK: - Tests de Cálculos
    func testCalculoPrecioUSD() {
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        viewModel.cantidadCrypto = 1.0
        viewModel.valorTotalFiatAlterno = 45000

        viewModel.calcularPrecioUSD()

        let expectedUSD = Decimal(45000) / Decimal(1.1)
        XCTAssertEqual(viewModel.valorTotalUSD, expectedUSD, accuracy: 0.01)
    }

    func testCalculoValorTotalUSD() {
        viewModel.cantidadCrypto = 2.0
        viewModel.precioUSD = 50000

        viewModel.onCantidadCryptoChange()

        XCTAssertEqual(viewModel.valorTotalUSD, 100000)
    }

    // MARK: - Tests de Guardado
    func testGuardarMovimiento() async throws {
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000

        try await viewModel.save()

        // El movimiento se persistió
        let movimientos = try modelContext.fetch(FetchDescriptor<Movimiento>())
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = try XCTUnwrap(movimientos.first)
        XCTAssertEqual(movimiento.cantidadCrypto, 1.0)
        XCTAssertEqual(movimiento.precioUSD, 50000)
        XCTAssertEqual(movimiento.crypto?.simbolo, "BTC")
        XCTAssertEqual(movimiento.cartera?.nombre, "Test Wallet")

        // El holding se actualizó: el dashboard ya debe mostrar datos
        let holding = try holding()
        XCTAssertEqual(holding?.cantidad, 1.0)
    }

    func testGuardarMovimientoConFIATAlterno() async throws {
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = fiat
        viewModel.valorTotalFiatAlterno = 45000

        try await viewModel.save()

        let movimientos = try modelContext.fetch(FetchDescriptor<Movimiento>())
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = try XCTUnwrap(movimientos.first)
        XCTAssertTrue(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.fiatAlterno?.simbolo, "EUR")
        XCTAssertEqual(movimiento.valorTotalFiatAlterno, 45000)

        XCTAssertEqual(try holding()?.cantidad, 1.0)
    }

    // MARK: - Tests de Edición y Eliminación

    func testEditarMovimientoActualizaHolding() async throws {
        // Crear movimiento con 1.0 BTC
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        try await viewModel.save()
        XCTAssertEqual(try holding()?.cantidad, 1.0)

        // Editar a 2.0 BTC
        let movimiento = try XCTUnwrap(viewModel.movimiento)
        viewModel = MovimientoEntradaViewModel(
            modelContext: modelContext,
            movimiento: movimiento
        )
        viewModel.cantidadCrypto = 2.0
        viewModel.precioUSD = 50000
        try await viewModel.save()

        XCTAssertEqual(try holding()?.cantidad, 2.0)
    }

    func testEliminarMovimientoRevierteHolding() async throws {
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        try await viewModel.save()
        XCTAssertEqual(try holding()?.cantidad, 1.0)

        viewModel = MovimientoEntradaViewModel(
            modelContext: modelContext,
            movimiento: try XCTUnwrap(viewModel.movimiento)
        )
        try await viewModel.delete()

        let movimientos = try modelContext.fetch(FetchDescriptor<Movimiento>())
        XCTAssertEqual(movimientos.count, 0)
        XCTAssertNil(try holding())
    }

    func testSwipeDeleteSpentEntryIsRejectedAndPublishesError() async throws {
        let runner = ModelContextTransactionRunner(modelContext: modelContext)
        let holdingService = HoldingService()
        let registerUseCase = RegisterMovementUseCase(
            transactionRunner: runner,
            holdingService: holdingService
        )
        let deleteUseCase = DeleteMovementUseCase(
            transactionRunner: runner,
            holdingService: holdingService
        )
        let entry = try await registerUseCase.register(RegisterMovementInput(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50_000,
            usaFiatAlterno: false,
            precioFiatAlterno: nil,
            valorTotalFiatAlterno: nil,
            cartera: cartera,
            crypto: crypto,
            fiatAlterno: nil
        ))
        let exit = Movimiento.salida(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50_000,
            cartera: cartera,
            crypto: crypto
        )
        try await runner.run { context in
            context.insert(exit)
            try holdingService.updateHoldingForMovement(exit, in: context)
        }
        let listViewModel = MovimientosEntradaListViewModel(
            modelContext: modelContext,
            deleteUseCase: deleteUseCase
        )

        do {
            try await listViewModel.deleteMovimientos(at: IndexSet(integer: 0), from: [entry])
            XCTFail("Expected spent entry deletion to fail")
        } catch {
            XCTAssertTrue(listViewModel.hasError)
            XCTAssertFalse(listViewModel.errorMessage.isEmpty)
            XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Movimiento>()), 2)
            XCTAssertNil(try holding())
        }
    }
}
