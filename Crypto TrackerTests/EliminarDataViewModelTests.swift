import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class EliminarDataViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: EliminarDataViewModel!
    
    override func setUp() async throws {
        // Configurar un contenedor de modelo en memoria para pruebas
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Crypto.self,
            Cartera.self,
            FIAT.self,
            MovimientoIngreso.self,
            MovimientoEgreso.self,
            MovimientoEntreCarteras.self,
            MovimientoSwap.self,
            PrecioHistorico.self,
            CryptoSyncConfig.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
        
        // Preparar datos de prueba
        try prepararDatosDePrueba()
        
        // Crear ViewModel
        viewModel = EliminarDataViewModel(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        // Limpiar después de cada prueba
        modelContainer = nil
        modelContext = nil
        viewModel = nil
    }
    
    // Método para preparar datos de prueba
    private func prepararDatosDePrueba() throws {
        // Crear algunas cryptos
        let bitcoin = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let ethereum = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        modelContext.insert(bitcoin)
        modelContext.insert(ethereum)
        
        // Crear carteras
        let cartera1 = Cartera(nombre: "Binance", simbolo: "BNCE")
        let cartera2 = Cartera(nombre: "Coinbase", simbolo: "CNBS")
        modelContext.insert(cartera1)
        modelContext.insert(cartera2)
        
        // Crear FIAT
        let usd = FIAT(nombre: "Dolar", simbolo: "USD", precioUSD: 1)
        let eur = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 0.92)
        modelContext.insert(usd)
        modelContext.insert(eur)
        
        // Crear movimientos de ingreso
       
        let movIngreso1 = MovimientoIngreso(
                fecha: Date(),
                cantidadCrypto: Decimal(0.5),
                precioUSD: Decimal(50000),
                usaFiatAlterno: false,
                cartera: cartera1,
                crypto: bitcoin
            )

        
          let movIngreso2 = MovimientoIngreso(
              fecha: Date(),
              cantidadCrypto: Decimal(2),
              precioUSD: Decimal(3000),
              usaFiatAlterno: false,
              cartera: cartera2,
              crypto: ethereum
          )
          
          // Crear movimientos de egreso
          let movEgreso1 = MovimientoEgreso(
              fecha: Date(),
              cantidadCrypto: Decimal(0.1),
              precioUSD: Decimal(50000),
              usaFiatAlterno: false,
              cartera: cartera1,
              crypto: bitcoin
          )
          
          let movEgreso2 = MovimientoEgreso(
              fecha: Date(),
              cantidadCrypto: Decimal(0.5),
              precioUSD: Decimal(3000),
              usaFiatAlterno: false,
              cartera: cartera2,
              crypto: ethereum
          )
        
        
        modelContext.insert(movIngreso1)
           modelContext.insert(movIngreso2)
           modelContext.insert(movEgreso1)
           modelContext.insert(movEgreso2)
        
        // Guardar cambios
        try modelContext.save()
    }
    
    // Prueba de borrado de datos
    func testBorradoDeDatos() async throws {
        // Verificar datos antes del borrado
        let cryptosAntes = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carterasAntes = try modelContext.fetch(FetchDescriptor<Cartera>())
        let fiatsAntes = try modelContext.fetch(FetchDescriptor<FIAT>())
        let movIngresosAntes = try modelContext.fetch(FetchDescriptor<MovimientoIngreso>())
        let movEgresosAntes = try modelContext.fetch(FetchDescriptor<MovimientoEgreso>())
        
        XCTAssertFalse(cryptosAntes.isEmpty, "Debe haber cryptos antes del borrado")
        XCTAssertFalse(carterasAntes.isEmpty, "Debe haber carteras antes del borrado")
        XCTAssertFalse(fiatsAntes.isEmpty, "Debe haber FIAT antes del borrado")
        XCTAssertFalse(movIngresosAntes.isEmpty, "Debe haber movimientos de ingreso antes del borrado")
        XCTAssertFalse(movEgresosAntes.isEmpty, "Debe haber movimientos de egreso antes del borrado")
        
        // Ejecutar borrado
        await viewModel.borrarDatos()
        
        // Verificar que los datos se borraron
        let cryptosDespues = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carterasDespues = try modelContext.fetch(FetchDescriptor<Cartera>())
        let fiatsDespues = try modelContext.fetch(FetchDescriptor<FIAT>())
        let movIngresosDespues = try modelContext.fetch(FetchDescriptor<MovimientoIngreso>())
        let movEgresosDespues = try modelContext.fetch(FetchDescriptor<MovimientoEgreso>())
        
        XCTAssertTrue(cryptosDespues.isEmpty, "No deben quedar cryptos después del borrado")
        XCTAssertTrue(carterasDespues.isEmpty, "No deben quedar carteras después del borrado")
        XCTAssertTrue(fiatsDespues.isEmpty, "No deben quedar FIAT después del borrado")
        XCTAssertTrue(movIngresosDespues.isEmpty, "No deben quedar movimientos de ingreso después del borrado")
        XCTAssertTrue(movEgresosDespues.isEmpty, "No deben quedar movimientos de egreso después del borrado")
        
        // Verificar estados del ViewModel
        XCTAssertTrue(viewModel.deleteCompleted, "deleteCompleted debe ser true")
        XCTAssertFalse(viewModel.isDeleting, "isDeleting debe ser false")
    }
    
    // Prueba de logs
    func testLogsGeneradosEnBorrado() async throws {
        // Borrar datos
        await viewModel.borrarDatos()
        
        // Verificar logs
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains("Iniciando borrado de datos") }), "Debe haber un log de inicio de borrado")
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains("Borrando movimientos de ingreso") }), "Debe haber un log de borrado de movimientos de ingreso")
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains("Borrando cryptos") }), "Debe haber un log de borrado de cryptos")
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains("Borrado completado exitosamente") }), "Debe haber un log de borrado completado")
    }
    
    // Prueba de método de log
    func testAgregarLog() {
        let mensajePrueba = "Mensaje de prueba"
        viewModel.agregarLog(mensajePrueba)
        
        XCTAssertTrue(viewModel.logs.contains(where: { $0.contains(mensajePrueba) }), "El mensaje de log debe estar presente")
    }
}
