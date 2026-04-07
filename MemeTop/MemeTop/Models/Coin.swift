import Foundation

enum CoinSource: String, Codable {
    case coingecko
    case dexscreener
}

struct Coin: Identifiable, Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    var currentPrice: Double
    var priceChangePercentage24h: Double
    var priceChangeH1: Double?
    var priceChangeH6: Double?
    var marketCap: Double?
    var liquidity: Double?
    var volume24h: Double?
    let source: CoinSource

    var priceFormatted: String {
        if currentPrice >= 1 {
            return String(format: "$%.2f", currentPrice)
        } else if currentPrice >= 0.01 {
            return String(format: "$%.4f", currentPrice)
        } else if currentPrice >= 0.0001 {
            return String(format: "$%.6f", currentPrice)
        } else {
            return String(format: "$%.8f", currentPrice)
        }
    }

    var changeFormatted: String {
        let sign = priceChangePercentage24h >= 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, priceChangePercentage24h)
    }

    var isUp: Bool {
        priceChangePercentage24h >= 0
    }

    var mcFormatted: String? {
        guard let mc = marketCap, mc > 0 else { return nil }
        if mc >= 1_000_000_000 { return String(format: "$%.1fB", mc / 1_000_000_000) }
        if mc >= 1_000_000 { return String(format: "$%.1fM", mc / 1_000_000) }
        return String(format: "$%.0fK", mc / 1_000)
    }
}

struct CoinGeckoResponse: Codable {
    let id: String
    let symbol: String
    let name: String
    let currentPrice: Double
    let priceChangePercentage24h: Double?
    let marketCap: Double?
    let totalVolume: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCap = "market_cap"
        case totalVolume = "total_volume"
    }

    func toCoin() -> Coin {
        Coin(
            id: id,
            symbol: symbol.uppercased(),
            name: name,
            currentPrice: currentPrice,
            priceChangePercentage24h: priceChangePercentage24h ?? 0,
            marketCap: marketCap,
            volume24h: totalVolume,
            source: .coingecko
        )
    }
}

struct WatchlistItem: Codable, Identifiable, Equatable {
    let id: String          // coingecko_id or contract address
    let symbol: String
    let name: String
    let contract: String?   // nil for native / CoinGecko coins
    let chain: String?
    let notes: String?
    let source: CoinSource

    static func == (lhs: WatchlistItem, rhs: WatchlistItem) -> Bool {
        lhs.id == rhs.id
    }
}

let defaultWatchlist: [WatchlistItem] = [
    WatchlistItem(id: "ethereum", symbol: "ETH", name: "Ethereum",
                  contract: nil, chain: "Ethereum", notes: "主要持仓", source: .coingecko),
    WatchlistItem(id: "bittensor", symbol: "TAO", name: "Bittensor",
                  contract: nil, chain: "Bittensor", notes: "Grayscale ETF概念", source: .coingecko),
    WatchlistItem(id: "chiliz", symbol: "CHZ", name: "Chiliz",
                  contract: nil, chain: "Ethereum", notes: "世界杯概念", source: .coingecko),
    WatchlistItem(id: "akash-network", symbol: "AKT", name: "Akash Network",
                  contract: nil, chain: "Cosmos", notes: "去中心化AI算力", source: .coingecko),
    WatchlistItem(id: "virtual-protocol", symbol: "VIRTUAL", name: "Virtuals Protocol",
                  contract: "0x0b3e328455c4059eeb9e3f84b5543f74e24e7e1b", chain: "Base",
                  notes: "AI Agent平台, 网格交易中", source: .coingecko),
    WatchlistItem(id: "0xa601877977340862ca67f816eb079958e5bd0ba3", symbol: "BOTCOIN", name: "Botcoin",
                  contract: "0xa601877977340862ca67f816eb079958e5bd0ba3", chain: "Base",
                  notes: "AI agent meme", source: .dexscreener),
    WatchlistItem(id: "0x5f980dcfc4c0fa3911554cf5ab288ed0eb13dba3", symbol: "GITLAWB", name: "Gitlawb",
                  contract: "0x5f980dcfc4c0fa3911554cf5ab288ed0eb13dba3", chain: "Base",
                  notes: "AI代码协作meme, a16z pmarca关注", source: .dexscreener),
    WatchlistItem(id: "0xf30bf00edd0c22db54c9274b90d2a4c21fc09b07", symbol: "FELIX", name: "Felix",
                  contract: "0xf30bf00edd0c22db54c9274b90d2a4c21fc09b07", chain: "Base",
                  notes: "bankrbot做市", source: .dexscreener),
    WatchlistItem(id: "0xde61878b0b21ce395266c44d4d548d1c72a3eb07", symbol: "SAIRI", name: "Sairi",
                  contract: "0xde61878b0b21ce395266c44d4d548d1c72a3eb07", chain: "Base",
                  notes: "bankrbot做市", source: .dexscreener),
    WatchlistItem(id: "0x4E6c9f48f73E54EE5F3AB7e2992B2d733D0d0b07", symbol: "JUNO", name: "Juno",
                  contract: "0x4E6c9f48f73E54EE5F3AB7e2992B2d733D0d0b07", chain: "Base",
                  notes: "网格交易中", source: .dexscreener),
]
