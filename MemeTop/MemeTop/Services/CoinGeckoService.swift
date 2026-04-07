import Foundation

actor CoinGeckoService {
    private let baseURL = "https://api.coingecko.com/api/v3"
    private var session: URLSession

    init() {
        self.session = CoinGeckoService.makeSession(proxyMode: .system, host: nil, port: nil)
    }

    func updateProxy(mode: ProxyMode, host: String?, port: Int?) {
        self.session = CoinGeckoService.makeSession(proxyMode: mode, host: host, port: port)
    }

    private static func makeSession(proxyMode: ProxyMode, host: String?, port: Int?) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true

        switch proxyMode {
        case .system:
            // URLSessionConfiguration.default already uses system proxy
            break
        case .custom:
            if let host, let port, !host.isEmpty, port > 0 {
                config.connectionProxyDictionary = [
                    kCFNetworkProxiesHTTPEnable: true,
                    kCFNetworkProxiesHTTPProxy: host,
                    kCFNetworkProxiesHTTPPort: port,
                    kCFNetworkProxiesHTTPSEnable: true,
                    kCFNetworkProxiesHTTPSProxy: host,
                    kCFNetworkProxiesHTTPSPort: port,
                ]
            }
        case .none:
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: false,
                kCFNetworkProxiesHTTPSEnable: false,
            ]
        }

        return URLSession(configuration: config)
    }

    func fetchPrices(ids: [String]) async throws -> [Coin] {
        guard !ids.isEmpty else { return [] }
        let idsParam = ids.joined(separator: ",")
        let urlString = "\(baseURL)/coins/markets?vs_currency=usd&ids=\(idsParam)&order=market_cap_desc&sparkline=false&price_change_percentage=24h"

        guard let url = URL(string: urlString) else {
            throw CoinError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoinError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw CoinError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw CoinError.httpError(httpResponse.statusCode)
        }

        let results = try JSONDecoder().decode([CoinGeckoResponse].self, from: data)
        return results.map { $0.toCoin() }
    }

    func searchCoins(query: String) async throws -> [WatchlistItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search?query=\(encoded)"

        guard let url = URL(string: urlString) else {
            throw CoinError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        struct SearchResponse: Codable {
            struct CoinResult: Codable {
                let id: String
                let symbol: String
                let name: String
            }
            let coins: [CoinResult]
        }

        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        return result.coins.prefix(20).map {
            WatchlistItem(id: $0.id, symbol: $0.symbol.uppercased(), name: $0.name,
                          contract: nil, chain: nil, notes: nil, source: .coingecko)
        }
    }
}

enum ProxyMode: String, CaseIterable, Codable {
    case system = "System"
    case custom = "Custom"
    case none = "None"
}

enum CoinError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case rateLimited
    case httpError(Int)
    case noPairFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .rateLimited: return "Rate limited, please wait"
        case .httpError(let code): return "HTTP error: \(code)"
        case .noPairFound: return "No trading pair found"
        }
    }
}
