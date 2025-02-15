/*import XCTest
import SwiftData
@testable import Crypto_Tracker

// MARK: - Test Suite para Servicios de Carga de Movimientos
final class CargaMovimientosTests: XCTestCase {
    var modelContext: ModelContext!
    var mockDelegate: MockCargaMovimientosDelegate!
    
    override func setUp() async throws {
        try await super.setUp()
        // Configurar el contexto de prueba y el delegado mock antes de cada test
        await MainActor.run {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: Schema([
                FIAT.self,
                Crypto.self,
                Cartera.self,
                MovimientoIngreso.self,
                MovimientoEgreso.self,
                MovimientoEntreCarteras.self,
                MovimientoSwap.self
            ]), configurations: [config])
            modelContext = ModelContext(container)
        }
        mockDelegate = MockCargaMovimientosDelegate()
    }
    
    override func tearDown() async throws {
        // Limpiar después de cada test
        await MainActor.run {
            modelContext = ModelContext(PreviewContainer.shared.container)
        }
        mockDelegate = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests para CargaMovimientosEntradaService
    
    /// Test que verifica la carga exitosa de movimientos de entrada desde un archivo Excel
    /// - Valida que:
    ///   - Los movimientos se cargan correctamente
    ///   - El total de movimientos cargados es correcto
    ///   - Los datos de cada movimiento son válidos
    ///   - El delegado recibe las actualizaciones de progreso
    func testCargaMovimientosEntradaExitosa() async throws {
        // Arrange
        let entradaService: CargaMovimientosEntradaService = CargaMovimientosEntradaService(modelContext: modelContext, delegate: mockDelegate)
        let testData = crearDatosPrueba()
        let url = crearArchivoExcelTemporal(conDatos: testData)
        
        // Act
        let totalCargados = try await entradaService.cargarMovimientos(
            desde: url,
            cryptos: testData.cryptos,
            carteras: testData.carteras,
            fiats: testData.fiats
        )
        
        // Assert
        XCTAssertEqual(totalCargados, testData.movimientosEsperados)
        XCTAssertTrue(mockDelegate.didReceiveProgressUpdates)
        XCTAssertEqual(mockDelegate.completedTasks["Movimientos de Entrada"], testData.movimientosEsperados)
        
        // Verificar que los movimientos se guardaron correctamente
        let descriptor = FetchDescriptor<MovimientoIngreso>()
        let movimientosCargados = try modelContext.fetch(descriptor)
        XCTAssertEqual(movimientosCargados.count, testData.movimientosEsperados)
        // Aquí podrías agregar más validaciones específicas sobre los datos
    }
    
    /// Test que verifica el manejo de errores al cargar movimientos de entrada con datos inválidos
    /// - Valida que:
    ///   - Se manejan correctamente los errores de formato
    ///   - No se guardan movimientos parciales en caso de error
    ///   - El delegado recibe la notificación de error
    func testCargaMovimientosEntradaConDatosInvalidos() async {
        // Arrange
        let entradaService: CargaMovimientosEntradaService = CargaMovimientosEntradaService(modelContext: modelContext, delegate: mockDelegate)
        let datosInvalidos = crearDatosInvalidos()
        let url = crearArchivoExcelTemporal(conDatos: datosInvalidos)
        
        // Act & Assert
        do {
            _ = try await entradaService.cargarMovimientos(
                desde: url,
                cryptos: [],
                carteras: [],
                fiats: []
            )
            XCTFail("Se esperaba un error por datos inválidos")
        } catch {
            // Verificar que no se guardaron movimientos
            let descriptor = FetchDescriptor<MovimientoIngreso>()
            let movimientosCargados = try? modelContext.fetch(descriptor)
            XCTAssertEqual(movimientosCargados?.count ?? 0, 0)
            XCTAssertTrue(mockDelegate.didReceiveError)
        }
    }
    
    // MARK: - Tests para CargaMovimientosSalidaService
    
    /// Test que verifica la carga exitosa de movimientos de salida
    /// - Valida que:
    ///   - Los movimientos de salida se cargan correctamente
    ///   - Las cantidades y balances son consistentes
    ///   - Se actualizan los balances de las carteras
    func testCargaMovimientosSalidaExitosa() async throws {
        // Arrange
        let salidaService: CargaMovimientosSalidaService = CargaMovimientosSalidaService(modelContext: modelContext, delegate: mockDelegate)
        let testData = crearDatosPrueba()
        let url = crearArchivoExcelTemporal(conDatos: testData)
        
        // Act
        let totalCargados = try await salidaService.cargarMovimientos(
            desde: url,
            cryptos: testData.cryptos,
            carteras: testData.carteras,
            fiats: testData.fiats
        )
        
        // Assert
        XCTAssertEqual(totalCargados, testData.movimientosEsperados)
        XCTAssertTrue(mockDelegate.didReceiveProgressUpdates)
        // Verificar balances de carteras
        for cartera in testData.carteras {
            XCTAssertTrue(verificarBalanceCartera(cartera))
        }
    }
    
    // MARK: - Tests para CargaMovimientosEntreCarterasService
    
    /// Test que verifica la carga exitosa de movimientos entre carteras
    /// - Valida que:
    ///   - Las transferencias se registran correctamente
    ///   - Los balances de ambas carteras son consistentes
    ///   - Se calculan correctamente las comisiones
    func testCargaMovimientosEntreCarterasExitosa() async throws {
        // Arrange
        let entreCarterasService: CargaMovimientosEntreCarterasService = CargaMovimientosEntreCarterasService(modelContext: modelContext, delegate: mockDelegate)
        let testData = crearDatosPrueba()
        let url = crearArchivoExcelTemporal(conDatos: testData)
        
        // Act
        let totalCargados = try await entreCarterasService.cargarMovimientos(
            desde: url,
            cryptos: testData.cryptos,
            carteras: testData.carteras
        )
        
        // Assert
        XCTAssertEqual(totalCargados, testData.movimientosEsperados)
        // Verificar consistencia de balances entre carteras
        let movimientos = try modelContext.fetch(FetchDescriptor<MovimientoEntreCarteras>())
        for movimiento in movimientos {
            XCTAssertTrue(verificarConsistenciaTransferencia(movimiento))
        }
    }
    
    // MARK: - Tests para CargaMovimientosSwapService
    
    /// Test que verifica la carga exitosa de movimientos swap
    /// - Valida que:
    ///   - Los swaps se registran correctamente
    ///   - Los precios y cantidades son consistentes
    ///   - Se actualizan correctamente los balances de cryptos
    func testCargaMovimientosSwapExitosa() async throws {
        // Arrange
        let swapService: CargaMovimientosSwapService = CargaMovimientosSwapService(modelContext: modelContext, delegate: mockDelegate)
        let testData = crearDatosPrueba()
        let url = crearArchivoExcelTemporal(conDatos: testData)
        
        // Act
        let totalCargados = try await swapService.cargarMovimientos(
            desde: url,
            cryptos: testData.cryptos,
            carteras: testData.carteras
        )
        
        // Assert
        XCTAssertEqual(totalCargados, testData.movimientosEsperados)
        // Verificar consistencia de los swaps
        let movimientos = try modelContext.fetch(FetchDescriptor<MovimientoSwap>())
        for movimiento in movimientos {
            XCTAssertTrue(verificarConsistenciaSwap(movimiento))
        }
    }
    
    // MARK: - Helper Methods
    
    private func crearDatosPrueba() -> TestData {
        // Implementar creación de datos de prueba
        TestData(
            cryptos: [],
            carteras: [],
            fiats: [],
            movimientosEsperados: 0
        )
    }
    
    private func crearDatosInvalidos() -> TestData {
        // Implementar creación de datos inválidos para pruebas
        TestData(
            cryptos: [],
            carteras: [],
            fiats: [],
            movimientosEsperados: 0
        )
    }
    
    private func crearArchivoExcelTemporal(conDatos data: TestData) -> URL {
        // Implementar creación de archivo Excel temporal
        URL(fileURLWithPath: "")
    }
    
    private func verificarBalanceCartera(_ cartera: Cartera) -> Bool {
        // Implementar verificación de balance de cartera
        true
    }
    
    private func verificarConsistenciaTransferencia(_ movimiento: MovimientoEntreCarteras) -> Bool {
        // Implementar verificación de consistencia de transferencia
        true
    }
    
    private func verificarConsistenciaSwap(_ movimiento: MovimientoSwap) -> Bool {
        // Implementar verificación de consistencia de swap
        true
    }
}

// MARK: - Estructuras Auxiliares

struct TestData {
    let cryptos: [Crypto]
    let carteras: [Cartera]
    let fiats: [FIAT]
    let movimientosEsperados: Int
}

// MARK: - Mock del Delegado

class MockCargaMovimientosDelegate: CargaMovimientosDelegate {
    var didReceiveProgressUpdates = false
    var didReceiveError = false
    var completedTasks: [String: Int] = [:]
    
    func didUpdateProgress(_ message: String) {
        didReceiveProgressUpdates = true
    }
    
    func didCompleteTask(_ task: String, total: Int) {
        completedTasks[task] = total
    }
    
    func didReceiveErrorMessage(_ error: Error) {
        didReceiveError = true
    }
}

// MARK: - Protocolo del Delegado

protocol CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String)
    func didCompleteTask(_ task: String, total: Int)
    func didReceiveErrorMessage(_ error: Error)
}
*/
