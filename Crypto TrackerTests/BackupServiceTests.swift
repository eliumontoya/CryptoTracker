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

    func testRestoreClearsExistingData() throws {
        try seedContext()
        let data = try service.export(in: modelContext)

        let extraCrypto = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        modelContext.insert(extraCrypto)
        try modelContext.save()

        try service.restore(from: data, in: modelContext)

        let cryptos = try modelContext.fetch(FetchDescriptor<Crypto>())
        XCTAssertEqual(cryptos.count, 1)
        XCTAssertEqual(cryptos.first?.simbolo, "BTC")
    }

    func testRestoreThrowsForUnsupportedVersion() throws {
        let container = [
            "version": 999,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "portfolios": [],
            "cryptos": [],
            "fiats": [],
            "carteras": [],
            "holdings": [],
            "movimientos": [],
            "preciosHistoricos": [],
            "snapshots": [],
            "syncConfigs": []
        ] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: container)

        do {
            try service.restore(from: data, in: modelContext)
            XCTFail("Expected unsupported version error")
        } catch {
            XCTAssertEqual(error as? BackupError, .unsupportedVersion)
        }
    }

    func testExportPreservesFiatCurrencies() throws {
        try seedContext()
        let data = try service.export(in: modelContext)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let fiats = json?["fiats"] as? [[String: Any]]
        XCTAssertEqual(fiats?.count, 1)
        XCTAssertEqual(fiats?.first?["simbolo"] as? String, "USD")
    }

    func testRestorePreservesSnapshotPortfolioId() throws {
        try seedContext()
        let data = try service.export(in: modelContext)
        let portfolioId = try modelContext.fetch(FetchDescriptor<Portfolio>()).first?.id

        try service.restore(from: data, in: modelContext)

        let snapshots = try modelContext.fetch(FetchDescriptor<PortfolioSnapshot>())
        XCTAssertEqual(snapshots.first?.portfolioId, portfolioId)
    }

    func testRoundTripRestoresEmptyBackup() throws {
        let data = try service.export(in: modelContext)
        try service.restore(from: data, in: modelContext)

        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<Crypto>()).count, 0)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<Cartera>()).count, 0)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<Movimiento>()).count, 0)
    }
}
