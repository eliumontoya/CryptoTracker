import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class SnapshotServiceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var service: SnapshotService!

    override func setUp() {
        super.setUp()
        let schema = Schema([
            Crypto.self,
            Cartera.self,
            Portfolio.self,
            Holding.self,
            Movimiento.self,
            PortfolioSnapshot.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        service = SwiftDataSnapshotService()
    }

    override func tearDown() {
        service = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    func testRecordDailySnapshotCreatesSnapshot() async throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)

        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(holding)
        modelContext.insert(movimiento)
        try modelContext.save()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.totalUSD, 50000)
    }

    func testRecordDailySnapshotUpdatesExistingSnapshotForSameDay() async throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(holding)
        try modelContext.save()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)
        crypto.precio = 60000
        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.totalUSD, 60000)
    }
}
