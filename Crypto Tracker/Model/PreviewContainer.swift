import SwiftUI
import SwiftData

@MainActor
class PreviewContainer {
    static let shared = PreviewContainer()
    
    let container: ModelContainer
    let context: ModelContext
    
    init() {
        let schema = Schema([
            FIAT.self,
            Crypto.self,
            Cartera.self,
            MovimientoIngreso.self,
            MovimientoEgreso.self,
            MovimientoEntreCarteras.self,
            MovimientoSwap.self,
            PrecioHistorico.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            context = ModelContext(container)
        } catch {
            fatalError("Could not create preview container: \(error.localizedDescription)")
        }
        
        // Crear datos de ejemplo
        createPreviewData()
    }
    
    private func createPreviewData() {
        // Crear FIATs
        let usd = FIAT(nombre: "US Dollar", simbolo: "USD", precioUSD: 1.0)
        let eur = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.08)
        let mxn = FIAT(nombre: "Peso Mexicano", simbolo: "MXN", precioUSD: 0.058)
        
        // Crear Cryptos
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 43000.0)
        let eth = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 2250.0)
        let sol = Crypto(nombre: "Solana", simbolo: "SOL", precio: 98.0)
        
        // Crear Carteras
        let binance = Cartera(nombre: "Binance", simbolo: "BNB")
        let metamask = Cartera(nombre: "MetaMask", simbolo: "MM")
        let phantom = Cartera(nombre: "Phantom", simbolo: "PHT")
        
        // Insertar todos los objetos en el contexto
        [usd, eur, mxn].forEach { context.insert($0) }
        [btc, eth, sol].forEach { context.insert($0) }
        [binance, metamask, phantom].forEach { context.insert($0) }
        
        // Crear algunos movimientos de ejemplo
        
        // Movimiento con USD
        let movimiento1 = MovimientoIngreso(
            fecha: Date().addingTimeInterval(-86400), // Ayer
            cantidadCrypto: 0.23,
            precioUSD: 43478.26,
            usaFiatAlterno: false,
            cartera: binance,
            crypto: btc,
            fiatAlterno: nil
        )
        
        // Movimiento con FIAT alterno (EUR)
        let movimiento2 = MovimientoIngreso(
            fecha: Date().addingTimeInterval(-43200), // Hace 12 horas
            cantidadCrypto: 2.22,
            precioUSD: 2252.25,
            usaFiatAlterno: true,
            precioFiatAlterno: 2083.56,
            valorTotalFiatAlterno: 4625.50,
            cartera: metamask,
            crypto: eth,
            fiatAlterno: eur
        )
        
        // Movimiento con FIAT alterno (MXN)
        let movimiento3 = MovimientoIngreso(
            fecha: Date().addingTimeInterval(-21600), // Hace 6 horas
            cantidadCrypto: 5.0,
            precioUSD: 98.0,
            usaFiatAlterno: true,
            precioFiatAlterno: 1689.65,
            valorTotalFiatAlterno: 8448.25,
            cartera: phantom,
            crypto: sol,
            fiatAlterno: mxn
        )
        
        [movimiento1, movimiento2, movimiento3].forEach { context.insert($0) }
    }
}

// Extension para Preview
extension View {
    func withPreviewContainer() -> some View {
        self.modelContainer(PreviewContainer.shared.container)
    }
}
