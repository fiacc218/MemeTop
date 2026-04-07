import SwiftUI

struct CoinRowView: View {
    let coin: Coin

    var body: some View {
        HStack(spacing: 0) {
            // Symbol + source
            HStack(spacing: 3) {
                Circle()
                    .fill(coin.isUp ? Theme.up : Theme.down)
                    .frame(width: 5, height: 5)
                Text(coin.symbol)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                if coin.source == .dexscreener {
                    Text("DEX")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.orange)
                }
            }

            Spacer(minLength: 4)

            // DEX coins show MC, others show price
            Text(coin.source == .dexscreener ? (coin.mcFormatted ?? "-") : coin.priceFormatted)
                .font(.system(size: 12, weight: .medium, design: .monospaced))

            // 24h change
            Text(coin.changeFormatted)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(coin.isUp ? Theme.up : Theme.down)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}
