import Foundation
import SwiftUI
import Combine
import Network

@MainActor
class CoinViewModel: ObservableObject, BinanceWebSocketDelegate {
    @Published var coins: [Coin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [WatchlistItem] = []
    @Published var isSearching = false
    @Published var showSettings = false
    @Published var lastUpdated: Date?

    var isDataStale: Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 60
    }

    @AppStorage("refreshInterval") var refreshInterval: Double = 30
    @AppStorage("menuBarCoinId") var menuBarCoinId: String = "ethereum"
    @AppStorage("menuBarCount") var menuBarCount: Int = 3
    @AppStorage("proxyMode") var proxyMode: ProxyMode = .system
    @AppStorage("proxyHost") var proxyHost: String = ""
    @AppStorage("proxyPort") var proxyPort: Int = 0

    @Published var currentMenuBarIndex: Int = 0

    private let geckoService = CoinGeckoService()
    private let dexService = DexScreenerService()
    private let wsService = BinanceWebSocketService()
    private var refreshTimer: Timer?
    private var scrollTimer: Timer?
    private var searchTask: Task<Void, Never>?
    private var geckoBackoffUntil: Date?
    private let networkMonitor = NWPathMonitor()
    private nonisolated(unsafe) var lastPathStatus: NWPath.Status?

    // Binance symbol -> CoinGecko id
    private let binanceToGeckoId: [String: String] = [
        "btcusdt": "bitcoin",
        "ethusdt": "ethereum",
        "solusdt": "solana",
        "dogeusdt": "dogecoin",
        "pepeusdt": "pepe",
        "shibusdt": "shiba-inu",
        "taousdt": "bittensor",
        "chzusdt": "chiliz",
        "aktusdt": "akash-network",
    ]

