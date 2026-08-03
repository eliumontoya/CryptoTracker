import Foundation

// MARK: - Price Query

/// Lightweight, Sendable description of the data needed to fetch a price.
/// Keeps the price-service boundary independent of the SwiftData model.
struct PriceQuery: Sendable {
    let cryptoId: UUID
    let coingeckoId: String
}

// MARK: - Protocol

protocol PriceService: AnyObject {
    func fetchPrices(for queries: [PriceQuery]) async throws -> [UUID: Decimal]
}

// MARK: - CoinGecko Implementation

actor CoinGeckoPriceService: PriceService {
    private struct CachedPrice {
        let price: Decimal
        let date: Date

        func isValid(validity: TimeInterval) -> Bool {
            Date().timeIntervalSince(date) < validity
        }
    }

    private let urlSession: URLSession
    private let baseURL: URL
    private let cacheValidityInterval: TimeInterval
    private let minimumRequestInterval: TimeInterval

    private var cache: [UUID: CachedPrice] = [:]
    private var lastRequestDate: Date?

    init(
        urlSession: URLSession = URLSession.shared,
        baseURL: URL = URL(string: "https://api.coingecko.com/api/v3/simple/price")!,
        cacheValidityInterval: TimeInterval = 30,
        minimumRequestInterval: TimeInterval = 2
    ) {
        self.urlSession = urlSession
        self.baseURL = baseURL
        self.cacheValidityInterval = cacheValidityInterval
        self.minimumRequestInterval = minimumRequestInterval
    }

    func fetchPrices(for queries: [PriceQuery]) async throws -> [UUID: Decimal] {
        guard !queries.isEmpty else { return [:] }

        let requested = queries.map { ($0.cryptoId, $0.coingeckoId) }

        var result: [UUID: Decimal] = [:]
        var missing: [(UUID, String)] = []

        for (cryptoId, coingeckoId) in requested {
            if let cached = cache[cryptoId], cached.isValid(validity: cacheValidityInterval) {
                result[cryptoId] = cached.price
            } else {
                missing.append((cryptoId, coingeckoId))
            }
        }

        guard !missing.isEmpty else { return result }

        let idsParam = missing.map { $0.1 }.joined(separator: ",")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "ids", value: idsParam),
            URLQueryItem(name: "vs_currencies", value: "usd")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        await enforceRateLimit()

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)

        for (cryptoId, coingeckoId) in missing {
            if let price = decoded[coingeckoId]?["usd"] {
                let decimalPrice = Decimal(price)
                result[cryptoId] = decimalPrice
                cache[cryptoId] = CachedPrice(price: decimalPrice, date: Date())
            }
        }

        return result
    }

    private func enforceRateLimit() async {
        guard let lastRequestDate else { return }
        let remaining = minimumRequestInterval - Date().timeIntervalSince(lastRequestDate)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}
