import XCTest
import SwiftData
import Combine
@testable import Crypto_Tracker

@MainActor
final class MovimientoSalidaViewModelTests: XCTestCase {
    
    var modelContext: ModelContext!
    var viewModel: MovimientoSalidaViewModel!
    
    var mockCrypto: Crypto!
    var mockCartera: Cartera!
    var mockFiatAlterno: FIAT!
    
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        do {
            // Usar método de TestSetup para crear el contexto
            modelContext = TestSetup.createModelContext()
            
            // Crear mocks usando los métodos de extensión
            mockCrypto = Crypto.mock()
            mockCartera = Cartera.mock()
            mockFiatAlterno = FIAT.mock()
            
            
            // Intentar insertar con manejo de errores
            do {
                try modelContext.transaction {
                    modelContext.insert(mockCrypto)
                    modelContext.insert(mockCartera)
                    modelContext.insert(mockFiatAlterno)
                    try modelContext.save()
                }
            } catch {
                XCTFail("Error al insertar mocks: \(error)")
            }
            
            // Inicializar ViewModel
            viewModel = MovimientoSalidaViewModel(modelContext: modelContext)
        } catch {
            XCTFail("Error en la configuración inicial: \(error)")
        }
    }
    
    override func tearDown() {
        viewModel = nil
        modelContext = nil
        mockCrypto = nil
        mockCartera = nil
        mockFiatAlterno = nil
        cancellables.removeAll()
        
        super.tearDown()
    }
    
    // MARK: - Pruebas de Inicialización
    func testInitialization() {
        XCTAssertNotNil(viewModel)
        
        // Verificar que la fecha está cerca de la fecha actual
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
    
    // MARK: - Pruebas de Validación de Formulario
    func testInvalidValidationScenarios() {
        // Usar los escenarios de casos de prueba definidos
        MovimientoTestCases.invalidValidationScenarios.forEach { scenario in
            // Reiniciar el ViewModel para cada escenario
            viewModel = MovimientoSalidaViewModel(modelContext: modelContext)
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
        viewModel.cantidadCrypto = 150 // Supera el saldo disponible
        viewModel.precioUSD = 1000
        
        XCTAssertFalse(viewModel.formIsValid)
    }
    
    // MARK: - Pruebas de Cálculos
    func testOnCantidadCryptoChange() {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.precioUSD = 1000
        viewModel.cantidadCrypto = 150 // Supera el saldo disponible
        
        viewModel.onCantidadCryptoChange()
        
        XCTAssertEqual(viewModel.cantidadCrypto, 100) // Debe ajustarse al saldo disponible
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
    
    // MARK: - Pruebas de Guardado
    func testSave_Success() async throws {
        viewModel.selectedCrypto = mockCrypto
        viewModel.selectedCartera = mockCartera
        viewModel.cantidadCrypto = 50
        viewModel.precioUSD = 1000
        viewModel.valorTotalUSD = 50000
        
        do {
            try await viewModel.save()
            
            XCTAssertFalse(viewModel.isLoading)
            
            // Verificar que el movimiento se guardó correctamente
            let fetchRequest = FetchDescriptor<MovimientoEgreso>()
            let movimientos = try modelContext.fetch(fetchRequest)
            
            XCTAssertEqual(movimientos.count, 1)
            let movimiento = movimientos.first!
            
            XCTAssertEqual(movimiento.cantidadCrypto, 50)
            XCTAssertEqual(movimiento.precioUSD, 1000)
            XCTAssertEqual(movimiento.valorTotalUSD, 50000)
            XCTAssertFalse(movimiento.usaFiatAlterno)
            XCTAssertEqual(movimiento.cartera?.id, mockCartera.id)
            XCTAssertEqual(movimiento.crypto?.id, mockCrypto.id)
        } catch {
            XCTFail("Guardado falló inesperadamente: \(error)")
        }
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
        
        do {
            try await viewModel.save()
            
            XCTAssertFalse(viewModel.isLoading)
            
            // Verificar que el movimiento se guardó correctamente
            let fetchRequest = FetchDescriptor<MovimientoEgreso>()
            let movimientos = try modelContext.fetch(fetchRequest)
            
            XCTAssertEqual(movimientos.count, 1)
            let movimiento = movimientos.first!
            
            XCTAssertEqual(movimiento.cantidadCrypto, 50)
            XCTAssertEqual(movimiento.precioUSD, 1000)
            XCTAssertEqual(movimiento.valorTotalUSD, 50000)
            XCTAssertTrue(movimiento.usaFiatAlterno)
            XCTAssertEqual(movimiento.fiatAlterno?.id, mockFiatAlterno.id)
            XCTAssertEqual(movimiento.valorTotalFiatAlterno, 55000)
        } catch {
            XCTFail("Guardado falló inesperadamente: \(error)")
        }
    }
    
    // MARK: - Pruebas de Eliminación
    func testDelete_Success() async throws {
        // Primero crear un movimiento para eliminar
        let movimiento = MovimientoEgreso(
            fecha: Date(),
            cantidadCrypto: 50,
            precioUSD: 1000,
            usaFiatAlterno: false,
            cartera: mockCartera,
            crypto: mockCrypto
        )
        modelContext.insert(movimiento)
        
        // Inicializar ViewModel con el movimiento
        viewModel = MovimientoSalidaViewModel(modelContext: modelContext, movimiento: movimiento)
        
        do {
            try await viewModel.delete()
            
            XCTAssertFalse(viewModel.isLoading)
            
            // Verificar que el movimiento se eliminó
            let fetchRequest = FetchDescriptor<MovimientoEgreso>()
            let movimientos = try modelContext.fetch(fetchRequest)
            
            XCTAssertEqual(movimientos.count, 0)
        } catch {
            XCTFail("Eliminación falló inesperadamente: \(error)")
        }
    }
    
    // MARK: - Pruebas de Casos Límite
    func testEdgeCaseScenarios() {
        // Ejecutar escenarios de casos límite
        MovimientoTestCases.edgeCaseScenarios.forEach { scenario in
            scenario(modelContext)
        }
    }
}
