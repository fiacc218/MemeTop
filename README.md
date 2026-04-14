# MemeTop

A lightweight macOS menubar app for tracking cryptocurrency prices in real-time.

Built with **SwiftUI** — native, no Electron, no WebView. ~15MB memory footprint.

## Features

- **Menubar ticker** — cycles through your watchlist, showing price and 24h change
- **Click-to-expand panel** — view all tracked coins with price, market cap, and 24h change
- **Dockable floating window** — always-on-top compact ticker strip, auto-snaps to screen edges, click to toggle between price and change %
- **Dual data sources**
  - [CoinGecko](https://www.coingecko.com/) API for mainstream coins
  - [DexScreener](https://dexscreener.com/) API for DEX tokens (Base, etc.)
  - [Binance](https://www.binance.com/) WebSocket for real-time price updates
- **Customizable watchlist** — search CoinGecko or paste a contract address to add DEX tokens
- **Adjustable refresh interval** — 10s / 30s / 1m / 5m
- **Proxy support** — system proxy, custom proxy, or direct connection

## Requirements

- macOS 13.0+
- Xcode 15.0+ (to build)

## Build & Run

```bash
git clone https://github.com/fiacc218/memetop.git
cd memetop/MemeTop
xcodebuild -project MemeTop.xcodeproj -scheme MemeTop -configuration Release build
```

Or open `MemeTop/MemeTop.xcodeproj` in Xcode and press `Cmd+R`.

The built app will be in `~/Library/Developer/Xcode/DerivedData/MemeTop-*/Build/Products/Release/MemeTop.app`.

## Usage

- **Menubar** — shows one coin at a time, auto-rotates every 3 seconds
- **Click menubar** — opens the price panel
- **Pin icon** — toggles the floating ticker window
- **Gear icon** — opens settings (refresh interval, proxy, watchlist management)
- **Floating window** — drag to reposition; auto-snaps to left/right edge when near; click to toggle price/change display; hover to reveal close button

### Adding DEX tokens

In Settings > Add Token, paste a contract address (e.g. a Base chain token). MemeTop will fetch the token info from DexScreener automatically.

### Custom watchlist config

You can pre-configure your watchlist via a JSON file. MemeTop looks for config files in this order:

1. `~/.memetop/watchlist.json`
2. `~/watchlist.json`

If found on first launch, it overrides the default watchlist. See [`watchlist.example.json`](watchlist.example.json) for the format.

## Data Sources

| Source | Usage | Auth |
|--------|-------|------|
| CoinGecko | Prices, market data, coin search | Free, no API key (rate limited ~30 req/min) |
| DexScreener | DEX token prices, liquidity, market cap | Free, no API key |
| Binance | Real-time WebSocket price stream | Public, no API key |

No server required. All data fetched directly from public APIs.

## License

[MIT](LICENSE)
