import XCTest
import SwiftData
@testable import Crypto_Tracker // Replace with your actual app module name

@MainActor
final class CryptoSyncViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: CryptoSyncViewModel!
    
    override func setUp() {
        super.setUp()
        
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try ModelContainer(for: Crypto.self, CryptoSyncConfig.self, configurations: config)
            modelContext = modelContainer.mainContext
            viewModel = CryptoSyncViewModel(modelContext: modelContext)
        } catch {
            XCTFail("Failed to set up model container: \(error)")
        }
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    func testInitialViewModelState() {
        XCTAssertFalse(viewModel.state.isSyncing, "Sync should not be active initially")
        XCTAssertTrue(viewModel.state.cryptos.isEmpty, "No cryptos should exist initially")
        XCTAssertTrue(viewModel.state.syncConfigs.isEmpty, "No sync configurations should exist initially")
        XCTAssertTrue(viewModel.state.logEntries.isEmpty, "No log entries should exist initially")
    }
    
    // MARK: - Crypto Creation and Validation Tests
    func testCryptoCreation() {
        let bitcoin = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        modelContext.insert(bitcoin)
        
        XCTAssertEqual(bitcoin.nombre, "Bitcoin", "Crypto name should be set correctly")
        XCTAssertEqual(bitcoin.simbolo, "BTC", "Crypto symbol should be set correctly")
        XCTAssertEqual(bitcoin.precio, 50000, "Crypto price should be set correctly")
        XCTAssertNotNil(bitcoin.ultimaActualizacion, "Update timestamp should be set")
    }
    
    func testCryptoNameLengthValidation() {
        let longName = String(repeating: "A", count: 30)
        let crypto = Crypto(nombre: longName, simbolo: "BTC", precio: 50000)
        
        XCTAssertEqual(crypto.nombre.count, 20, "Name should be truncated to 20 characters")
        XCTAssertTrue(crypto.nombre.hasPrefix("AAAAAAAAAAAAAAAAAAA"), "Name should be first 20 characters")
    }
    
    func testCryptoSymbolLengthValidation() {
        let longSymbol = String(repeating: "X", count: 15)
        let crypto = Crypto(nombre: "Test Crypto", simbolo: longSymbol, precio: 50000)
        
        XCTAssertEqual(crypto.simbolo.count, 10, "Symbol should be truncated to 10 characters")
        XCTAssertTrue(crypto.simbolo.hasPrefix("XXXXXXXXXX"), "Symbol should be first 10 characters")
    }
    
    // MARK: - Sync Configuration Tests
    func testSaveSyncConfiguration() {
        let crypto = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        modelContext.insert(crypto)
        
        viewModel.saveSyncConfig(for: crypto, url: "https://eth-price.com", defaultPrice: 2900)
        
        XCTAssertEqual(viewModel.state.syncConfigs.count, 1, "One sync config should be created")
        
        guard let savedConfig = viewModel.state.syncConfigs.first else {
            XCTFail("Sync configuration should exist")
            return
        }
        
        XCTAssertEqual(savedConfig.syncUrl, "https://eth-price.com", "Sync URL should match")
        XCTAssertEqual(savedConfig.defaultPrice, 2900, "Default price should match")
        XCTAssertEqual(savedConfig.crypto?.id, crypto.id, "Crypto should be correctly associated")
    }
    
    func testRetrieveSyncConfiguration() {
        let crypto = Crypto(nombre: "Ripple", simbolo: "XRP", precio: 1)
        modelContext.insert(crypto)
        
        viewModel.saveSyncConfig(for: crypto, url: "https://xrp-price.com", defaultPrice: 0.5)
        
        let retrievedConfig = viewModel.getSyncConfig(for: crypto.id)
        
        XCTAssertNotNil(retrievedConfig, "Sync configuration should be retrievable")
        XCTAssertEqual(retrievedConfig?.syncUrl, "https://xrp-price.com", "Retrieved URL should match")
        XCTAssertEqual(retrievedConfig?.defaultPrice, 0.5, "Retrieved default price should match")
    }
    
    // MARK: - Price History Tests
    func testCryptoPriceHistory() {
        let crypto = Crypto(nombre: "Litecoin", simbolo: "LTC", precio: 100)
        modelContext.insert(crypto)
        
        let initialPrice = crypto.precio
        crypto.precio = 150
        
        // Verify initial state of price history
        XCTAssertEqual(crypto.historicosPrecios.count, 0, "Price history should start empty")
        
        // Test price at date functionality
        let historicPrice = crypto.precioEnFecha(Date())
        XCTAssertNil(historicPrice, "No historic price should exist for today before manual recording")
    }
    
    func testCryptoPerformanceCalculation() {
        let crypto = Crypto(nombre: "Cardano", simbolo: "ADA", precio: 100)
        modelContext.insert(crypto)
        
        // TODO: You'll need to modify this based on your PrecioHistorico model
        // Simulate a historic price record
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // Check performance calculation
        let performance = crypto.rendimientoDesde(pastDate)
        
        // The specific assertion depends on your exact implementation
        XCTAssertNil(performance, "Performance should be nil without sufficient history")
    }
    
    // MARK: - Sync Process Tests
    func testSyncProcessInitiation() {
        let crypto = Crypto(nombre: "Solana", simbolo: "SOL", precio: 50)
        modelContext.insert(crypto)
        
        let config = CryptoSyncConfig(crypto: crypto, syncUrl: "https://test-sync-url.com", defaultPrice: 45)
        modelContext.insert(config)
        
        viewModel.loadData()
        viewModel.startSync()
        
        XCTAssertTrue(viewModel.state.isSyncing, "Sync process should be active")
    }
    
    // MARK: - Cleanup Tests
    func testViewModelCleanup() {
        let crypto = Crypto(nombre: "Polkadot", simbolo: "DOT", precio: 25)
        modelContext.insert(crypto)
        
        viewModel.saveSyncConfig(for: crypto, url: "https://test.com", defaultPrice: 22)
        viewModel.cleanup()
        
        XCTAssertTrue(viewModel.state.syncConfigs.isEmpty, "Sync configurations should be cleared")
    }
    
    // MARK: - Performance Tests
    func testSyncConfigCreationPerformance() {
        measure {
            let crypto = Crypto(nombre: "PerformanceCoin", simbolo: "PFC", precio: 10)
            modelContext.insert(crypto)
            viewModel.saveSyncConfig(for: crypto, url: "https://perf.com", defaultPrice: 9.5)
        }
    }
}

// Mock struct for price response
struct PriceResponse: Decodable {
    let price: Double
}

// Extension to help with string validation (mirroring model behavior)
extension String {
    func validated(maxLength: Int) -> String {
        return String(prefix(maxLength))
    }
}
