import XCTest
@testable import Crypto_Tracker
import SwiftData

/*

class MockMovimientosEntradaService : MovimientosEntradaServiceProtocol{
    func save(movimiento: Crypto_Tracker.MovimientoIngreso) throws {
        <#code#>
    }
    
    func insert(movimiento: Crypto_Tracker.MovimientoIngreso) throws {
        <#code#>
    }
    
    func delete(movimiento: Crypto_Tracker.MovimientoIngreso) throws {
        
    }
    
}

// MARK: - Test Data Helpers
extension MovimientoEntradaTests {
    func createTestCrypto() -> Crypto {
        return Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
    }
    
    func createTestCartera() -> Cartera {
        return Cartera(nombre: "Test Wallet", simbolo: "TEST")
    }
    
    func createTestFIAT() -> FIAT {
        return FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
    }
    
    func createTestMovimiento() -> MovimientoIngreso {
        let crypto = createTestCrypto()
        let cartera = createTestCartera()
        return MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: 1.0,
            precioUSD: 50000,
            cartera: cartera,
            crypto: crypto
        )
    }
}

@MainActor
class MovimientoEntradaTests: XCTestCase {
    var modelContainer: ModelContainer!
    var mockContext: ModelContext!
    
    var sut: MovimientoEntradaViewModel!

    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([MovimientoIngreso.self])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        mockContext = ModelContext(modelContainer)
        
        viewModel = MovimientoEntradaViewModel(modelContext: mockContext)
    }
    
    override func tearDown() {
        mockContext = nil
        sut = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    func testMovimientoEntradaCreation() {
        // Given
        let crypto = createTestCrypto()
        let cartera = createTestCartera()
        let cantidad: Decimal = 1.0
        let precioUSD: Decimal = 50000
        
        // When
        let movimiento = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: cantidad,
            precioUSD: precioUSD,
            cartera: cartera,
            crypto: crypto
        )
        
        // Then
        XCTAssertEqual(movimiento.cantidadCrypto, cantidad)
        XCTAssertEqual(movimiento.precioUSD, precioUSD)
        XCTAssertEqual(movimiento.valorTotalUSD, cantidad * precioUSD)
        XCTAssertEqual(movimiento.crypto?.simbolo, "BTC")
        XCTAssertEqual(movimiento.cartera?.nombre, "Test Wallet")
    }
    
    func testMovimientoEntradaConFIATAlterno() {
        // Given
        let crypto = createTestCrypto()
        let cartera = createTestCartera()
        let fiat = createTestFIAT()
        let cantidad: Decimal = 1.0
        let precioUSD: Decimal = 50000
        let valorFIAT: Decimal = 45000
        
        // When
        let movimiento = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: cantidad,
            precioUSD: precioUSD,
            usaFiatAlterno: true,
            precioFiatAlterno: valorFIAT / cantidad,
            valorTotalFiatAlterno: valorFIAT,
            cartera: cartera,
            crypto: crypto,
            fiatAlterno: fiat
        )
        
        // Then
        XCTAssertTrue(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.valorTotalFiatAlterno, valorFIAT)
        XCTAssertEqual(movimiento.fiatAlterno?.simbolo, "EUR")
    }
    
    func testDeleteMovimiento() {
        // Given
        let movimiento = createTestMovimiento()
        
        // When
        mockContext.delete(movimiento)
        
        // Then
        XCTAssertEqual(mockContext.deleteCallCount, 1)
        XCTAssertTrue(mockContext.deletedItems.contains { $0 is MovimientoIngreso })
    }
    
    func testViewModelInitialization() {
        // Given
        let movimiento = createTestMovimiento()
        
        // When
        let viewModel = MovimientoEntradaViewModel(
            modelContext: mockContext,
            movimiento: movimiento
        )
        
        // Then
        XCTAssertEqual(viewModel.selectedCrypto?.simbolo, "BTC")
        XCTAssertEqual(viewModel.selectedCartera?.nombre, "Test Wallet")
        XCTAssertEqual(viewModel.cantidadCrypto, 1.0)
        XCTAssertEqual(viewModel.precioUSD, 50000)
    }
}
*/
