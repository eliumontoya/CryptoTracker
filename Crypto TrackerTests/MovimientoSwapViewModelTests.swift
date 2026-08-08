import XCTest
import SwiftData
import Combine
@testable import Crypto_Tracker

@MainActor
final class MovimientoSwapViewModelTests: XCTestCase {
    var modelContext: ModelContext!
    var viewModel: MovimientoSwapViewModel!
    var mockCryptoOrigen: Crypto!
    var mockCryptoDestino: Crypto!
    var mockCartera: Cartera!

    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        modelContext = TestSetup.createModelContext()

        let portfolio = Portfolio(nombre: "TEST_Portfolio", isDefault: true)
        mockCryptoOrigen = Crypto.mock(nombre: "TEST_Bitcoin", simbolo: "TEST_BTC", precio: 50_000)
        mockCryptoDestino = Crypto.mock(nombre: "TEST_Ethereum", simbolo: "TEST_ETH", precio: 3_000)
        mockCartera = Cartera.mock(nombre: "TEST_Cartera")
        mockCartera.portfolio = portfolio

        // Seed 100 BTC so swaps can be created and the available balance reflects
        // a realistic value.
        let entrada = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: 100,
            precioUSD: 50_000,
            cartera: mockCartera,
            crypto: mockCryptoOrigen
        )

        do {
            modelContext.insert(portfolio)
            modelContext.insert(mockCryptoOrigen)
            modelContext.insert(mockCryptoDestino)
            modelContext.insert(mockCartera)
            modelContext.insert(entrada)
            try HoldingService().updateHoldingForMovement(entrada, in: modelContext)
            try modelContext.save()
        } catch {
            XCTFail("Error al insertar mocks: \(error)")
        }

        // Refetch wallet to ensure SwiftData inverse relationships are populated.
        do {
            let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
            if let cartera = carteras.first(where: { $0.id == mockCartera.id }) {
                mockCartera = cartera
            }
        } catch {
            XCTFail("Error al recuperar carteras: \(error)")
        }

        viewModel = MovimientoSwapViewModel(modelContext: modelContext)
    }

    override func tearDown() {
        viewModel = nil
        modelContext = nil
        mockCryptoOrigen = nil
        mockCryptoDestino = nil
        mockCartera = nil
        cancellables.removeAll()

        super.tearDown()
    }

    // MARK: - Initialization
    func testInitialization() {
        XCTAssertNotNil(viewModel)

        XCTAssertLessThan(abs(viewModel.fecha.timeIntervalSinceNow), 1)
        XCTAssertNil(viewModel.selectedCryptoOrigen)
        XCTAssertNil(viewModel.selectedCryptoDestino)
        XCTAssertNil(viewModel.selectedCartera)
        XCTAssertEqual(viewModel.cantidadOrigen, 0)
        XCTAssertEqual(viewModel.cantidadDestino, 0)
        XCTAssertEqual(viewModel.precioUSDOrigen, 0)
        XCTAssertEqual(viewModel.precioUSDDestino, 0)
    }

    // MARK: - Form validation
    func testFormValidation_InvalidWhenMissingData() {
        XCTAssertFalse(viewModel.formIsValid)
    }

    func testFormValidation_ValidWithCompleteData() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCryptoDestino = mockCryptoDestino
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadOrigen = 50
        viewModel.cantidadDestino = 500
        viewModel.precioUSDOrigen = 50_000
        viewModel.precioUSDDestino = 3_000

        XCTAssertTrue(viewModel.formIsValid)
    }

    func testFormValidation_InvalidWithSameCrypto() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCryptoDestino = mockCryptoOrigen
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadOrigen = 50
        viewModel.cantidadDestino = 500
        viewModel.precioUSDOrigen = 50_000
        viewModel.precioUSDDestino = 3_000

        XCTAssertFalse(viewModel.formIsValid)
    }

    func testFormValidation_InvalidWithExceedingAmount() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCryptoDestino = mockCryptoDestino
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadOrigen = 150 // Exceeds available balance
        viewModel.cantidadDestino = 500
        viewModel.precioUSDOrigen = 50_000
        viewModel.precioUSDDestino = 3_000

        XCTAssertFalse(viewModel.formIsValid)
    }

    // MARK: - Adjustments
    func testAdjustCantidadOrigen() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadOrigen = 150

        viewModel.adjustCantidadOrigen()

        XCTAssertEqual(viewModel.cantidadOrigen, 100)
    }

    func testSetMaxCantidadOrigen() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCartera = mockCartera

        viewModel.setMaxCantidadOrigen()

        XCTAssertEqual(viewModel.cantidadOrigen, 100)
    }

    // MARK: - Computed properties
    func testCryptoDisponible() {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCartera = mockCartera

        XCTAssertEqual(viewModel.cryptoDisponible, 100)
    }

    func testValorTotalOrigen() {
        viewModel.cantidadOrigen = 2
        viewModel.precioUSDOrigen = 50_000

        XCTAssertEqual(viewModel.valorTotalOrigen, 100_000)
    }

    func testValorTotalDestino() {
        viewModel.cantidadDestino = 10
        viewModel.precioUSDDestino = 3_000

        XCTAssertEqual(viewModel.valorTotalDestino, 30_000)
    }

    // MARK: - Saving
    func testSave_Success() async throws {
        viewModel.selectedCryptoOrigen = mockCryptoOrigen
        viewModel.selectedCryptoDestino = mockCryptoDestino
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadOrigen = 50
        viewModel.cantidadDestino = 500
        viewModel.precioUSDOrigen = 50_000
        viewModel.precioUSDDestino = 3_000

        do {
            try await viewModel.save()

            let fetchRequest = FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.tipoRaw == "swapSalida" }
            )
            let movimientos = try modelContext.fetch(fetchRequest)

            XCTAssertEqual(movimientos.count, 1)
            let movimiento = movimientos.first!

            XCTAssertEqual(movimiento.cantidadOrigen, 50)
            XCTAssertEqual(movimiento.cantidadDestino, 500)
            XCTAssertEqual(movimiento.precioUSDOrigen, 50_000)
            XCTAssertEqual(movimiento.precioUSDDestino, 3_000)
            XCTAssertEqual(movimiento.cartera?.id, mockCartera.id)
            XCTAssertEqual(movimiento.cryptoOrigen?.id, mockCryptoOrigen.id)
            XCTAssertEqual(movimiento.cryptoDestino?.id, mockCryptoDestino.id)
        } catch {
            XCTFail("Guardado falló inesperadamente: \(error)")
        }
    }

    // MARK: - Deletion
    func testDelete_Success() async throws {
        let useCase = SwapMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        let par = try await useCase.execute(
            SwapMovementInput(
                fecha: Date(),
                cantidadOrigen: 50,
                cantidadDestino: 500,
                precioUSDOrigen: mockCryptoOrigen.precio,
                precioUSDDestino: mockCryptoDestino.precio,
                cartera: mockCartera,
                cryptoOrigen: mockCryptoOrigen,
                cryptoDestino: mockCryptoDestino
            )
        )

        viewModel = MovimientoSwapViewModel(modelContext: modelContext, movimiento: par.salida)

        do {
            try await viewModel.delete()

            let fetchRequest = FetchDescriptor<Movimiento>()
            let movimientos = try modelContext.fetch(fetchRequest)

            // Seeded entrada remains.
            XCTAssertEqual(movimientos.count, 1)
        } catch {
            XCTFail("Eliminación falló inesperadamente: \(error)")
        }
    }

    func testDeleteFailurePublishesAlertFeedback() async {
        let movimiento = Movimiento.swap(
            fecha: Date(),
            cantidadOrigen: 1,
            cantidadDestino: 10,
            precioUSDOrigen: mockCryptoOrigen.precio,
            precioUSDDestino: mockCryptoDestino.precio,
            cartera: mockCartera,
            cryptoOrigen: mockCryptoOrigen,
            cryptoDestino: mockCryptoDestino
        ).salida
        viewModel = MovimientoSwapViewModel(
            modelContext: modelContext,
            movimiento: movimiento,
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

    // MARK: - Editing
    func testEdit_Success() async throws {
        let useCase = SwapMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        let par = try await useCase.execute(
            SwapMovementInput(
                fecha: Date(),
                cantidadOrigen: 50,
                cantidadDestino: 500,
                precioUSDOrigen: mockCryptoOrigen.precio,
                precioUSDDestino: mockCryptoDestino.precio,
                cartera: mockCartera,
                cryptoOrigen: mockCryptoOrigen,
                cryptoDestino: mockCryptoDestino
            )
        )

        viewModel = MovimientoSwapViewModel(modelContext: modelContext, movimiento: par.salida)
        viewModel.cantidadOrigen = 25
        viewModel.cantidadDestino = 250
        viewModel.precioUSDOrigen = 55_000
        viewModel.precioUSDDestino = 3_200

        do {
            try await viewModel.save()

            let fetchRequest = FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.tipoRaw == "swapSalida" }
            )
            let movimientos = try modelContext.fetch(fetchRequest)
            XCTAssertEqual(movimientos.count, 1)
            let movimiento = movimientos.first!

            XCTAssertEqual(movimiento.cantidadOrigen, 25)
            XCTAssertEqual(movimiento.cantidadDestino, 250)
            XCTAssertEqual(movimiento.precioUSDOrigen, 55_000)
            XCTAssertEqual(movimiento.precioUSDDestino, 3_200)
        } catch {
            XCTFail("Edición falló inesperadamente: \(error)")
        }
    }
}
