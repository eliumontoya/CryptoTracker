import SwiftUI
import SwiftData

@MainActor
class EliminarDataViewModel: ObservableObject {
    @Published var logs: [String] = []
    @Published var isDeleting = false
    @Published var deleteCompleted = false
    
    private let modelContext: ModelContext
    
    // Queries
    private var cryptos: [Crypto]
    private var carteras: [Cartera]
    private var fiats: [FIAT]
    private var movimientosIngreso: [MovimientoIngreso]
    private var movimientosEgreso: [MovimientoEgreso]
    private var movimientosEntreCarteras: [MovimientoEntreCarteras]
    private var movimientosSwap: [MovimientoSwap]
    private var preciosHistoricos: [PrecioHistorico]
    private var syncConfigs: [CryptoSyncConfig]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Initialize queries
        let cryptoDescriptor = FetchDescriptor<Crypto>()
        let carteraDescriptor = FetchDescriptor<Cartera>()
        let fiatDescriptor = FetchDescriptor<FIAT>()
        let ingresoDescriptor = FetchDescriptor<MovimientoIngreso>()
        let egresoDescriptor = FetchDescriptor<MovimientoEgreso>()
        let entreCarterasDescriptor = FetchDescriptor<MovimientoEntreCarteras>()
        let swapDescriptor = FetchDescriptor<MovimientoSwap>()
        let preciosDescriptor = FetchDescriptor<PrecioHistorico>()
        let syncConfigDescriptor = FetchDescriptor<CryptoSyncConfig>()
        
        do {
            self.cryptos = try modelContext.fetch(cryptoDescriptor)
            self.carteras = try modelContext.fetch(carteraDescriptor)
            self.fiats = try modelContext.fetch(fiatDescriptor)
            self.movimientosIngreso = try modelContext.fetch(ingresoDescriptor)
            self.movimientosEgreso = try modelContext.fetch(egresoDescriptor)
            self.movimientosEntreCarteras = try modelContext.fetch(entreCarterasDescriptor)
            self.movimientosSwap = try modelContext.fetch(swapDescriptor)
            self.preciosHistoricos = try modelContext.fetch(preciosDescriptor)
            self.syncConfigs = try modelContext.fetch(syncConfigDescriptor)
        } catch {
            // Handle error - could use a more robust error handling mechanism
            print("Error fetching data: \(error)")
            self.cryptos = []
            self.carteras = []
            self.fiats = []
            self.movimientosIngreso = []
            self.movimientosEgreso = []
            self.movimientosEntreCarteras = []
            self.movimientosSwap = []
            self.preciosHistoricos = []
            self.syncConfigs = []
        }
    }
    
    func agregarLog(_ mensaje: String) {
        // Condición para pruebas: detectar si se está ejecutando en un contexto de pruebas
               #if DEBUG
               if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                   // Para pruebas, agregar el log de manera síncrona
                   logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
                   return
               }
               #endif
               
               // Comportamiento normal para la app
               DispatchQueue.main.async { [weak self] in
                   self?.logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
               }
        
         
    }
    
    func borrarDatos() async {
        isDeleting = true
        
        // Borrando movimientos
        agregarLog("Iniciando borrado de datos...")
        
        // Movimientos
        agregarLog("Borrando movimientos de ingreso...")
        movimientosIngreso.forEach { modelContext.delete($0) }
        
        agregarLog("Borrando movimientos de egreso...")
        movimientosEgreso.forEach { modelContext.delete($0) }
        
        agregarLog("Borrando movimientos entre carteras...")
        movimientosEntreCarteras.forEach { modelContext.delete($0) }
        
        agregarLog("Borrando movimientos de swap...")
        movimientosSwap.forEach { modelContext.delete($0) }
        
        // Históricos
        agregarLog("Borrando precios históricos...")
        preciosHistoricos.forEach { modelContext.delete($0) }
        
        // Configuraciones
        agregarLog("Borrando configuraciones de sincronización...")
        syncConfigs.forEach { modelContext.delete($0) }
        
        // Catálogos
        agregarLog("Borrando carteras...")
        carteras.forEach { modelContext.delete($0) }
        
        agregarLog("Borrando cryptos...")
        cryptos.forEach { modelContext.delete($0) }
        
        agregarLog("Borrando monedas FIAT...")
        fiats.forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            agregarLog("✅ Borrado completado exitosamente")
            
            // Marcar como completado para mostrar el botón de cerrar
            DispatchQueue.main.async { [weak self] in
                self?.deleteCompleted = true
                self?.isDeleting = false
            }
        } catch {
            agregarLog("❌ Error al guardar cambios: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.isDeleting = false
            }
        }
    }
}
