//
//  AdminCryptosViewModelTests.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 12/02/25.
//
import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class AdminCryptosViewModelTests: XCTestCase {
    var sut: AdminCryptosViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Crypto.self,
            Cartera.self,
            Portfolio.self,
            Holding.self,
            FIAT.self,
            Movimiento.self,
            PrecioHistorico.self,
            PortfolioSnapshot.self,
            CryptoSyncConfig.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        sut = AdminCryptosViewModel(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        sut = nil
        modelContext = nil
        modelContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    /// Test si el ViewModel se inicializa correctamente con un array vacío de cryptos
    func testInitialState() {
        XCTAssertTrue(sut.cryptos.isEmpty)
        XCTAssertNil(sut.formState)
        XCTAssertFalse(sut.showingDeleteAlert)
        XCTAssertNil(sut.selectedCrypto)
    }
    
    // MARK: - CRUD Operation Tests
    
    /// Test si se puede agregar una nueva crypto correctamente
    func testAddCrypto() throws {
        // Given
        let nombre = "Bitcoin"
        let simbolo = "BTC"
        let precio: Decimal = 50000.0
        
        // When
        sut.addCrypto(nombre: nombre, simbolo: simbolo, precio: precio)
        
        // Then
        XCTAssertEqual(sut.cryptos.count, 1)
        let crypto = try XCTUnwrap(sut.cryptos.first)
        XCTAssertEqual(crypto.nombre, nombre)
        XCTAssertEqual(crypto.simbolo, simbolo)
        XCTAssertEqual(crypto.precio, precio)
    }
    
    /// Test si se puede actualizar una crypto existente
    func testUpdateCrypto() throws {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        modelContext.insert(crypto)
        sut.loadCryptos()
        
        // When
        let newNombre = "Bitcoin Cash"
        let newSimbolo = "BCH"
        let newPrecio: Decimal = 60000.0
        sut.updateCrypto(crypto, nombre: newNombre, simbolo: newSimbolo, precio: newPrecio)
        
        // Then
        XCTAssertEqual(crypto.nombre, newNombre)
        XCTAssertEqual(crypto.simbolo, newSimbolo)
        XCTAssertEqual(crypto.precio, newPrecio)
        
        // Verificar que se creó el histórico de precios
        let descriptor = FetchDescriptor<PrecioHistorico>()
        let historicos = try modelContext.fetch(descriptor)
        XCTAssertEqual(historicos.count, 1)
        XCTAssertEqual(historicos.first?.precio, 50000.0)
    }
    
    /// Test si se puede eliminar una crypto correctamente
    func testDeleteCrypto() throws {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        modelContext.insert(crypto)
        sut.loadCryptos()
        XCTAssertEqual(sut.cryptos.count, 1)
        
        // When
        sut.requestDeletion(of: [crypto])
        sut.confirmDeletion()
        
        // Then
        XCTAssertTrue(sut.cryptos.isEmpty)
    }

    func testRequestDeletionBlocksCryptoWithHolding() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let portfolio = Portfolio(nombre: "Principal", isDefault: true)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WAL", portfolio: portfolio)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        modelContext.insert(crypto)
        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(holding)
        try modelContext.save()
        sut.loadCryptos()

        sut.requestDeletion(of: [crypto])

        XCTAssertTrue(sut.showingDeleteAlert)
        XCTAssertFalse(sut.deleteRequiresConfirmation)
        XCTAssertTrue(sut.deleteAlertMessage.contains("datos asociados") || sut.deleteAlertMessage.contains("holdings"))
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Crypto>()), 1)
    }

    func testConfirmDeletionRemovesCryptoHistoryAndSyncConfigTogether() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let history = PrecioHistorico(crypto: crypto, precio: 49000, fecha: Date())
        let syncConfig = CryptoSyncConfig(crypto: crypto, syncUrl: "https://example.com", defaultPrice: 50000)
        modelContext.insert(crypto)
        modelContext.insert(history)
        modelContext.insert(syncConfig)
        try modelContext.save()
        sut.loadCryptos()

        sut.requestDeletion(of: [crypto])

        XCTAssertTrue(sut.showingDeleteAlert)
        XCTAssertTrue(sut.deleteRequiresConfirmation)
        XCTAssertTrue(sut.deleteAlertMessage.contains("1 históricos"))
        XCTAssertTrue(sut.deleteAlertMessage.contains("1 configuraciones"))

        sut.confirmDeletion()

        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Crypto>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<PrecioHistorico>()), 0)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<CryptoSyncConfig>()), 0)
    }

    func testRequestDeletionBlocksCryptoWithMovement() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let portfolio = Portfolio(nombre: "Principal", isDefault: true)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WAL", portfolio: portfolio)
        let movement = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50000,
            cartera: cartera,
            crypto: crypto
        )
        modelContext.insert(crypto)
        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(movement)
        try modelContext.save()
        sut.loadCryptos()

        sut.requestDeletion(of: [crypto])

        XCTAssertFalse(sut.deleteRequiresConfirmation)
        XCTAssertTrue(sut.deleteAlertMessage.contains("movimientos o holdings"))
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Crypto>()), 1)
    }

    func testConfirmDeletionDeletesEverySelectedUnreferencedCrypto() throws {
        let bitcoin = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let ether = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        modelContext.insert(bitcoin)
        modelContext.insert(ether)
        try modelContext.save()
        sut.loadCryptos()

        sut.requestDeletion(of: [bitcoin, ether])
        XCTAssertTrue(sut.deleteRequiresConfirmation)

        sut.confirmDeletion()

        XCTAssertTrue(sut.cryptos.isEmpty)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Crypto>()), 0)
        XCTAssertFalse(sut.showingDeleteAlert)
    }

    func testAddFailurePublishesErrorAndKeepsFormOpen() throws {
        sut = AdminCryptosViewModel(modelContext: modelContext) { _ in throw PersistenceFailure.expected }
        sut.showAddForm()

        let didSave = sut.addCrypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)

        XCTAssertFalse(didSave)
        XCTAssertNotNil(sut.formErrorMessage)
        XCTAssertNotNil(sut.formState)
        XCTAssertTrue(sut.cryptos.isEmpty)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<Crypto>()), 0)
    }

    func testUpdateFailurePublishesErrorAndKeepsFormOpen() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        modelContext.insert(crypto)
        try modelContext.save()
        sut = AdminCryptosViewModel(modelContext: modelContext) { _ in throw PersistenceFailure.expected }
        sut.showEditForm(for: crypto)

        let didSave = sut.updateCrypto(crypto, nombre: "Changed", simbolo: "CHG", precio: 1)

        XCTAssertFalse(didSave)
        XCTAssertNotNil(sut.formErrorMessage)
        XCTAssertNotNil(sut.formState)
        XCTAssertEqual(try modelContext.fetchCount(FetchDescriptor<PrecioHistorico>()), 0)
    }
    
    // MARK: - Form State Tests
    
    /// Test si se maneja correctamente el estado del formulario para agregar
    func testShowAddForm() {
        // When
        sut.showAddForm()
        
        // Then
        if case .add = sut.formState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Form state should be .add")
        }
    }
    
    /// Test si se maneja correctamente el estado del formulario para editar
    func testShowEditForm() {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        
        // When
        sut.showEditForm(for: crypto)
        
        // Then
        if case .edit(let editCrypto) = sut.formState {
            XCTAssertEqual(editCrypto.id, crypto.id)
        } else {
            XCTFail("Form state should be .edit")
        }
    }
    
    /// Test si se cierra correctamente el formulario
    func testCloseForm() {
        // Given
        sut.showAddForm()
        XCTAssertNotNil(sut.formState)
        
        // When
        sut.closeForm()
        
        // Then
        XCTAssertNil(sut.formState)
    }
    
    // MARK: - Cache Tests
    
    /// Test si el caché funciona correctamente para los cálculos de crypto
    func testCryptoCalculosCache() {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        
        // When - Primera llamada (debería guardar en caché)
        let firstResult = sut.getCalculosCrypto(crypto)
        
        // Modificar la crypto (pero no a través del ViewModel)
        crypto.precio = 60000.0
        
        // Then - Segunda llamada (debería usar el caché)
        let secondResult = sut.getCalculosCrypto(crypto)
        
        // El resultado debería ser el mismo que el primero (cacheado)
        XCTAssertEqual(firstResult.precio, secondResult.precio)
        
        // Limpiar caché y obtener nuevo resultado
        sut.clearCache()
        let thirdResult = sut.getCalculosCrypto(crypto)
        
        // El nuevo resultado debería reflejar el cambio
        XCTAssertEqual(thirdResult.precio, 60000.0)
    }
    
    /// Test si el caché se limpia al actualizar una crypto
    func testCacheClearsOnUpdate() throws {
        // Given
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        modelContext.insert(crypto)
        sut.loadCryptos()
        
        // When - Obtener datos iniciales
        let initialResult = sut.getCalculosCrypto(crypto)
        
        // Actualizar crypto
        sut.updateCrypto(crypto, nombre: "Bitcoin", simbolo: "BTC", precio: 60000.0)
        
        // Then - El nuevo resultado debería ser diferente
        let newResult = sut.getCalculosCrypto(crypto)
        XCTAssertNotEqual(initialResult.precio, newResult.precio)
    }
    
    /// Test si el ordenamiento de cryptos funciona correctamente
    func testCryptoSorting() {
        // Given
        let crypto1 = Crypto(nombre: "Zcash", simbolo: "ZEC", precio: 100.0)
        let crypto2 = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000.0)
        let crypto3 = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000.0)
        
        // When
        sut.addCrypto(nombre: crypto1.nombre, simbolo: crypto1.simbolo, precio: crypto1.precio)
        sut.addCrypto(nombre: crypto2.nombre, simbolo: crypto2.simbolo, precio: crypto2.precio)
        sut.addCrypto(nombre: crypto3.nombre, simbolo: crypto3.simbolo, precio: crypto3.precio)
        
        // Then
        XCTAssertEqual(sut.cryptos[0].nombre, "Bitcoin")
        XCTAssertEqual(sut.cryptos[1].nombre, "Ethereum")
        XCTAssertEqual(sut.cryptos[2].nombre, "Zcash")
    }
}

private enum PersistenceFailure: Error {
    case expected
}
