import SwiftUI
import SwiftData

@main
struct CryptoTrackerApp: App {
    let container: ModelContainer
    let dependencies: AppDependencyContainer

    init() {
        do {
            // Definimos el esquema con versión
           
            let schema = Schema([
                FIAT.self,
                Crypto.self,
                Cartera.self,
                Portfolio.self,
                Holding.self,
                Movimiento.self,
                PrecioHistorico.self,
                PortfolioSnapshot.self,
                CryptoSyncConfig.self
            ], version: .init(5, 1, 0))
            
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

            // Limpieza de registros huérfanos (Holdings, Movimientos, etc. que
            // referencian Cryptos eliminados). Debe correr ANTES de cualquier
            // acceso a datos para evitar crashes por relaciones invalidadas.
            OrphanCleanupMigration.apply(in: container.mainContext)

            // Migración de datos v2 → v3: carteras huérfanas al portafolio por defecto
            PortfolioMigration.apply(in: container.mainContext)

            // Inicializar el contenedor de dependencias
            dependencies = AppDependencyContainer(modelContext: container.mainContext)

        } catch {
            fatalError("Could not initialize ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
        .modelContainer(container)
    }
}
