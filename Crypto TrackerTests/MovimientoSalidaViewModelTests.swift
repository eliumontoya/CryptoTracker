import XCTest
import SwiftData
import Combine
@testable import Crypto_Tracker

/// Verifies `MovimientoSalidaViewModel` delegates persistence to the domain use cases
/// (`RegisterMovementUseCase`, `EditMovementUseCase`, `DeleteMovementUseCase`) while keeping
/// form validation and FIAT-alternate calculations in the ViewModel.
@MainActor
final class MovimientoSalidaViewModelTests: XCTestCase {

    var modelContext: ModelContext!
    var registerUseCase: RegisterMovementUseCaseProtocol!
    var editUseCase: EditMovementUseCaseProtocol!
    var deleteUseCase: DeleteMovementUseCaseProtocol!
    var viewModel: MovimientoSalidaViewModel!

    var portfolio: Portfolio!
    var mockCrypto: Crypto!
    var mockCartera: Cartera!
    var mockFiatAlterno: FIAT!

    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        do {
            modelContext = TestSetup.createModelContext()

            portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
            mockCrypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
            mockCartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
            mockFiatAlterno = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)

            modelContext.insert(portfolio)
            modelContext.insert(mockCrypto)
            modelContext.insert(mockCartera)
            modelContext.insert(mockFiatAlterno)
            try modelContext.save()

            let transactionRunner = ModelContextTransactionRunner(modelContext: modelContext)
            let holdingService = HoldingService()
            registerUseCase = RegisterMovementUseCase(
                transactionRunner: transactionRunner,
                holdingService: holdingService
            )
            editUseCase = EditMovementUseCase(
                transactionRunner: transactionRunner,
                holdingService: holdingService
            )
            deleteUseCase = DeleteMovementUseCase(
                transactionRunner: transactionRunner,
                holdingService: holdingService
            )

            // Seed an entry movement and a matching holding so the wallet has enough balance
            // for both form validation (BalanceCalculator) and exit use-case validation (Holding).
            let entry = Movimiento.entrada(
                fecha: Date(),
                cantidadCrypto: 100,
                precioUSD: 50000,
                usaFiatAlterno: false,
                cartera: mockCartera,
                crypto: mockCrypto
            )
            modelContext.insert(entry)
            modelContext.insert(
                Holding(portfolio: portfolio, cartera: mockCartera, crypto: mockCrypto, cantidad: 100)
            )
            try modelContext.save()