    var watchlist: [WatchlistItem] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchlist"),
                  let items = try? JSONDecoder().decode([WatchlistItem].self, from: data) else {
                return Self.loadWatchlistFromFile() ?? defaultWatchlist
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "watchlist")
            }
            objectWillChange.send()
        }
    }

    /// Load watchlist from ~/watchlist.json or project-relative watchlist.json
    private static func loadWatchlistFromFile() -> [WatchlistItem]? {
        let paths = [
            NSHomeDirectory() + "/.memetop/watchlist.json",
            NSHomeDirectory() + "/watchlist.json",
        ]
        struct FileConfig: Codable {
            let watchlist: [FileItem]
            struct FileItem: Codable {
                let id: String
                let symbol: String
                let name: String
                let contract: String?
                let chain: String?
                let notes: String?
                let source: String
            }
        }
        for path in paths {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let config = try? JSONDecoder().decode(FileConfig.self, from: data) else {
                continue
            }
            return config.watchlist.map {
                WatchlistItem(
                    id: $0.id, symbol: $0.symbol, name: $0.name,
                    contract: $0.contract, chain: $0.chain, notes: $0.notes,
                    source: $0.source == "dexscreener" ? .dexscreener : .coingecko
                )
            }
        }
        return nil
    }

    var menuBarText: String {
        guard !coins.isEmpty else { return "MemeTop" }
        let index = currentMenuBarIndex % coins.count
        return formatMenuBar(coins[index])
    }

    private func formatMenuBar(_ coin: Coin) -> String {
        let arrow = coin.isUp ? "\u{25B2}" : "\u{25BC}"
        let value = coin.source == .dexscreener ? (coin.mcFormatted ?? coin.priceFormatted) : coin.priceFormatted
        return "\(coin.symbol) \(value) \(arrow)\(String(format: "%.1f%%", abs(coin.priceChangePercentage24h)))"
    }

    init() {
        wsService.delegate = self
        Task { await applyProxy() }
        startRefreshing()
        startScrolling()

        // Refresh when waking from sleep
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.geckoBackoffUntil = nil
            self.startRefreshing()
        }

        // Refresh when network connectivity recovers
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let previous = self.lastPathStatus
            self.lastPathStatus = path.status
            // Only trigger refresh when transitioning to satisfied
            if path.status == .satisfied && previous != .satisfied {
                Task { @MainActor in
                    self.geckoBackoffUntil = nil
                    self.errorMessage = nil
                    self.startRefreshing()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "net.memetop.monitor"))
    }

    func startScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard !self.coins.isEmpty else { return }
                self.currentMenuBarIndex = (self.currentMenuBarIndex + 1) % self.coins.count
            }
        }
    }

    func applyProxy() async {
        await geckoService.updateProxy(
            mode: proxyMode,
            host: proxyHost.isEmpty ? nil : proxyHost,
            port: proxyPort > 0 ? proxyPort : nil
        )
    }

    func startRefreshing() {
        refreshTimer?.invalidate()

        Task { await fetchPrices() }

        // Connect WebSocket for CoinGecko coins
        let geckoIds = watchlist.filter { $0.source == .coingecko }.map(\.id)
        wsService.connect(coinIds: geckoIds)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchPrices()
            }
        }
    }

    func forceRefresh() async {
        geckoBackoffUntil = nil
        errorMessage = nil
        await fetchPrices()
    }

    func fetchPrices() async {
        let list = watchlist
        guard !list.isEmpty else {
            coins = []
            return
        }

        if coins.isEmpty { isLoading = true }
        errorMessage = nil

        let geckoItems = list.filter { $0.source == .coingecko }
        let dexItems = list.filter { $0.source == .dexscreener }

        let oldCoins = coins

        // Fetch both sources concurrently
        async let geckoCoins = fetchGeckoCoins(ids: geckoItems.map(\.id))
        async let dexCoins = fetchDexCoins(contracts: dexItems.compactMap(\.contract))

        let allGecko = await geckoCoins
        let allDex = await dexCoins

        // Merge and preserve watchlist order
        var merged: [Coin] = []
        for item in list {
            if item.source == .coingecko {
                if let coin = allGecko.first(where: { $0.id == item.id }) {
                    merged.append(coin)
                }
            } else {
                if let contract = item.contract,
                   let coin = allDex.first(where: { $0.id == contract.lowercased() }) {
                    merged.append(coin)
                }
            }
        }

        if !merged.isEmpty {
            coins = merged
            if merged != oldCoins {
                lastUpdated = Date()
            }
        }
        // Always stop loading - show error state if no data
        if coins.isEmpty && errorMessage == nil {
            errorMessage = "Unable to fetch data. Check your network."
        }
        isLoading = false
    }

    private func fetchGeckoCoins(ids: [String]) async -> [Coin] {
        guard !ids.isEmpty else { return [] }
        // Auto-clear expired backoff
        if let backoff = geckoBackoffUntil {
            if Date() >= backoff {
                geckoBackoffUntil = nil
            } else {
                let remaining = Int(backoff.timeIntervalSinceNow)
                errorMessage = "CoinGecko: rate limited, retry in \(remaining)s"
                return coins.filter { $0.source == .coingecko }
            }
        }
        do {
            let result = try await geckoService.fetchPrices(ids: ids)
            geckoBackoffUntil = nil
            return result
        } catch let error as CoinError where error == .rateLimited {
            geckoBackoffUntil = Date().addingTimeInterval(60)
            errorMessage = "CoinGecko: rate limited, retry in 60s"
            return coins.filter { $0.source == .coingecko }
        } catch {
            errorMessage = "CoinGecko: \(error.localizedDescription)"
            return []
        }
    }

    private func fetchDexCoins(contracts: [String]) async -> [Coin] {
        guard !contracts.isEmpty else { return [] }
        return await dexService.fetchPrices(contracts: contracts)
    }

    func addToWatchlist(_ item: WatchlistItem) {
        var list = watchlist
        guard !list.contains(where: { $0.id == item.id }) else { return }
        list.append(item)
        watchlist = list
        startRefreshing()
    }

    func removeFromWatchlist(_ item: WatchlistItem) {
        var list = watchlist
        list.removeAll { $0.id == item.id }
        watchlist = list
        coins.removeAll { $0.id == item.id }
        startRefreshing()
    }

    func moveWatchlistItem(from source: IndexSet, to destination: Int) {
        var list = watchlist
        list.move(fromOffsets: source, toOffset: destination)
        watchlist = list
        let ids = list.map(\.id)
        coins.sort { a, b in
            (ids.firstIndex(of: a.id) ?? 0) < (ids.firstIndex(of: b.id) ?? 0)
        }
    }

    func addDexToken(contract: String, chain: String = "Base") {
        let cleaned = contract.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        guard !watchlist.contains(where: { $0.contract?.lowercased() == cleaned }) else { return }

        // Fetch info from DexScreener first
        Task {
            do {
                let coin = try await dexService.fetchPrice(contract: cleaned)
                let item = WatchlistItem(
                    id: cleaned,
                    symbol: coin.symbol,
                    name: coin.name,
                    contract: cleaned,
                    chain: chain,
                    notes: nil,
                    source: .dexscreener
                )
                addToWatchlist(item)
            } catch {
                errorMessage = "Failed to find token: \(error.localizedDescription)"
            }
        }
    }

    func searchCoins(query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let results = try await geckoService.searchCoins(query: query)
                if !Task.isCancelled {
                    searchResults = results.filter { item in
                        !watchlist.contains(where: { $0.id == item.id })
                    }
                    isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    isSearching = false
                }
            }
        }
    }

    func updateRefreshInterval(_ interval: Double) {
        refreshInterval = interval
        startRefreshing()
    }

    // MARK: - BinanceWebSocketDelegate

    nonisolated func didReceivePriceUpdate(symbol: String, price: Double, changePercent: Double) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let geckoId = self.binanceToGeckoId[symbol] else { return }
            if let index = self.coins.firstIndex(where: { $0.id == geckoId }) {
                self.coins[index].currentPrice = price
                self.coins[index].priceChangePercentage24h = changePercent
            }
        }
    }
}
