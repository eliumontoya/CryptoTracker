import SwiftUI
import SwiftData

@main
struct CryptoTrackerApp: App {
    let container: ModelContainer
    
    init() {
        do {
            // Definimos el esquema con versión
           
            let schema = Schema([
                FIAT.self,
                Crypto.self,
                Cartera.self,
                MovimientoIngreso.self,
                MovimientoEgreso.self,
                MovimientoEntreCarteras.self,
                MovimientoSwap.self,
                PrecioHistorico.self,
                CryptoSyncConfig.self
            ], version: .init(2, 0, 0))
            
            // Configuración del modelo
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            // Inicialización del contenedor
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