            viewModel = makeViewModel()
        } catch {
            XCTFail("Error en la configuración inicial: \(error)")
        }
    }

    override func tearDown() {
        viewModel = nil
        registerUseCase = nil
        editUseCase = nil
        deleteUseCase = nil
        modelContext = nil
        portfolio = nil
        mockCrypto = nil
        mockCartera = nil
        mockFiatAlterno = nil
        cancellables.removeAll()

        super.tearDown()
    }

    private func makeViewModel(movimiento: Movimiento? = nil) -> MovimientoSalidaViewModel {
        MovimientoSalidaViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            registerUseCase: registerUseCase,
            editUseCase: editUseCase,
            deleteUseCase: deleteUseCase
        )
    }

    // MARK: - Initialization

    func testInitialization() {
        XCTAssertNotNil(viewModel)

        XCTAssertLessThan(abs(viewModel.fecha.timeIntervalSinceNow), 1)
        XCTAssertNil(viewModel.selectedCrypto)
        XCTAssertNil(viewModel.selectedCartera)
        XCTAssertEqual(viewModel.cantidadCrypto, 0)
        XCTAssertEqual(viewModel.precioUSD, 0)
        XCTAssertEqual(viewModel.valorTotalUSD, 0)
        XCTAssertFalse(viewModel.usaFiatAlterno)
        XCTAssertNil(viewModel.selectedFiatAlterno)
        XCTAssertEqual(viewModel.valorTotalFiatAlterno, 0)
    }

    // MARK: - Form Validation

    func testInvalidValidationScenarios() {
        MovimientoTestCases.invalidValidationScenarios.forEach { scenario in
            viewModel = makeViewModel()
            scenario(viewModel)
        }
    }

    func testFormValidation_ValidWithBasicData() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 50
        viewModel.precioUSD = 1000

        XCTAssertTrue(viewModel.formIsValid)
    }

    func testFormValidation_ValidWithFiatAlterno() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 50
        viewModel.precioUSD = 1000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = mockFiatAlterno
        viewModel.valorTotalFiatAlterno = 55000

        XCTAssertTrue(viewModel.formIsValid)
    }

    func testFormValidation_InvalidWithExceedingAmount() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 150
        viewModel.precioUSD = 1000

        XCTAssertFalse(viewModel.formIsValid)
    }

    // MARK: - Calculations

    func testOnCantidadCryptoChange() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.precioUSD = 1000
        viewModel.cantidadCrypto = 150

        viewModel.onCantidadCryptoChange()

        XCTAssertEqual(viewModel.cantidadCrypto, 100)
        XCTAssertEqual(viewModel.valorTotalUSD, 100 * 1000)
    }

    func testCalcularPrecioUSD_WithFiatAlterno() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = mockFiatAlterno
        viewModel.cantidadCrypto = 50
        viewModel.valorTotalFiatAlterno = 55000

        viewModel.calcularPrecioUSD()

        XCTAssertEqual(viewModel.precioUSD, 1000, accuracy: 0.001)
        XCTAssertEqual(viewModel.valorTotalUSD, 50000, accuracy: 0.001)
    }

    // MARK: - Save

    func testSave_Success() async throws {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 50
        viewModel.precioUSD = 1000
        viewModel.valorTotalUSD = 50000

        try await viewModel.save()

        XCTAssertFalse(viewModel.isLoading)

        let fetchRequest = FetchDescriptor<Movimiento>(predicate: #Predicate { $0.tipoRaw == "salida" })
        let movimientos = try modelContext.fetch(fetchRequest)

        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos.first!

        XCTAssertEqual(movimiento.cantidadCrypto, 50)
        XCTAssertEqual(movimiento.precioUSD, 1000)
        XCTAssertEqual(movimiento.valorTotalUSD, 50000)
        XCTAssertFalse(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.cartera?.id, mockCartera.id)
        XCTAssertEqual(movimiento.crypto?.id, mockCrypto.id)
    }

    func testSave_SuccessWithFiatAlterno() async throws {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 50
        viewModel.precioUSD = 1000
        viewModel.valorTotalUSD = 50000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = mockFiatAlterno
        viewModel.valorTotalFiatAlterno = 55000

        try await viewModel.save()

        XCTAssertFalse(viewModel.isLoading)

        let fetchRequest = FetchDescriptor<Movimiento>(predicate: #Predicate { $0.tipoRaw == "salida" })
        let movimientos = try modelContext.fetch(fetchRequest)

        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos.first!

        XCTAssertEqual(movimiento.cantidadCrypto, 50)
        XCTAssertEqual(movimiento.precioUSD, 1000)
        XCTAssertEqual(movimiento.valorTotalUSD, 50000)
        XCTAssertTrue(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.fiatAlterno?.id, mockFiatAlterno.id)
        XCTAssertEqual(movimiento.valorTotalFiatAlterno, 55000)
    }

    // MARK: - Delete

    func testDelete_Success() async throws {
        let movimiento = Movimiento.salida(
            fecha: Date(),
            cantidadCrypto: 50,
            precioUSD: 1000,
            usaFiatAlterno: false,
            cartera: mockCartera,
            crypto: mockCrypto
        )
        modelContext.insert(movimiento)

        viewModel = makeViewModel(movimiento: movimiento)

        try await viewModel.delete()

        XCTAssertFalse(viewModel.isLoading)

        let fetchRequest = FetchDescriptor<Movimiento>(predicate: #Predicate { $0.tipoRaw == "salida" })
        let movimientos = try modelContext.fetch(fetchRequest)

        XCTAssertEqual(movimientos.count, 0)
    }

    func testDeleteFailurePublishesAlertFeedback() async {
        let movimiento = Movimiento.salida(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 1000,
            usaFiatAlterno: false,
            cartera: mockCartera,
            crypto: mockCrypto
        )
        viewModel = MovimientoSalidaViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
            registerUseCase: registerUseCase,
            editUseCase: editUseCase,
            deleteUseCase: ThrowingDeleteMovementUseCaseStub()
        )

        do {
            try await viewModel.delete()
            XCTFail("Delete should throw")
        } catch {
            XCTAssertTrue(viewModel.hasError)
            XCTAssertEqual(viewModel.errorMessage, TestDeletionError.forced.localizedDescription)
            XCTAssertNotNil(viewModel.movimiento)
        }
    }

    // MARK: - Edge Cases

    func testEdgeCase_VerySmallQuantityIsValid() {
        let tinyAmount: Decimal = 0.000005
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        modelContext.insert(crypto)
        modelContext.insert(cartera)

        let entry = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: 0.00002,
            precioUSD: 50000,
            usaFiatAlterno: false,
            cartera: cartera,
            crypto: crypto
        )
        modelContext.insert(entry)
        try? modelContext.save()

        let viewModel = makeViewModel()
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = tinyAmount
        viewModel.precioUSD = 1000

        XCTAssertTrue(viewModel.formIsValid)
    }
}

struct ThrowingDeleteMovementUseCaseStub: DeleteMovementUseCaseProtocol {
    func delete(_ movement: Movimiento) async throws {
        throw TestDeletionError.forced
    }
}

enum TestDeletionError: LocalizedError {
    case forced

    var errorDescription: String? {
        "Forced deletion failure"
    }
}
