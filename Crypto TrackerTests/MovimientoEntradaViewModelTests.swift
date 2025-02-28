import XCTest
@testable import Crypto_Tracker
import SwiftData

@MainActor
class MovimientoEntradaViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var mockContext: ModelContext!
    
    var viewModel: MovimientoEntradaViewModel!

    
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
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Tests de Validación
    func testFormValidationWithValidData() {
        // Given
        viewModel.selectedCrypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        viewModel.selectedCartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        
        // Then
        XCTAssertTrue(viewModel.formIsValid)
    }
    
    func testFormValidationWithInvalidData() {
        // Given
        viewModel.selectedCrypto = nil
        viewModel.selectedCartera = nil
        viewModel.cantidadCrypto = 0
        viewModel.precioUSD = 0
        
        // Then
        XCTAssertFalse(viewModel.formIsValid)
    }
    
    func testFormValidationWithFIATAlterno() {
        // Given
        viewModel.selectedCrypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        viewModel.selectedCartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        viewModel.valorTotalFiatAlterno = 45000
        
        // Then
        XCTAssertTrue(viewModel.formIsValid)
    }
    
    // MARK: - Tests de Cálculos
    func testCalculoPrecioUSD() {
        // Given
        viewModel.usaFiatAlterno = true
        viewModel.selectedFiatAlterno = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        viewModel.cantidadCrypto = 1.0
        viewModel.valorTotalFiatAlterno = 45000
        
        // When
        viewModel.calcularPrecioUSD()
        
        // Then
        let expectedUSD = Decimal(45000) / Decimal(1.1)
        XCTAssertEqual(viewModel.valorTotalUSD, expectedUSD, accuracy: 0.01)
    }
    
    func testCalculoValorTotalUSD() {
        // Given
        viewModel.cantidadCrypto = 2.0
        viewModel.precioUSD = 50000
        
        // When
        viewModel.onCantidadCryptoChange()
        
        // Then
        XCTAssertEqual(viewModel.valorTotalUSD, 100000)
    }
    
    // MARK: - Tests de Guardado
    func testGuardarMovimiento() {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST")
        viewModel.selectedCrypto = crypto
        viewModel.selectedCartera = cartera
        viewModel.cantidadCrypto = 1.0
        viewModel.precioUSD = 50000
        
        // When
        viewModel.save()
        
        // Then
        XCTAssertEqual(mockContext.insertCallCount, 1)
        XCTAssertTrue(mockContext.savedItems.contains { item in
            guard let movimiento = item as? MovimientoIngreso else { return false }
            return movimiento.cantidadCrypto == 1.0 &&
                   movimiento.precioUSD == 50000 &&
                   movimiento.crypto?.simbolo == "BTC" &&
                   movimiento.cartera?.nombre == "Test Wallet"
        })
    }
    
    func testGuardarMovimientoConFIATAlterno() {
        // Given
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
        
        // When
        viewModel.save()
        
        // Then
        XCTAssertEqual(mockContext.insertCallCount, 1)
        XCTAssertTrue(mockContext.savedItems.contains { item in
            guard let movimiento = item as? MovimientoIngreso else { return false }
            return movimiento.usaFiatAlterno &&
                   movimiento.fiatAlterno?.simbolo == "EUR" &&
                   movimiento.valorTotalFiatAlterno == 45000
        })
    }
}
