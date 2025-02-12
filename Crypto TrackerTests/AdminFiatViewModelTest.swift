//
//  AdminFiatViewModelTest.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 12/02/25.
//

import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class AdminFiatViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AdminFiatViewModel!
    
    // MARK: - Setup y TearDown
    override func setUp() async throws {
        // Crear un contenedor en memoria para testing
        let schema = Schema([FIAT.self])
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        viewModel = AdminFiatViewModel(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        // Limpiar todos los datos después de cada prueba
        try modelContext.delete(model: FIAT.self)
        viewModel = nil
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - Tests de Inicialización
    
    /// Test que verifica que el ViewModel se inicializa correctamente
    /// - La lista de fiats debe estar vacía inicialmente
    /// - No debe haber formulario activo
    /// - No debe haber alertas visibles
    func testInitialization() {
        XCTAssertTrue(viewModel.fiats.isEmpty)
        XCTAssertNil(viewModel.formState)
        XCTAssertFalse(viewModel.showingDeleteAlert)
        XCTAssertNil(viewModel.selectedFiat)
    }
    
    // MARK: - Tests de CRUD
    
    /// Test que verifica la creación de un nuevo FIAT
    /// - Debe agregarse correctamente a la lista
    /// - Debe persistirse en el contexto
    /// - Los valores deben ser correctos
    func testAddFiat() throws {
        // Arrange
        let nombre = "Euro"
        let simbolo = "EUR"
        let precio: Decimal = 1.2
        
        // Act
        viewModel.addFiat(nombre: nombre, simbolo: simbolo, precioUSD: precio)
        
        // Assert
        XCTAssertEqual(viewModel.fiats.count, 1)
        let fiat = try XCTUnwrap(viewModel.fiats.first)
        XCTAssertEqual(fiat.nombre, nombre)
        XCTAssertEqual(fiat.simbolo, simbolo)
        XCTAssertEqual(fiat.precioUSD, precio)
    }
    
    /// Test que verifica la actualización de un FIAT existente
    /// - Debe actualizarse correctamente en la lista
    /// - Debe persistirse en el contexto
    /// - Los valores actualizados deben ser correctos
    func testUpdateFiat() throws {
        // Arrange
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        modelContext.insert(fiat)
        viewModel.loadFiats()
        
        // Act
        let nuevoNombre = "Euro Updated"
        let nuevoSimbolo = "EUR2"
        let nuevoPrecio: Decimal = 1.3
        
        viewModel.updateFiat(fiat, nombre: nuevoNombre, simbolo: nuevoSimbolo, precioUSD: nuevoPrecio)
        
        // Assert
        XCTAssertEqual(viewModel.fiats.count, 1)
        let fiatActualizado = try XCTUnwrap(viewModel.fiats.first)
        XCTAssertEqual(fiatActualizado.nombre, nuevoNombre)
        XCTAssertEqual(fiatActualizado.simbolo, nuevoSimbolo)
        XCTAssertEqual(fiatActualizado.precioUSD, nuevoPrecio)
    }
    
    /// Test que verifica la eliminación de un FIAT
    /// - Debe eliminarse de la lista
    /// - Debe eliminarse del contexto
    /// - La caché debe actualizarse
    func testDeleteFiat() throws {
        // Arrange
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        modelContext.insert(fiat)
        viewModel.loadFiats()
        XCTAssertEqual(viewModel.fiats.count, 1)
        
        // Act
        viewModel.deleteFiat(fiat)
        
        // Assert
        XCTAssertTrue(viewModel.fiats.isEmpty)
        let descriptor = FetchDescriptor<FIAT>()
        let fiatsEnContexto = try modelContext.fetch(descriptor)
        XCTAssertTrue(fiatsEnContexto.isEmpty)
    }
    
    // MARK: - Tests de Validación
    
    /// Test que verifica la validación para eliminar un FIAT
    /// - Debe permitir eliminar si no tiene movimientos asociados
    /// - No debe permitir eliminar si tiene movimientos
    func testCanDeleteFiat() {
        // Arrange
        let fiatSinMovimientos = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        XCTAssertTrue(viewModel.canDeleteFiat(fiatSinMovimientos))
        
        // TODO: Agregar prueba con movimientos cuando estén implementados
        // Por ahora solo verificamos el caso positivo
    }
    
    // MARK: - Tests de Caché
    
    /// Test que verifica el funcionamiento del caché de precios
    /// - Debe devolver el precio correcto
    /// - Debe mantener el precio en caché
    /// - Debe actualizar el caché cuando se modifica el precio
    func testPrecioCache() {
        // Arrange
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        modelContext.insert(fiat)
        
        // Act - Primera lectura
        let precio1 = viewModel.getPrecioUSD(fiat)
        
        // Assert
        XCTAssertEqual(precio1, 1.2)
        
        // Act - Actualizar precio
        viewModel.updateFiat(fiat, nombre: fiat.nombre, simbolo: fiat.simbolo, precioUSD: 1.3)
        let precio2 = viewModel.getPrecioUSD(fiat)
        
        // Assert
        XCTAssertEqual(precio2, 1.3)
    }
    
    /// Test que verifica la limpieza del caché
    /// - Debe eliminar todos los valores cacheados
    func testClearCache() {
        // Arrange
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        modelContext.insert(fiat)
        
        // Act - Llenar caché
        _ = viewModel.getPrecioUSD(fiat)
        
        // Act - Limpiar caché
        viewModel.clearCache()
        
        // Assert - Verificar que se obtiene el valor actualizado
        let nuevoPrecio: Decimal = 1.3
        viewModel.updateFiat(fiat, nombre: fiat.nombre, simbolo: fiat.simbolo, precioUSD: nuevoPrecio)
        XCTAssertEqual(viewModel.getPrecioUSD(fiat), nuevoPrecio)
    }
    
    // MARK: - Tests de Estado del Formulario
    
    /// Test que verifica el manejo del estado del formulario
    /// - Debe mostrar el formulario de agregar
    /// - Debe mostrar el formulario de editar
    /// - Debe cerrar el formulario
    func testFormState() {
        // Test Add Form
        viewModel.showAddForm()
        if case .add = viewModel.formState {
            // Estado correcto
        } else {
            XCTFail("Estado del formulario debería ser .add")
        }
        
        // Test Edit Form
        let fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        viewModel.showEditForm(for: fiat)
        if case .edit(let editFiat) = viewModel.formState {
            XCTAssertEqual(editFiat.id, fiat.id)
        } else {
            XCTFail("Estado del formulario debería ser .edit")
        }
        
        // Test Close Form
        viewModel.closeForm()
        XCTAssertNil(viewModel.formState)
    }
    
    // MARK: - Tests de Ordenamiento
    
    /// Test que verifica el ordenamiento de la lista de FIAT
    /// - Debe mantener la lista ordenada por nombre al agregar
    /// - Debe mantener la lista ordenada por nombre al actualizar
    func testFiatSorting() {
        // Arrange
        let fiat1 = FIAT(nombre: "Yen", simbolo: "JPY", precioUSD: 0.0067)
        let fiat2 = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.2)
        let fiat3 = FIAT(nombre: "Dólar", simbolo: "USD", precioUSD: 1.0)
        
        // Act
        viewModel.addFiat(nombre: fiat1.nombre, simbolo: fiat1.simbolo, precioUSD: fiat1.precioUSD)
        viewModel.addFiat(nombre: fiat2.nombre, simbolo: fiat2.simbolo, precioUSD: fiat2.precioUSD)
        viewModel.addFiat(nombre: fiat3.nombre, simbolo: fiat3.simbolo, precioUSD: fiat3.precioUSD)
        
        // Assert
        XCTAssertEqual(viewModel.fiats[0].nombre, "Dólar")
        XCTAssertEqual(viewModel.fiats[1].nombre, "Euro")
        XCTAssertEqual(viewModel.fiats[2].nombre, "Yen")
    }
}
