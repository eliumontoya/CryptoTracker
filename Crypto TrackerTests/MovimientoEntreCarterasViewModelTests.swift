import XCTest
import SwiftData
import Combine
@testable import Crypto_Tracker

@MainActor
final class MovimientoEntreCarterasViewModelTests: XCTestCase {
    var modelContext: ModelContext!
    var viewModel: MovimientoEntreCarterasViewModel!
    
    var mockCrypto: Crypto!
    var mockCarteraOrigen: Cartera!
    var mockCarteraDestino: Cartera!
    
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Usar método de TestSetup para crear el contexto
        modelContext = TestSetup.createModelContext()
        
        // Crear mocks usando los métodos de extensión
        let portfolio = Portfolio(nombre: "TEST_Portfolio", isDefault: true)
        mockCrypto = Crypto.mock()
        mockCarteraOrigen = Cartera.mock(nombre: "TEST_Cartera Origen")
        mockCarteraOrigen.portfolio = portfolio
        mockCarteraDestino = Cartera.mock(nombre: "TEST_Cartera Destino")
        mockCarteraDestino.portfolio = portfolio

        // Seed 100 units in the origin wallet so transfers can be created and the
        // available balance reflects a realistic value.
        let entrada = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: 100,
            precioUSD: 50_000,
            cartera: mockCarteraOrigen,
            crypto: mockCrypto
        )

        // Agregar mocks al contexto
        do {
            modelContext.insert(portfolio)
            modelContext.insert(mockCrypto)
            modelContext.insert(mockCarteraOrigen)
            modelContext.insert(mockCarteraDestino)
            modelContext.insert(entrada)
            try HoldingService().updateHoldingForMovement(entrada, in: modelContext)
            try modelContext.save()
        } catch {
            XCTFail("Error al insertar mocks: \(error)")
        }

        // Refetch wallets to ensure SwiftData inverse relationships are populated.
        do {
            let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
            if let origen = carteras.first(where: { $0.id == mockCarteraOrigen.id }) {
                mockCarteraOrigen = origen
            }
            if let destino = carteras.first(where: { $0.id == mockCarteraDestino.id }) {
                mockCarteraDestino = destino
            }
        } catch {
            XCTFail("Error al recuperar carteras: \(error)")
        }

        // Inicializar ViewModel
        viewModel = MovimientoEntreCarterasViewModel(modelContext: modelContext)
    }
    
    override func tearDown() {
        viewModel = nil
        modelContext = nil
        mockCrypto = nil
        mockCarteraOrigen = nil
        mockCarteraDestino = nil
        cancellables.removeAll()
        
        super.tearDown()
    }
    
    // MARK: - Pruebas de Inicialización
    func testInitialization() {
        XCTAssertNotNil(viewModel)
        
        // Verificar que la fecha está cerca de la fecha actual
        XCTAssertLessThan(abs(viewModel.fecha.timeIntervalSinceNow), 1)
        
        XCTAssertNil(viewModel.selectedCrypto)
        XCTAssertNil(viewModel.selectedCarteraOrigen)
        XCTAssertNil(viewModel.selectedCarteraDestino)
        XCTAssertEqual(viewModel.cantidadCryptoSalida, 0)
        XCTAssertEqual(viewModel.cantidadCryptoEntrada, 0)
     }
    
    // MARK: - Pruebas de Validación de Formulario
    func testFormValidation_InvalidWhenMissingData() {
        XCTAssertFalse(viewModel.formIsValid)
    }
    
    func testFormValidation_ValidWithCompleteData() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        viewModel.selectedCarteraDestino = mockCarteraDestino
        viewModel.cantidadCryptoSalida = 50
        viewModel.cantidadCryptoEntrada = 50
        
        XCTAssertTrue(viewModel.formIsValid)
    }
    
    func testFormValidation_InvalidWithSameCarteras() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        viewModel.selectedCarteraDestino = mockCarteraOrigen
        viewModel.cantidadCryptoSalida = 50
        viewModel.cantidadCryptoEntrada = 50
        
        XCTAssertFalse(viewModel.formIsValid)
    }
    
    func testFormValidation_InvalidWithExceedingAmount() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        viewModel.selectedCarteraDestino = mockCarteraDestino
        viewModel.cantidadCryptoSalida = 150 // Supera el saldo disponible
        viewModel.cantidadCryptoEntrada = 50
        
        XCTAssertFalse(viewModel.formIsValid)
    }
    
    // MARK: - Pruebas de Métodos de Ajuste
    

    func testSetMaxCantidadSalida() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen

        viewModel.setMaxCantidadSalida()

        XCTAssertEqual(viewModel.cantidadCryptoSalida, 100)
        XCTAssertEqual(viewModel.cantidadCryptoEntrada, 100)
    }

    func testSetMaxCantidadEntrada() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        viewModel.cantidadCryptoSalida = 75

        viewModel.setMaxCantidadEntrada()

        XCTAssertEqual(viewModel.cantidadCryptoEntrada, 75)
    }
    
    // MARK: - Pruebas de Propiedades Calculadas
    func testCryptoDisponible() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        
        XCTAssertEqual(viewModel.cryptoDisponible, 100)
    }
    
    func testComision() {
        viewModel.cantidadCryptoSalida = 100
        viewModel.cantidadCryptoEntrada = 90
        
        XCTAssertEqual(viewModel.comision, 10)
    }
    
    // MARK: - Pruebas de Guardado
    func testSave_Success() async throws {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCarteraOrigen = mockCarteraOrigen
        viewModel.selectedCarteraDestino = mockCarteraDestino
        viewModel.cantidadCryptoSalida = 50
        viewModel.cantidadCryptoEntrada = 50
        
        do {
            try await viewModel.save()
            
 
            // Verificar que los movimientos se guardaron correctamente (par con groupId)
            let fetchRequest = FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.tipoRaw == "transferenciaSalida" }
            )
            let movimientos = try modelContext.fetch(fetchRequest)
            
            XCTAssertEqual(movimientos.count, 1)
            let movimiento = movimientos.first!
            
            XCTAssertEqual(movimiento.cantidadCryptoSalida, 50)
            XCTAssertEqual(movimiento.cantidadCryptoEntrada, 50)
            XCTAssertEqual(movimiento.cantidadCryptoComision, 0) // No hay comisión en este caso
            XCTAssertEqual(movimiento.carteraOrigen?.id, mockCarteraOrigen.id)
            XCTAssertEqual(movimiento.carteraDestino?.id, mockCarteraDestino.id)
            XCTAssertEqual(movimiento.crypto?.id, mockCrypto.id)
        } catch {
            XCTFail("Guardado falló inesperadamente: \(error)")
        }
    }
    
     
    
    // MARK: - Pruebas de Eliminación
    func testDelete_Success() async throws {
        // Crear transferencia a través del use case para que los holdings se
        // materialicen correctamente antes de eliminar.
        let useCase = MoveBetweenWalletsUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        let par = try await useCase.execute(
            MoveBetweenWalletsInput(
                fecha: Date(),
                cantidadCryptoSalida: 50,
                cantidadCryptoEntrada: 50,
                precioUSD: mockCrypto.precio,
                carteraOrigen: mockCarteraOrigen,
                carteraDestino: mockCarteraDestino,
                crypto: mockCrypto
            )
        )

        // Inicializar ViewModel con el movimiento
        viewModel = MovimientoEntreCarterasViewModel(modelContext: modelContext, movimiento: par.salida)

        do {
            try await viewModel.delete()

            // Verificar que los movimientos de transferencia se eliminaron;
            // la entrada sembrada en setUp permanece.
            let fetchRequest = FetchDescriptor<Movimiento>()
            let movimientos = try modelContext.fetch(fetchRequest)

            XCTAssertEqual(movimientos.count, 1)
        } catch {
            XCTFail("Eliminación falló inesperadamente: \(error)")
        }
    }

}
