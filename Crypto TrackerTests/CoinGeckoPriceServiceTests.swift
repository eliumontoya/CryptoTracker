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
        MockCoinGeckoURLProtocol.mockData = try! JSONSerialization.data(withJSONObject: [
            "bitcoin": ["usd": 43000],
            "ethereum": ["usd": 2250]
        ])
        MockCoinGeckoURLProtocol.mockStatusCode = 200
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

    func testFetchPricesReturnsEmptyForEmptyQueries() async throws {
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let prices = try await service.fetchPrices(for: [])
        XCTAssertTrue(prices.isEmpty)
    }

    func testFetchPricesThrowsBadServerResponse() async throws {
        MockCoinGeckoURLProtocol.mockStatusCode = 500
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let query = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")

        do {
            _ = try await service.fetchPrices(for: [query])
            XCTFail("Expected error for 500 response")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testFetchPricesIgnoresMissingCoinsInResponse() async throws {
        MockCoinGeckoURLProtocol.mockData = try JSONSerialization.data(withJSONObject: [
            "bitcoin": ["usd": 43000]
        ])
        let service = CoinGeckoPriceService(urlSession: urlSession)
        let bitcoinQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")
        let missingQuery = PriceQuery(cryptoId: UUID(), coingeckoId: "unknown")

        let prices = try await service.fetchPrices(for: [bitcoinQuery, missingQuery])

        XCTAssertEqual(prices[bitcoinQuery.cryptoId], Decimal(43000))
        XCTAssertNil(prices[missingQuery.cryptoId])
    }

    func testFetchPricesUsesInjectedBaseURL() async throws {
        let customBaseURL = URL(string: "https://custom.example.com/price")!
        let service = CoinGeckoPriceService(urlSession: urlSession, baseURL: customBaseURL)
        let query = PriceQuery(cryptoId: UUID(), coingeckoId: "bitcoin")

        let prices = try await service.fetchPrices(for: [query])
        XCTAssertEqual(prices[query.cryptoId], Decimal(43000))
    }
}

final class MockCoinGeckoURLProtocol: URLProtocol {
    static var mockData: Data = {
        try! JSONSerialization.data(withJSONObject: [
            "bitcoin": ["usd": 43000],
            "ethereum": ["usd": 2250]
        ])
    }()
    static var mockStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.mockStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.mockData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
