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
        mockCrypto = Crypto.mock()
        mockCarteraOrigen = Cartera.mock(nombre: "TEST_Cartera Origen")
        mockCarteraDestino = Cartera.mock(nombre: "TEST_Cartera Destino")
        
        // Agregar mocks al contexto
        do {
            try modelContext.transaction {
                modelContext.insert(mockCrypto)
                modelContext.insert(mockCarteraOrigen)
                modelContext.insert(mockCarteraDestino)
                try modelContext.save()
            }
        } catch {
            XCTFail("Error al insertar mocks: \(error)")
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
            
 
            // Verificar que el movimiento se guardó correctamente
            let fetchRequest = FetchDescriptor<MovimientoEntreCarteras>()
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
        // Primero crear un movimiento para eliminar
        let movimiento = MovimientoEntreCarteras(
            fecha: Date(),
            cantidadCryptoSalida: 50,
            cantidadCryptoEntrada: 50,
            carteraOrigen: mockCarteraOrigen,
            carteraDestino: mockCarteraDestino,
            crypto: mockCrypto
        )
        modelContext.insert(movimiento)
        
        // Inicializar ViewModel con el movimiento
        viewModel = MovimientoEntreCarterasViewModel(modelContext: modelContext, movimiento: movimiento)
        
        do {
            try await viewModel.delete()
            
 
            // Verificar que el movimiento se eliminó
            let fetchRequest = FetchDescriptor<MovimientoEntreCarteras>()
            let movimientos = try modelContext.fetch(fetchRequest)
            
            XCTAssertEqual(movimientos.count, 0)
        } catch {
            XCTFail("Eliminación falló inesperadamente: \(error)")
        }
    }
}
