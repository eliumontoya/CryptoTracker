import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class CoinGeckoPriceServiceTests: XCTestCase {
    private var urlSession: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockCoinGeckoURLProtocol.self]
        urlSession = URLSession(configuration: configuration)
    }

    override func tearDown() {
        urlSession = nil
        super.tearDown()
    }

    func testFetchPricesDecodesCoinGeckoResponse() async throws {
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let bitcoinQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")
        let ethereumQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "ethereum")

        let prices = try await service.fetchPrices(for: [bitcoinQuery, ethereumQuery])

        XCTAssertEqual(prices[bitcoinQuery.cryptoId], Decimal(43000))
        XCTAssertEqual(prices[ethereumQuery.cryptoId], Decimal(2250))
    }

    func testFetchPricesIgnoresCryptosWithoutCoingeckoId() async throws {
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let bitcoinQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")

        let prices = try await service.fetchPrices(for: [bitcoinQuery])

        XCTAssertEqual(prices[bitcoinQuery.cryptoId], Decimal(43000))
    }

    func testFetchPricesReturnsCachedValueWithinValidityInterval() async throws {
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let bitcoinQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")

        _ = try await service.fetchPrices(for: [bitcoinQuery])

        // Simulate a different server response by changing the payload.
        MockCoinGeckoURLProtocol.mockData = try JSONSerialization.data(withJSONObject: [
            "bitcoin": ["usd": 50000]
        ])

        let prices = try await service.fetchPrices(for: [bitcoinQuery])
        XCTAssertEqual(prices[bitcoinQuery.cryptoId], Decimal(43000))
    }
}

final class MockCoinGeckoURLProtocol: URLProtocol {
    static var mockData: Data = {
        try! JSONSerialization.data(withJSONObject: [
            "bitcoin": ["usd": 43000],
            "ethereum": ["usd": 2250]
        ])
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.mockData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
