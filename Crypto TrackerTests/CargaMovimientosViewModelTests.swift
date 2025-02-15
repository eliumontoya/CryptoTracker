import XCTest
import SwiftData
import Combine
@testable import Crypto_Tracker

@MainActor
final class CargaMovimientosViewModelTests: XCTestCase {
    var viewModel: CargaMovimientosViewModel!
    var mockModelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        
        // Setup a mock model context for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Crypto.self,
            Cartera.self,
            FIAT.self,
            configurations: config
        )
        
        // Use Task to handle main actor context
        let expectation = XCTestExpectation(description: "Context Setup")
        Task { @MainActor in
            mockModelContext = container.mainContext
            viewModel = CargaMovimientosViewModel(modelContext: mockModelContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    override func tearDown() {
        Task { @MainActor in
            viewModel = nil
            mockModelContext = nil
        }
        super.tearDown()
    }
    
    // MARK: - Test Catalog Validation
    
    /// Verifies that hayCatalogosNecesarios returns false when catalogs are empty
    func testHayCatalogosNecesariosIsFalseWhenEmpty() {
        // Ensure no catalogs exist
        XCTAssertFalse(viewModel.hayCatalogosNecesarios,
                       "hayCatalogosNecesarios should be false when no catalogs are present")
    }
    
    /// Verifies that hayCatalogosNecesarios returns true when all catalogs have entries
    func testHayCatalogosNecesariosIsTrueWhenPopulated() {
        // Populate catalogs
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.00)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WALLET")
        let fiat = FIAT(nombre: "Dolar", simbolo: "USD", precioUSD: 1.00)
        
        mockModelContext.insert(crypto)
        mockModelContext.insert(cartera)
        mockModelContext.insert(fiat)
        
        // Attempt to save the context
        do {
            try mockModelContext.save()
        } catch {
            XCTFail("Failed to save mock context: \(error)")
        }
        
        // Reload view model catalogs
        XCTAssertTrue(viewModel.hayCatalogosNecesarios,
                      "hayCatalogosNecesarios should be true when all catalogs are populated")
    }
    
    // MARK: - Test File Selection Logic
    
    /// Verifies that hayArchivosSeleccionados correctly detects file selection
    func testHayArchivosSeleccionadosDetectsSelectedFiles() {
        // Initially no files
        XCTAssertFalse(viewModel.hayArchivosSeleccionados,
                       "hayArchivosSeleccionados should be false initially")
        
        // Select an entry movements file
        viewModel.movimientosEntradaURL = URL(fileURLWithPath: "/test/entrada.xlsx")
        XCTAssertTrue(viewModel.hayArchivosSeleccionados,
                      "hayArchivosSeleccionados should be true after selecting an entry file")
        
        // Reset
        viewModel.movimientosEntradaURL = nil
        
        // Select other file types
        viewModel.movimientosSalidaURL = URL(fileURLWithPath: "/test/salida.xlsx")
        XCTAssertTrue(viewModel.hayArchivosSeleccionados,
                      "hayArchivosSeleccionados should be true after selecting a sale file")
    }
    
    // MARK: - Test Logging and Error Handling
    
    /// Verifies that didUpdateProgress correctly adds log messages
    func testDidUpdateProgressAddsLogMessage() {
        let initialLogCount = viewModel.logs.count
        
        viewModel.didUpdateProgress("Test log message")
        
        XCTAssertEqual(viewModel.logs.count, initialLogCount + 1,
                       "Log should increase by one")
        XCTAssertTrue(viewModel.logs.last?.contains("Test log message") ?? false,
                      "Log message should match the input")
    }
    
    /// Verifies that didEncounterError properly handles and logs errors
    func testDidEncounterErrorHandling() {
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test Error"])
        
        viewModel.didEncounterError(testError)
        
        XCTAssertTrue(viewModel.showError, "showError should be true")
        XCTAssertEqual(viewModel.errorMessage, "Test Error", "Error message should match")
        XCTAssertTrue(viewModel.logs.last?.contains("ERROR") ?? false, "Error should be logged")
    }
    
    // MARK: - Test Task Completion
    
    /// Verifies that didCompleteTask correctly updates total loaded and loading state
    func testDidCompleteTaskUpdatesState() {
        viewModel.isLoading = true
        
        viewModel.didCompleteTask("Movimientos de Entrada", total: 5)
        
        XCTAssertEqual(viewModel.totalCargados["Movimientos de Entrada"], 5,
                       "Total loaded should match the input")
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after task completion")
    }
    
    // MARK: - Asynchronous Loading Tests
    
    /// Tests the cargarArchivos method with multiple file types
    func testCargarArchivosWithMultipleFileTypes() {
        // Prepare test by populating catalogs
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.00)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TESTWALLET")
        let fiat = FIAT(nombre: "Dolar", simbolo: "USD", precioUSD: 1.00)
        
        mockModelContext.insert(crypto)
        mockModelContext.insert(cartera)
        mockModelContext.insert(fiat)
        
        // Prepare expectation for async test
        let expectation = XCTestExpectation(description: "Archivos cargados")
        
        // Mock file URLs (these would typically be real Excel files in a real test)
        viewModel.movimientosEntradaURL = URL(fileURLWithPath: "/mock/entrada.xlsx")
        viewModel.movimientosSalidaURL = URL(fileURLWithPath: "/mock/salida.xlsx")
        
        // Observe changes
        var cancellables = Set<AnyCancellable>()
        viewModel.$totalCargados
            .sink { totalCargados in
                if totalCargados.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Call method to load files
        viewModel.cargarArchivos()
        
        // Wait for expectation
        wait(for: [expectation], timeout: 5.0)
        
        // Validate results
        XCTAssertEqual(viewModel.totalCargados.count, 2,
                       "Should have loaded two types of movements")
    }
    
    // MARK: - Edge Case Tests
    
    /// Verifies behavior when no files are selected
    func testCargarArchivosWithNoFiles() {
        // Reset all file URLs
        viewModel.movimientosEntradaURL = nil
        viewModel.movimientosSalidaURL = nil
        viewModel.movimientosEntreCarterasURL = nil
        viewModel.movimientosSwapURL = nil
        
        // Prepare expectation for async test
        let expectation = XCTestExpectation(description: "No files loaded")
        
        // Observe changes
        var cancellables = Set<AnyCancellable>()
        viewModel.$isLoading
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Call method to load files
        viewModel.cargarArchivos()
        
        // Wait for expectation
        wait(for: [expectation], timeout: 5.0)
        
        // Validate results
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after attempting to load with no files")
        XCTAssertTrue(viewModel.totalCargados.isEmpty, "No files should result in empty totalCargados")
    }
    
    // MARK: - Performance Tests
    
    /// Measures performance of file loading process
    func testCargarArchivosPerformance() {
        // Prepare test by populating catalogs
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.00)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TESTWALLET")
        let fiat = FIAT(nombre: "Dolar", simbolo: "USD", precioUSD: 1.00)
        
        mockModelContext.insert(crypto)
        mockModelContext.insert(cartera)
        mockModelContext.insert(fiat)
        
        // Prepare mock file URLs
        viewModel.movimientosEntradaURL = URL(fileURLWithPath: "/mock/entrada.xlsx")
        viewModel.movimientosSalidaURL = URL(fileURLWithPath: "/mock/salida.xlsx")
        viewModel.movimientosEntreCarterasURL = URL(fileURLWithPath: "/mock/entreCarteras.xlsx")
        viewModel.movimientosSwapURL = URL(fileURLWithPath: "/mock/swap.xlsx")
        
        // Measure performance
        measure {
            let expectation = XCTestExpectation(description: "Performance Test")
            
            viewModel.cargarArchivos()
            
            // Simple wait mechanism (in real scenarios, use more robust async testing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Boundary Condition Tests
    
    /// Verifies behavior when some but not all catalogs are populated
    func testHayCatalogosNecesariosWithPartialCatalogs() {
        // Populate only some catalogs
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.00)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WALLET")
        
        mockModelContext.insert(crypto)
        mockModelContext.insert(cartera)
        
        // Attempt to save the context
        do {
            try mockModelContext.save()
        } catch {
            XCTFail("Failed to save mock context: \(error)")
        }
        
        // Reload view model catalogs
        XCTAssertFalse(viewModel.hayCatalogosNecesarios,
                       "hayCatalogosNecesarios should be false when not all catalogs are populated")
    }
    
    // MARK: - Dependency Injection Test
    
    /// Demonstrates how to test with mock dependencies
    func testViewModelInitializationWithMockContext() {
        // Create a mock model context
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Crypto.self,
            configurations: config
        )
        
        // Use Task to handle main actor context
        let expectation = XCTestExpectation(description: "ViewModel Initialization")
        
        Task { @MainActor in
            let mockContext = container.mainContext
            
            // Initialize ViewModel with mock context
            let testViewModel = CargaMovimientosViewModel(modelContext: mockContext)
            
            // Verify initial state
            XCTAssertNotNil(testViewModel, "ViewModel should be initialized")
            XCTAssertFalse(testViewModel.hayCatalogosNecesarios, "Initial state should have no catalogs")
            XCTAssertFalse(testViewModel.isLoading, "Initial loading state should be false")
            XCTAssertTrue(testViewModel.logs.isEmpty, "Initial logs should be empty")
            XCTAssertTrue(testViewModel.totalCargados.isEmpty, "Initial totalCargados should be empty")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Mock Error for Testing
enum MockExcelWorksheetError: Error {
    case generic
    
    var localizedDescription: String {
        return "Mock Excel Worksheet Error"
    }
}
