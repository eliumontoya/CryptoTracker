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

    private func seedPortfolio(cryptoPrice: Decimal = 50000) -> Portfolio {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: cryptoPrice)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)

        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(holding)
        modelContext.insert(movimiento)
        try! modelContext.save()
        return portfolio
    }

    func testRecordDailySnapshotCreatesSnapshot() async throws {
        let portfolio = seedPortfolio()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.totalUSD, 50000)
    }

    func testRecordDailySnapshotUpdatesExistingSnapshotForSameDay() async throws {
        let portfolio = seedPortfolio()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)
        let crypto = try modelContext.fetch(FetchDescriptor<Crypto>()).first
        crypto?.precio = 60000
        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.totalUSD, 60000)
    }

    func testFetchSnapshotsReturnsEmptyForUnknownPortfolio() {
        let snapshots = service.fetchSnapshots(for: UUID(), in: modelContext)
        XCTAssertTrue(snapshots.isEmpty)
    }

    func testRecordDailySnapshotPrunesOldSnapshots() async throws {
        let portfolio = seedPortfolio()
        let calendar = Calendar.current

        for dayOffset in 0..<370 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let snapshot = PortfolioSnapshot(date: calendar.startOfDay(for: date), totalUSD: Decimal(dayOffset), portfolioId: portfolio.id)
            modelContext.insert(snapshot)
        }
        try modelContext.save()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 365)
    }

    func testRecordDailySnapshotSortsByDateAscending() async throws {
        let portfolio = seedPortfolio()

        try await service.recordDailySnapshot(for: portfolio.id, in: modelContext)

        let snapshots = service.fetchSnapshots(for: portfolio.id, in: modelContext)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.portfolioId, portfolio.id)
    }
}
