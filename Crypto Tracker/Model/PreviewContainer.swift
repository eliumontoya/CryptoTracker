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
            Portfolio.self,
            Holding.self,
            Movimiento.self,
            PrecioHistorico.self,
            PortfolioSnapshot.self,
            CryptoSyncConfig.self
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
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 43000.0, coingeckoId: "bitcoin")
        let eth = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 2250.0, coingeckoId: "ethereum")
        let sol = Crypto(nombre: "Solana", simbolo: "SOL", precio: 98.0, coingeckoId: "solana")
        
        // Crear Portfolio por defecto
        let portfolio = Portfolio(nombre: "Portafolio Principal", descripcion: "Portafolio de ejemplo", isDefault: true)
        
        // Crear Carteras
        let binance = Cartera(nombre: "Binance", simbolo: "BNB", isMain: true, portfolio: portfolio)
        let metamask = Cartera(nombre: "MetaMask", simbolo: "MM", portfolio: portfolio)
        let phantom = Cartera(nombre: "Phantom", simbolo: "PHT", portfolio: portfolio)
        
        // Insertar todos los objetos en el contexto
        [usd, eur, mxn].forEach { context.insert($0) }
        [btc, eth, sol].forEach { context.insert($0) }
        context.insert(portfolio)
        [binance, metamask, phantom].forEach { context.insert($0) }
        
        // Crear algunos movimientos de ejemplo

        // Movimiento con USD
        let movimiento1 = Movimiento.entrada(
            fecha: Date().addingTimeInterval(-86400), // Ayer
            cantidadCrypto: 0.23,
            precioUSD: 43478.26,
            usaFiatAlterno: false,
            cartera: binance,
            crypto: btc,
            fiatAlterno: nil
        )
        
        // Movimiento con FIAT alterno (EUR)
        let movimiento2 = Movimiento.entrada(
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
        let movimiento3 = Movimiento.entrada(
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
        
        // Crear holdings materializados (balance por portfolio/cartera/crypto)
        let holding1 = Holding(portfolio: portfolio, cartera: binance, crypto: btc, cantidad: 0.23)
        let holding2 = Holding(portfolio: portfolio, cartera: metamask, crypto: eth, cantidad: 2.22)
        let holding3 = Holding(portfolio: portfolio, cartera: phantom, crypto: sol, cantidad: 5.0)
        
        [holding1, holding2, holding3].forEach { context.insert($0) }
    }
}

// Extension para Preview
extension View {
    func withPreviewContainer() -> some View {
        self.modelContainer(PreviewContainer.shared.container)
    }
}
