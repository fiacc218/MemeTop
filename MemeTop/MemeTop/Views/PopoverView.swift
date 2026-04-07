import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CoinViewModel
    @ObservedObject var floatingController: FloatingWindowController
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MemeTop")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Button(action: {
                    Task { await viewModel.fetchPrices() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .opacity(viewModel.isLoading ? 0.5 : 1)

                Button(action: { floatingController.toggle() }) {
                    Image(systemName: floatingController.isVisible ? "pip.fill" : "pip")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.showSettings.toggle()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if viewModel.showSettings {
                SettingsView(viewModel: viewModel)
            } else {
                // Coin list
                if viewModel.isLoading && viewModel.coins.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else if let error = viewModel.errorMessage, viewModel.coins.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.fetchPrices() }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    Spacer()
                } else {
                    // Table header
                    HStack(spacing: 0) {
                        Text("COIN")
                        Spacer(minLength: 4)
                        Text("PRICE/MC")
                        Text("24H")
                            .frame(width: 58, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.coins) { coin in
                                CoinRowView(coin: coin)
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let error = viewModel.errorMessage, !viewModel.coins.isEmpty {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("CoinGecko + Binance")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
