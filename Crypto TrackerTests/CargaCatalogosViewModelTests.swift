import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class CargaCatalogosViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: CargaCatalogosViewModel!
    
    override func setUp() async throws {
        // Configurar un contenedor de modelo en memoria para pruebas
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for:
                Cartera.self,
                Crypto.self,
                FIAT.self,
                CryptoSyncConfig.self
            ,
            configurations: config
        )
        modelContext = modelContainer.mainContext
        
        // Crear ViewModel con el contexto de prueba
        viewModel = CargaCatalogosViewModel(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        // Limpiar después de cada prueba
        modelContainer = nil
        modelContext = nil
        viewModel = nil
    }
    
    // Prueba para cargar Carteras
    func testCargarCarteras() async throws {
        // Crear un archivo temporal de prueba
        let contenido = """
        Binance,BNCE
        Coinbase,CNBS
        Kraken,KRKN
        """
        let url = try crearArchivoTemporal(contenido: contenido)
        
        // Ejecutar la carga
        let totalCargados = try await viewModel.cargarCarteras(desde: url)
        
        // Verificaciones
        XCTAssertEqual(totalCargados, 3, "Deben cargarse 3 carteras")
        
        // Verificar que las carteras se guardaron correctamente
        let fetchDescriptor = FetchDescriptor<Cartera>()
        let carteras = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(carteras.count, 3, "Deben existir 3 carteras en el contexto")
        XCTAssertTrue(carteras.contains { $0.nombre == "Binance" }, "Debe contener Binance")
        XCTAssertTrue(carteras.contains { $0.nombre == "Coinbase" }, "Debe contener Coinbase")
        XCTAssertTrue(carteras.contains { $0.nombre == "Kraken" }, "Debe contener Kraken")
    }
    
    // Prueba para cargar Cryptos
    func testCargarCryptos() async throws {
        let contenido = """
        Bitcoin,BTC
        Ethereum,ETH
        Cardano,ADA
        """
        let url = try crearArchivoTemporal(contenido: contenido)
        
        let totalCargados = try await viewModel.cargarCryptos(desde: url)
        
        XCTAssertEqual(totalCargados, 3, "Deben cargarse 3 cryptos")
        
        let fetchDescriptor = FetchDescriptor<Crypto>()
        let cryptos = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(cryptos.count, 3, "Deben existir 3 cryptos en el contexto")
        XCTAssertTrue(cryptos.contains { $0.simbolo == "BTC" }, "Debe contener Bitcoin")
        XCTAssertTrue(cryptos.contains { $0.simbolo == "ETH" }, "Debe contener Ethereum")
        XCTAssertTrue(cryptos.contains { $0.simbolo == "ADA" }, "Debe contener Cardano")
    }
    
    // Prueba para cargar FIAT
    func testCargarFIAT() async throws {
        let contenido = """
        Dolar Estadounidense,USD,1.0
        Euro,EUR,0.92
        Yen Japonés,JPY,134.5
        """
        let url = try crearArchivoTemporal(contenido: contenido)
        
        let totalCargados = try await viewModel.cargarFIAT(desde: url)
        
        XCTAssertEqual(totalCargados, 3, "Deben cargarse 3 monedas FIAT")
        
        let fetchDescriptor = FetchDescriptor<FIAT>()
        let fiats = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(fiats.count, 3, "Deben existir 3 monedas FIAT en el contexto")
        XCTAssertTrue(fiats.contains { $0.simbolo == "USD" }, "Debe contener USD")
        XCTAssertTrue(fiats.contains { $0.simbolo == "EUR" }, "Debe contener EUR")
        XCTAssertTrue(fiats.contains { $0.simbolo == "JPY" }, "Debe contener JPY")
    }
    
    // Prueba para cargar SyncConfig (requiere Cryptos precargadas)
    func testCargarSyncConfig() async throws {
        // Primero, cargar algunas cryptos
        let cryptoContenido = """
        Bitcoin,BTC
        Ethereum,ETH
        """
        let cryptoURL = try crearArchivoTemporal(contenido: cryptoContenido)
        
        _ = try await viewModel.cargarCryptos(desde: cryptoURL)
        
        // Ahora cargar SyncConfig
        let contenido = """
        BTC,https://api.bitcoin.com/price,50000.0
        ETH,https://api.ethereum.com/price,3000.0
        """
        let url = try crearArchivoTemporal(contenido: contenido)
        
        let totalCargados = try await viewModel.cargarSyncConfig(desde: url)
        
        XCTAssertEqual(totalCargados, 2, "Deben cargarse 2 configuraciones de sync")
        
        let fetchDescriptor = FetchDescriptor<CryptoSyncConfig>()
        let configs = try modelContext.fetch(fetchDescriptor)
        
        XCTAssertEqual(configs.count, 2, "Deben existir 2 configuraciones de sync en el contexto")
        XCTAssertTrue(configs.contains { config in
            guard let crypto = config.crypto else { return false }
            return crypto.simbolo == "BTC"
        }, "Debe contener config para BTC")
        
        XCTAssertTrue(configs.contains { config in
            guard let crypto = config.crypto else { return false }
            return crypto.simbolo == "ETH"
        }, "Debe contener config para ETH")
     }
    
    // Prueba de formato inválido
    func testCargarCarterasFormatoInvalido() async throws {
        let contenido = """
        Binance,BNCE,Extra
        Coinbase
        """
        let url = try crearArchivoTemporal(contenido: contenido)
        
        do {
            _ = try await viewModel.cargarCarteras(desde: url)
            XCTFail("Debería haber lanzado un error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Formato inválido"), "Debe lanzar error de formato")
        }
    }
    
    // Método auxiliar para crear archivos temporales
    private func crearArchivoTemporal(contenido: String) throws -> URL {
        let temporalDirectorio = FileManager.default.temporaryDirectory
        let archivoURL = temporalDirectorio.appendingPathComponent(UUID().uuidString + ".csv")
        
        try contenido.write(to: archivoURL, atomically: true, encoding: .utf8)
        
        return archivoURL
    }
    
    // Prueba de carga completa de archivos
    func testCargarArchivosCompleto() async throws {
        // Preparar archivos de prueba
        let carterasContenido = "Binance,BNCE\nCoinbase,CNBS"
        let cryptosContenido = "Bitcoin,BTC\nEthereum,ETH"
        let fiatContenido = "Dolar Estadounidense,USD,1.0\nEuro,EUR,0.92"
        let syncContenido = "BTC,https://api.bitcoin.com/price,50000.0"
        
        let carterasURL = try crearArchivoTemporal(contenido: carterasContenido)
        let cryptosURL = try crearArchivoTemporal(contenido: cryptosContenido)
        let fiatURL = try crearArchivoTemporal(contenido: fiatContenido)
        let syncURL = try crearArchivoTemporal(contenido: syncContenido)
        
        // Ejecutar carga de archivos
        await viewModel.cargarArchivos(
            carterasURL: carterasURL,
            cryptosURL: cryptosURL,
            fiatURL: fiatURL,
            syncURL: syncURL
        )
        
        // Verificar que los registros se cargaron correctamente
        XCTAssertEqual(viewModel.totalCargados["Carteras"], 2, "Deben cargarse 2 carteras")
        XCTAssertEqual(viewModel.totalCargados["Cryptos"], 2, "Deben cargarse 2 cryptos")
        XCTAssertEqual(viewModel.totalCargados["FIAT"], 2, "Deben cargarse 2 monedas FIAT")
        XCTAssertEqual(viewModel.totalCargados["Sync"], 1, "Deben cargarse 1 configuración de sync")
        
        // Verificar estados finales
        XCTAssertFalse(viewModel.isLoading, "La carga debe haber terminado")
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains("Proceso de carga completado exitosamente") }), "Debe haber un log de carga exitosa")
    }
}
