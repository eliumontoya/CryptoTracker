import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class BackupServiceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var service: BackupService!

    override func setUp() {
        super.setUp()
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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        service = JSONBackupService()
    }

    override func tearDown() {
        service = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    private func seedContext() throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000, coingeckoId: "bitcoin")
        let fiat = FIAT(nombre: "Dollar", simbolo: "USD", precioUSD: 1)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)
        let snapshot = PortfolioSnapshot(date: Date(), totalUSD: 50000, portfolioId: portfolio.id)
        let syncConfig = CryptoSyncConfig(crypto: crypto, syncUrl: "bitcoin", defaultPrice: 45000)

        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(fiat)
        modelContext.insert(holding)
        modelContext.insert(movimiento)
        modelContext.insert(snapshot)
        modelContext.insert(syncConfig)
        try modelContext.save()
    }

    func testExportProducesNonEmptyJSON() throws {
        try seedContext()
        let data = try service.export(in: modelContext)
        XCTAssertFalse(data.isEmpty)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["cryptos"])
        XCTAssertNotNil(json?["carteras"])
        XCTAssertNotNil(json?["movimientos"])
    }

    func testRestoreReimportsData() throws {
        try seedContext()
        let data = try service.export(in: modelContext)

        try service.restore(from: data, in: modelContext)

        let cryptos = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
        let movimientos = try modelContext.fetch(FetchDescriptor<Movimiento>())
        let snapshots = try modelContext.fetch(FetchDescriptor<PortfolioSnapshot>())

        XCTAssertEqual(cryptos.count, 1)
        XCTAssertEqual(cryptos.first?.coingeckoId, "bitcoin")
        XCTAssertEqual(carteras.count, 1)
        XCTAssertEqual(movimientos.count, 1)
        XCTAssertEqual(snapshots.count, 1)
    }
}
