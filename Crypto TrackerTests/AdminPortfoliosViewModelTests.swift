import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class AdminPortfoliosViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AdminPortfoliosViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([Portfolio.self, Cartera.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        viewModel = AdminPortfoliosViewModel(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.portfolios.isEmpty)
        XCTAssertNil(viewModel.formState)
        XCTAssertFalse(viewModel.showingDeleteAlert)
        XCTAssertNil(viewModel.selectedPortfolio)
    }
    
    // MARK: - CRUD Tests
    
    func testAddPortfolio() {
        viewModel.addPortfolio(nombre: "Test Portfolio", descripcion: "Description", isDefault: false)
        
        XCTAssertEqual(viewModel.portfolios.count, 1)
        XCTAssertEqual(viewModel.portfolios.first?.nombre, "Test Portfolio")
        XCTAssertEqual(viewModel.portfolios.first?.descripcion, "Description")
        XCTAssertFalse(viewModel.portfolios.first?.isDefault ?? true)
    }
    
    func testAddMultiplePortfoliosSorted() {
        viewModel.addPortfolio(nombre: "Zeta", descripcion: "", isDefault: false)
        viewModel.addPortfolio(nombre: "Alpha", descripcion: "", isDefault: false)
        viewModel.addPortfolio(nombre: "Beta", descripcion: "", isDefault: false)
        
        XCTAssertEqual(viewModel.portfolios.count, 3)
        XCTAssertEqual(viewModel.portfolios[0].nombre, "Alpha")
        XCTAssertEqual(viewModel.portfolios[1].nombre, "Beta")
        XCTAssertEqual(viewModel.portfolios[2].nombre, "Zeta")
    }
    
    func testUpdatePortfolio() {
        viewModel.addPortfolio(nombre: "Old Name", descripcion: "Old", isDefault: false)
        let portfolio = viewModel.portfolios.first!
        
        viewModel.updatePortfolio(portfolio, nombre: "New Name", descripcion: "New", isDefault: true)
        
        XCTAssertEqual(viewModel.portfolios.first?.nombre, "New Name")
        XCTAssertEqual(viewModel.portfolios.first?.descripcion, "New")
        XCTAssertTrue(viewModel.portfolios.first?.isDefault ?? false)
    }
    
    func testDeletePortfolio() {
        viewModel.addPortfolio(nombre: "To Delete", descripcion: "", isDefault: false)
        let portfolio = viewModel.portfolios.first!
        
        viewModel.deletePortfolio(portfolio)
        
        XCTAssertTrue(viewModel.portfolios.isEmpty)
    }
    
    // MARK: - Default Flag Tests
    
    func testDefaultFlagIsUniqueOnAdd() {
        viewModel.addPortfolio(nombre: "First", descripcion: "", isDefault: true)
        viewModel.addPortfolio(nombre: "Second", descripcion: "", isDefault: true)
        
        let defaults = viewModel.portfolios.filter { $0.isDefault }
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.nombre, "Second")
    }
    
    func testDefaultFlagIsUniqueOnUpdate() {
        viewModel.addPortfolio(nombre: "First", descripcion: "", isDefault: true)
        viewModel.addPortfolio(nombre: "Second", descripcion: "", isDefault: false)
        let second = viewModel.portfolios.first { $0.nombre == "Second" }!
        
        viewModel.updatePortfolio(second, nombre: "Second", descripcion: "", isDefault: true)
        
        let defaults = viewModel.portfolios.filter { $0.isDefault }
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.nombre, "Second")
    }
    
    // MARK: - Validation Tests
    
    func testCanDeleteEmptyPortfolio() {
        viewModel.addPortfolio(nombre: "Empty", descripcion: "", isDefault: false)
        let portfolio = viewModel.portfolios.first!
        
        XCTAssertTrue(viewModel.canDeletePortfolio(portfolio))
    }
    
    func testCannotDeletePortfolioWithWallets() {
        viewModel.addPortfolio(nombre: "With Wallets", descripcion: "", isDefault: false)
        let portfolio = viewModel.portfolios.first!
        let cartera = Cartera(nombre: "Wallet", simbolo: "WAL", portfolio: portfolio)
        modelContext.insert(cartera)
        try? modelContext.save()
        
        XCTAssertFalse(viewModel.canDeletePortfolio(portfolio))
    }
    
    // MARK: - Form State Tests
    
    func testShowAddForm() {
        viewModel.showAddForm()
        
        if case .add = viewModel.formState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Form state should be .add")
        }
    }
    
    func testShowEditForm() {
        viewModel.addPortfolio(nombre: "To Edit", descripcion: "", isDefault: false)
        let portfolio = viewModel.portfolios.first!
        
        viewModel.showEditForm(for: portfolio)
        
        if case .edit(let editedPortfolio) = viewModel.formState {
            XCTAssertEqual(editedPortfolio.id, portfolio.id)
        } else {
            XCTFail("Form state should be .edit")
        }
    }
    
    func testCloseForm() {
        viewModel.showAddForm()
        XCTAssertNotNil(viewModel.formState)
        
        viewModel.closeForm()
        
        XCTAssertNil(viewModel.formState)
    }
}
