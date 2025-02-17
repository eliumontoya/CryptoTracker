import SwiftUI
import SwiftData


struct DeleteOptions {
    var cryptos: Bool = false
    var carteras: Bool = false
    var fiats: Bool = false
    var movimientos: Bool = false
    var historicos: Bool = false
    var all: Bool = false
    
    mutating func toggleAll() {
        all = !all
        if all {
            cryptos = true
            carteras = true
            fiats = true
            movimientos = true
            historicos = true
        } else {
            cryptos = false
            carteras = false
            fiats = false
            movimientos = false
            historicos = false
        }
    }
}


@MainActor
class EliminarDataViewModel: ObservableObject {
    @Published var deleteOptions = DeleteOptions()

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
    
    var canDelete: Bool {
            deleteOptions.all ||
            deleteOptions.cryptos ||
            deleteOptions.carteras ||
            deleteOptions.fiats ||
            deleteOptions.movimientos ||
            deleteOptions.historicos
        }
    
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
        
        
        agregarLog("Iniciando borrado de datos...")
        
        // Borrando movimientos
        if deleteOptions.all || deleteOptions.movimientos {
            agregarLog("Borrando movimientos de ingreso...")
            movimientosIngreso.forEach { modelContext.delete($0) }
            
            agregarLog("Borrando movimientos de egreso...")
            movimientosEgreso.forEach { modelContext.delete($0) }
            
            agregarLog("Borrando movimientos entre carteras...")
            movimientosEntreCarteras.forEach { modelContext.delete($0) }
            
            agregarLog("Borrando movimientos de swap...")
            movimientosSwap.forEach { modelContext.delete($0) }
        }

        // borrando precios historicos
        if deleteOptions.all || deleteOptions.historicos {
            agregarLog("Borrando precios históricos...")
            preciosHistoricos.forEach { modelContext.delete($0) }
            
            agregarLog("Borrando configuraciones de sincronización...")
            syncConfigs.forEach { modelContext.delete($0) }
        }

        // borrando carteras
        if deleteOptions.all || deleteOptions.carteras {
            agregarLog("Borrando carteras...")
            carteras.forEach { modelContext.delete($0) }
        }

        // borrando cryptos
        if deleteOptions.all || deleteOptions.cryptos {
            agregarLog("Borrando cryptos...")
            cryptos.forEach { modelContext.delete($0) }
        }

        //borrando fiat
        if deleteOptions.all || deleteOptions.fiats {
            agregarLog("Borrando monedas FIAT...")
            fiats.forEach { modelContext.delete($0) }
        }

        // ejecutando los borrados
        do {
            try modelContext.save()
            agregarLog("✅ Borrado completado exitosamente")
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
