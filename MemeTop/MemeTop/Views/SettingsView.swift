import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CoinViewModel
    @State private var searchText = ""
    @State private var contractInput = ""

    private let intervalOptions: [(String, Double)] = [
        ("10s", 10),
        ("30s", 30),
        ("1m", 60),
        ("5m", 300),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Refresh interval + MenuBar display
                settingsSection("General") {
                    HStack {
                        Text("Refresh")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(intervalOptions, id: \.1) { label, value in
                                Button(label) {
                                    viewModel.updateRefreshInterval(value)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(viewModel.refreshInterval == value
                                              ? Color.accentColor.opacity(0.2)
                                              : Color.secondary.opacity(0.1))
                                )
                                .foregroundColor(viewModel.refreshInterval == value
                                                 ? .accentColor : .primary)
                            }
                        }
                    }

                    HStack {
                        Text("MenuBar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $viewModel.menuBarCoinId) {
                            ForEach(viewModel.watchlist) { item in
                                Text("\(item.symbol) - \(item.name)").tag(item.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }

                Divider()

                // Proxy
                settingsSection("Proxy") {
                    HStack {
                        Text("Mode")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $viewModel.proxyMode) {
                            ForEach(ProxyMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                        .onChange(of: viewModel.proxyMode) { _ in
                            Task { await viewModel.applyProxy() }
                        }
                    }

                    if viewModel.proxyMode == .custom {
                        HStack(spacing: 8) {
                            TextField("Host", text: $viewModel.proxyHost)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            TextField("Port", value: $viewModel.proxyPort, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 55)
                                .padding(5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            Button("Apply") {
                                Task { await viewModel.applyProxy() }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.2)))
                            .foregroundColor(.accentColor)
                        }
                    }
                }

                Divider()

                // Add token
                settingsSection("Add Token") {
                    // DEX contract
                    HStack(spacing: 6) {
                        TextField("Contract address (Base)...", text: $contractInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        Button("Add") {
                            viewModel.addDexToken(contract: contractInput)
                            contractInput = ""
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.2)))
                        .foregroundColor(.accentColor)
                    }

                    // CoinGecko search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        TextField("Search CoinGecko...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .onChange(of: searchText) { newValue in
                                viewModel.searchCoins(query: newValue)
                            }
                    }
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.1))
                    )

                    if !searchText.isEmpty {
                        if viewModel.isSearching {
                            HStack {
                                Spacer()
                                ProgressView().scaleEffect(0.6)
                                Spacer()
                            }.padding(.vertical, 2)
                        } else {
                            ForEach(viewModel.searchResults.prefix(8)) { item in
                                HStack {
                                    Text(item.symbol)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(item.name)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        viewModel.addToWatchlist(item)
                                        searchText = ""
                                        viewModel.searchResults = []
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                Divider()

                // Watchlist
                settingsSection("Watchlist") {
                    ForEach(viewModel.watchlist) { item in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(item.symbol)
                                        .font(.system(size: 11, weight: .semibold))
                                    if item.source == .dexscreener {
                                        Text("DEX")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.orange)
                                    }
                                    if let chain = item.chain {
                                        Text(chain)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                if let notes = item.notes {
                                    Text(notes)
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button(action: {
                                viewModel.removeFromWatchlist(item)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
