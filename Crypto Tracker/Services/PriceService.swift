import Foundation

// MARK: - Protocol

protocol PriceServiceProtocol {
    func fetchPrice(from urlString: String) async throws -> Double
    func fetchPrices(from urlStrings: [String]) async throws -> [String: Double]
}

// MARK: - Implementation

actor PriceService: PriceServiceProtocol {
    private struct CachedPrice {
        let value: Double
        let date: Date
    }

    private let urlSession: URLSession
    private let minimumRequestInterval: TimeInterval
    private let cacheValidityInterval: TimeInterval
    private let maxRetries: Int

    private var lastRequestDate: Date?
    private var priceCache: [String: CachedPrice] = [:]

    init(
        timeoutInterval: TimeInterval = 30,
        minimumRequestInterval: TimeInterval = 0.5,
        cacheValidityInterval: TimeInterval = 60,
        maxRetries: Int = 1
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.urlSession = URLSession(configuration: configuration)
        self.minimumRequestInterval = minimumRequestInterval
        self.cacheValidityInterval = cacheValidityInterval
        self.maxRetries = maxRetries
    }

    func fetchPrice(from urlString: String) async throws -> Double {
        if let cached = priceCache[urlString], isCacheValid(cached.date) {
            return cached.value
        }

        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                await enforceRateLimit()
                let price = try await performRequest(from: urlString)
                priceCache[urlString] = CachedPrice(value: price, date: Date())
                return price
            } catch {
                lastError = error
                if attempt < maxRetries, isRetryable(error) {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    throw error
                }
            }
        }
        throw lastError ?? URLError(.badServerResponse)
    }

    func fetchPrices(from urlStrings: [String]) async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        for urlString in urlStrings {
            prices[urlString] = try await fetchPrice(from: urlString)
        }
        return prices
    }

    private func performRequest(from urlString: String) async throws -> Double {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(PriceResponse.self, from: data).price
    }

    private func enforceRateLimit() async {
        guard let lastRequestDate else { return }
        let elapsed = Date().timeIntervalSince(lastRequestDate)
        let remaining = minimumRequestInterval - elapsed
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }

    private func isCacheValid(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < cacheValidityInterval
    }

    private func isRetryable(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
