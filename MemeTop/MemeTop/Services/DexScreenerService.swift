import Foundation

actor DexScreenerService {
    private let baseURL = "https://api.dexscreener.com/latest/dex/tokens"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func fetchPrice(contract: String) async throws -> Coin {
        let urlString = "\(baseURL)/\(contract)"
        guard let url = URL(string: urlString) else {
            throw CoinError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CoinError.invalidResponse
        }

        let result = try JSONDecoder().decode(DexScreenerResponse.self, from: data)

        guard let pair = result.pairs?.first else {
            throw CoinError.noPairFound
        }

        return pair.toCoin(contract: contract)
    }

    func fetchPrices(contracts: [String]) async -> [Coin] {
        await withTaskGroup(of: Coin?.self) { group in
            for contract in contracts {
                group.addTask {
                    try? await self.fetchPrice(contract: contract)
                }
            }
            var coins: [Coin] = []
            for await coin in group {
                if let coin { coins.append(coin) }
            }
            return coins
        }
    }
}

struct DexScreenerResponse: Codable {
    let pairs: [DexPair]?
}

struct DexPair: Codable {
    let baseToken: DexToken
    let priceUsd: String?
    let marketCap: Double?
    let fdv: Double?
    let liquidity: DexLiquidity?
    let volume: DexVolume?
    let priceChange: DexPriceChange?

    struct DexToken: Codable {
        let address: String
        let name: String
        let symbol: String
    }

    struct DexLiquidity: Codable {
        let usd: Double?
    }

    struct DexVolume: Codable {
        let h24: Double?
    }

    struct DexPriceChange: Codable {
        let h1: Double?
        let h6: Double?
        let h24: Double?
    }

    func toCoin(contract: String) -> Coin {
        let price = Double(priceUsd ?? "0") ?? 0
        return Coin(
            id: contract.lowercased(),
            symbol: baseToken.symbol.uppercased(),
            name: baseToken.name,
            currentPrice: price,
            priceChangePercentage24h: priceChange?.h24 ?? 0,
            priceChangeH1: priceChange?.h1,
            priceChangeH6: priceChange?.h6,
            marketCap: marketCap ?? fdv,
            liquidity: liquidity?.usd,
            volume24h: volume?.h24,
            source: .dexscreener
        )
    }
}
