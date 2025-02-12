import XCTest
import SwiftData
@testable import Crypto_Tracker

final class AdminCarterasViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AdminCarterasViewModel!
    
    override func setUpWithError() throws {
        // Configurar el contenedor de prueba en memoria
        let schema = Schema([Cartera.self, Crypto.self, FIAT.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        viewModel = AdminCarterasViewModel(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        // Limpiar el contexto y referencias después de cada prueba
        modelContext = nil
        modelContainer = nil
        viewModel = nil
    }
    
    // MARK: - Pruebas de Creación
    
    func testAddCartera() throws {
        // Prueba la creación de una nueva cartera y verifica que se agregue correctamente a la lista
        viewModel.addCartera(nombre: "Test Wallet", simbolo: "TEST")
        
        XCTAssertEqual(viewModel.carteras.count, 1)
        XCTAssertEqual(viewModel.carteras.first?.nombre, "Test Wallet")
        XCTAssertEqual(viewModel.carteras.first?.simbolo, "TEST")
    }
    
    func testAddMultipleCarteras() throws {
        // Prueba la creación de múltiples carteras y verifica el orden alfabético
        viewModel.addCartera(nombre: "Binance", simbolo: "BNB")
        viewModel.addCartera(nombre: "Atomic", simbolo: "ATC")
        viewModel.addCartera(nombre: "Coinbase", simbolo: "CB")
        
        XCTAssertEqual(viewModel.carteras.count, 3)
        XCTAssertEqual(viewModel.carteras[0].nombre, "Atomic") // Verifica orden alfabético
        XCTAssertEqual(viewModel.carteras[1].nombre, "Binance")
        XCTAssertEqual(viewModel.carteras[2].nombre, "Coinbase")
    }
    
    // MARK: - Pruebas de Actualización
    
    func testUpdateCartera() throws {
        // Prueba la actualización de una cartera existente
        viewModel.addCartera(nombre: "Old Name", simbolo: "OLD")
        let cartera = viewModel.carteras.first!
        
        viewModel.updateCartera(cartera, nombre: "New Name", simbolo: "NEW")
        
        XCTAssertEqual(viewModel.carteras.first?.nombre, "New Name")
        XCTAssertEqual(viewModel.carteras.first?.simbolo, "NEW")
    }
    
    // MARK: - Pruebas de Eliminación
    
    func testDeleteCartera() throws {
        // Prueba la eliminación de una cartera
        viewModel.addCartera(nombre: "To Delete", simbolo: "DEL")
        let cartera = viewModel.carteras.first!
        
        viewModel.deleteCartera(cartera)
        
        XCTAssertTrue(viewModel.carteras.isEmpty)
    }
    
    // MARK: - Pruebas de Validación
    
    func testCanDeleteCarteraEmpty() throws {
        // Prueba que una cartera sin movimientos puede ser eliminada
        viewModel.addCartera(nombre: "Empty Wallet", simbolo: "EMP")
        let cartera = viewModel.carteras.first!
        
        XCTAssertTrue(viewModel.canDeleteCartera(cartera))
    }
    
    func testCanDeleteCarteraWithMovimientos() throws {
        // Prueba que una cartera con movimientos no puede ser eliminada
        viewModel.addCartera(nombre: "Used Wallet", simbolo: "USD")
        let cartera = viewModel.carteras.first!
        
        // Agregar un movimiento de ingreso
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let movimiento = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50000,
            cartera: cartera,
            crypto: crypto
        )
        modelContext.insert(movimiento)
        
        XCTAssertFalse(viewModel.canDeleteCartera(cartera))
    }
    
    // MARK: - Pruebas de Cache
    
    func testCalculosCacheRetention() throws {
        // Prueba que los cálculos se mantienen en cache y son reutilizados
        viewModel.addCartera(nombre: "Cache Test", simbolo: "CCH")
        let cartera = viewModel.carteras.first!
        
        let primerCalculo = viewModel.getCalculosCartera(cartera)
        let segundoCalculo = viewModel.getCalculosCartera(cartera)
        
        // Verificar que ambos cálculos son idénticos (usando cache)
        XCTAssertEqual(primerCalculo.valorTotal, segundoCalculo.valorTotal)
        XCTAssertEqual(primerCalculo.resumen, segundoCalculo.resumen)
    }
    
    func testCacheClearOnUpdate() throws {
        // Prueba que el cache se limpia al actualizar una cartera
        viewModel.addCartera(nombre: "Cache Clear Test", simbolo: "CLR")
        let cartera = viewModel.carteras.first!
        
        let _ = viewModel.getCalculosCartera(cartera) // Llenar cache
        viewModel.updateCartera(cartera, nombre: "Updated Name", simbolo: "UPD")
        
        // Verificar que se realizan nuevos cálculos después de actualizar
        let nuevosCalculos = viewModel.getCalculosCartera(cartera)
        XCTAssertEqual(nuevosCalculos.resumen, "")
        XCTAssertEqual(nuevosCalculos.valorTotal, 0)
    }
    
    // MARK: - Pruebas de Estado del Formulario
    
    func testFormStateAdd() throws {
        // Prueba el estado del formulario para agregar
        viewModel.showAddForm()
        
        if case .add = viewModel.formState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Estado del formulario debería ser .add")
        }
    }
    
    func testFormStateEdit() throws {
        // Prueba el estado del formulario para editar
        viewModel.addCartera(nombre: "To Edit", simbolo: "EDT")
        let cartera = viewModel.carteras.first!
        
        viewModel.showEditForm(for: cartera)
        
        if case .edit(let carteraEdit) = viewModel.formState {
            XCTAssertEqual(carteraEdit.id, cartera.id)
        } else {
            XCTFail("Estado del formulario debería ser .edit")
        }
    }
}
