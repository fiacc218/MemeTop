import Foundation

protocol BinanceWebSocketDelegate: AnyObject {
    func didReceivePriceUpdate(symbol: String, price: Double, changePercent: Double)
}

class BinanceWebSocketService: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    weak var delegate: BinanceWebSocketDelegate?
    private var subscribedSymbols: Set<String> = []
    private var isConnected = false
    private var reconnectTimer: Timer?

    private let symbolMap: [String: String] = [
        "bitcoin": "btcusdt",
        "ethereum": "ethusdt",
        "solana": "solusdt",
        "dogecoin": "dogeusdt",
        "pepe": "pepeusdt",
        "shiba-inu": "shibusdt",
        "ripple": "xrpusdt",
        "cardano": "adausdt",
        "avalanche-2": "avaxusdt",
        "chainlink": "linkusdt",
        "polkadot": "dotusdt",
        "polygon": "maticusdt",
        "the-open-network": "tonusdt",
        "sui": "suiusdt",
        "bonk": "bonkusdt",
        "floki": "flokiusdt",
        "kaspa": "kasusdt",
    ]

    func connect(coinIds: [String]) {
        disconnect()

        subscribedSymbols = Set(coinIds.compactMap { symbolMap[$0] })
        guard !subscribedSymbols.isEmpty else { return }

        let streams = subscribedSymbols.map { "\($0)@ticker" }.joined(separator: "/")
        let urlString = "wss://stream.binance.com:9443/stream?streams=\(streams)"

        guard let url = URL(string: urlString) else { return }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                default:
                    break
                }
                self.receiveMessage()
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        struct StreamWrapper: Codable {
            let stream: String
            let data: TickerData
        }

        struct TickerData: Codable {
            let s: String  // Symbol
            let c: String  // Close price
            let P: String  // Price change percent
        }

        guard let wrapper = try? JSONDecoder().decode(StreamWrapper.self, from: data),
              let price = Double(wrapper.data.c),
              let changePercent = Double(wrapper.data.P) else {
            return
        }

        let symbol = wrapper.data.s.lowercased()
        delegate?.didReceivePriceUpdate(symbol: symbol, price: price, changePercent: changePercent)
    }

    private func scheduleReconnect() {
        isConnected = false
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self else { return }
            let symbols = Array(self.subscribedSymbols)
            let coinIds = symbols.compactMap { sym in
                self.symbolMap.first(where: { $0.value == sym })?.key
            }
            self.connect(coinIds: coinIds)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        scheduleReconnect()
    }
}
