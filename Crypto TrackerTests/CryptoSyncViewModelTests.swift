import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class CryptoSyncViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: CryptoSyncViewModel!
    var mockPriceService: MockPriceService!

    override func setUp() {
        super.setUp()

        let schema = Schema([Crypto.self, CryptoSyncConfig.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        mockPriceService = MockPriceService()
        viewModel = CryptoSyncViewModel(modelContext: modelContext, priceService: mockPriceService)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
        mockPriceService = nil
        super.tearDown()
    }

    func testInitialViewModelState() {
        XCTAssertFalse(viewModel.state.isSyncing)
        XCTAssertTrue(viewModel.state.cryptos.isEmpty)
        XCTAssertTrue(viewModel.state.syncConfigs.isEmpty)
        XCTAssertTrue(viewModel.state.logEntries.isEmpty)
    }

    func testCryptoCoingeckoId() {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000, coingeckoId: "bitcoin")
        XCTAssertEqual(crypto.coingeckoId, "bitcoin")
    }

    func testSaveSyncConfigurationStoresCoingeckoId() {
        let crypto = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        modelContext.insert(crypto)

        viewModel.saveSyncConfig(for: crypto, url: "ethereum", defaultPrice: 2900)

        XCTAssertEqual(viewModel.state.syncConfigs.count, 1)
        XCTAssertEqual(crypto.coingeckoId, "ethereum")
        XCTAssertEqual(viewModel.state.syncConfigs.first?.defaultPrice, 2900)
    }

    func testSyncUpdatesPricesFromCoinGecko() async {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000, coingeckoId: "bitcoin")
        modelContext.insert(crypto)
        viewModel.saveSyncConfig(for: crypto, url: "bitcoin", defaultPrice: 45000)

        mockPriceService.prices = [crypto.id: Decimal(60000)]

        await viewModel.syncPrices()

        XCTAssertEqual(crypto.precio, 60000)
        XCTAssertFalse(viewModel.state.isSyncing)
    }

    func testSyncFallsBackToDefaultPriceWhenNoPriceReturned() async {
        let crypto = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000, coingeckoId: "ethereum")
        modelContext.insert(crypto)
        viewModel.saveSyncConfig(for: crypto, url: "ethereum", defaultPrice: 2500)

        mockPriceService.prices = [:]

        await viewModel.syncPrices()

        XCTAssertEqual(crypto.precio, 2500)
    }
}

final class MockPriceService: PriceService {
    var prices: [UUID: Decimal] = [:]
    var shouldThrow = false

    func fetchPrices(for queries: [PriceQuery]) async throws -> [UUID: Decimal] {
        if shouldThrow { throw URLError(.badServerResponse) }
        return prices
    }
}
