import XCTest
@testable import Crypto_Tracker
import SwiftData

// MARK: - Mock Service

fileprivate class MockMovimientosEntradaService: MovimientosEntradaServiceProtocol {
    var savedMovimientos: [MovimientoIngreso] = []
    var insertedMovimientos: [MovimientoIngreso] = []
    var deletedMovimientos: [MovimientoIngreso] = []

    func save(movimiento: MovimientoIngreso) throws {
        savedMovimientos.append(movimiento)
    }

    func insert(movimiento: MovimientoIngreso) throws {
        insertedMovimientos.append(movimiento)
    }

    func delete(movimiento: MovimientoIngreso) throws {
        deletedMovimientos.append(movimiento)
    }

    func fetch() throws -> [MovimientoIngreso] {
        return savedMovimientos + insertedMovimientos
    }

    func fetchSorted() throws -> [MovimientoIngreso] {
        return savedMovimientos + insertedMovimientos
    }

    func checkCryptoDisponible(crypto: Crypto, cartera: Cartera) -> Decimal {
        return 999
    }
}

// MARK: - Tests

@MainActor
class MovimientoEntradaViewModelTests: XCTestCase {
    fileprivate var mockService: MockMovimientosEntradaService!
    fileprivate var viewModel: MovimientoEntradaViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockService = MockMovimientosEntradaService()
        viewModel = MovimientoEntradaViewModel(movimiento: nil, movimientoService: mockService)
    }

    override func tearDown() {
        mockService = nil
        viewModel = nil
        super.tearDown()
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
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000

        try await viewModel.save()

        XCTAssertEqual(mockService.insertedMovimientos.count, 1)
        let movimiento = mockService.insertedMovimientos.first
        XCTAssertEqual(movimiento?.cantidadCrypto, 1.0)
        XCTAssertEqual(movimiento?.precioUSD, 50000)
        XCTAssertEqual(movimiento?.crypto?.simbolo, "BTC")
        XCTAssertEqual(movimiento?.cartera?.nombre, "Test Wallet")
    }

    func testGuardarMovimientoConFIATAlterno() async throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)

        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = fiat
        viewModel.valorTotalFiatAlterno = 45000

        try await viewModel.save()

        XCTAssertEqual(mockService.insertedMovimientos.count, 1)
        let movimiento = mockService.insertedMovimientos.first
        XCTAssertTrue(movimiento?.usaFiatAlterno ?? false)
        XCTAssertEqual(movimiento?.fiatAlterno?.simbolo, "EUR")
        XCTAssertEqual(movimiento?.valorTotalFiatAlterno, 45000)
    }
}
