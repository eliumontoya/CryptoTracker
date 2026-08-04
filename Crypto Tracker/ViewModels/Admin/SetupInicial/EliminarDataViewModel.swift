import SwiftUI
import SwiftData


struct DeleteOptions {
    var cryptos: Bool = false
    var carteras: Bool = false
    var fiats: Bool = false
    var movimientos: Bool = false
    var historicos: Bool = false
    var holdings: Bool = false
    var all: Bool = false
    
    mutating func toggleAll() {
        all = !all
        if all {
            cryptos = true
            carteras = true
            fiats = true
            movimientos = true
            historicos = true
            holdings = true
        } else {
            cryptos = false
            carteras = false
            fiats = false
            movimientos = false
            historicos = false
            holdings = false
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
    private var movimientos: [Movimiento]
    private var preciosHistoricos: [PrecioHistorico]
    private var syncConfigs: [CryptoSyncConfig]
    private var holdings: [Holding]
    
    var canDelete: Bool {
            deleteOptions.all ||
            deleteOptions.cryptos ||
            deleteOptions.carteras ||
            deleteOptions.fiats ||
            deleteOptions.movimientos ||
            deleteOptions.historicos ||
            deleteOptions.holdings
        }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Initialize queries
        let cryptoDescriptor = FetchDescriptor<Crypto>()
        let carteraDescriptor = FetchDescriptor<Cartera>()
        let fiatDescriptor = FetchDescriptor<FIAT>()
        let movimientosDescriptor = FetchDescriptor<Movimiento>()
        let preciosDescriptor = FetchDescriptor<PrecioHistorico>()
        let syncConfigDescriptor = FetchDescriptor<CryptoSyncConfig>()
        let holdingsDescriptor = FetchDescriptor<Holding>()
        
        do {
            self.cryptos = try modelContext.fetch(cryptoDescriptor)
            self.carteras = try modelContext.fetch(carteraDescriptor)
            self.fiats = try modelContext.fetch(fiatDescriptor)
            self.movimientos = try modelContext.fetch(movimientosDescriptor)
            self.preciosHistoricos = try modelContext.fetch(preciosDescriptor)
            self.syncConfigs = try modelContext.fetch(syncConfigDescriptor)
            self.holdings = try modelContext.fetch(holdingsDescriptor)
        } catch {
            // Handle error - could use a more robust error handling mechanism
            print("Error fetching data: \(error)")
            self.cryptos = []
            self.carteras = []
            self.fiats = []
            self.movimientos = []
            self.preciosHistoricos = []
            self.syncConfigs = []
            self.holdings = []
        }
    }
    
    func agregarLog(_ mensaje: String) {
        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
    }
    
    func borrarDatos() async {
        isDeleting = true
        deleteCompleted = false
        
        
        agregarLog("Iniciando borrado de datos...")
        
        // Borrando movimientos
        if deleteOptions.all || deleteOptions.movimientos {
            agregarLog("Borrando movimientos de ingreso y salida...")
            movimientos.forEach { modelContext.delete($0) }
        }

        // borrando precios historicos
        if deleteOptions.all || deleteOptions.historicos {
            agregarLog("Borrando precios históricos...")
            preciosHistoricos.forEach { modelContext.delete($0) }
            
            agregarLog("Borrando configuraciones de sincronización...")
            syncConfigs.forEach { modelContext.delete($0) }
        }

        // borrando holdings (deben borrarse antes que cryptos y carteras)
        if deleteOptions.all || deleteOptions.holdings {
            agregarLog("Borrando holdings...")
            holdings.forEach { modelContext.delete($0) }
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
            deleteCompleted = true
            isDeleting = false
        } catch {
            modelContext.rollback()
            agregarLog("❌ Error al guardar cambios: \(error.localizedDescription)")
            isDeleting = false
        }
        
    }
}
