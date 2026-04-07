import SwiftUI
import AppKit

class FloatingWindowController: NSObject, ObservableObject {
    @Published var isVisible = false
    private var panel: NSPanel?
    private var viewModel: CoinViewModel?

    func setup(viewModel: CoinViewModel) {
        self.viewModel = viewModel
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let viewModel else { return }

        if panel == nil {
            let content = FloatingTickerView(viewModel: viewModel, controller: self)
            let hostingView = NSHostingView(rootView: content)

            let savedX = UserDefaults.standard.double(forKey: "floatingX")
            let savedY = UserDefaults.standard.double(forKey: "floatingY")
            let screen = NSScreen.main?.frame ?? .zero
            let x = savedX != 0 ? savedX : screen.maxX - 180
            let y = savedY != 0 ? savedY : screen.midY

            let panel = NSPanel(
                contentRect: NSRect(x: x, y: y, width: 90, height: 0),
                styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.contentView = hostingView
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden

            // Auto-size height to content
            hostingView.setFrameSize(hostingView.fittingSize)
            panel.setContentSize(hostingView.fittingSize)

            self.panel = panel
        }

        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        savePosition()
        panel?.orderOut(nil)
        isVisible = false
    }

    func savePosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(frame.origin.x, forKey: "floatingX")
        UserDefaults.standard.set(frame.origin.y, forKey: "floatingY")
    }

    func snapToEdge() {
        guard let panel, let screen = panel.screen?.visibleFrame else { return }
        var frame = panel.frame
        let margin: CGFloat = 4

        let distLeft = frame.minX - screen.minX
        let distRight = screen.maxX - frame.maxX
        let distTop = screen.maxY - frame.maxY
        let distBottom = frame.minY - screen.minY

        let minDist = min(distLeft, distRight, distTop, distBottom)

        if minDist == distLeft {
            frame.origin.x = screen.minX + margin
        } else if minDist == distRight {
            frame.origin.x = screen.maxX - frame.width - margin
        }
        if minDist == distTop {
            frame.origin.y = screen.maxY - frame.height - margin
        } else if minDist == distBottom {
            frame.origin.y = screen.minY + margin
        }

        panel.setFrame(frame, display: true, animate: true)
        savePosition()
    }
}

struct FloatingTickerView: View {
    @ObservedObject var viewModel: CoinViewModel
    @ObservedObject var controller: FloatingWindowController

    @State private var isHovering = false
    @State private var showPrice = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.coins) { coin in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(coin.isUp ? Theme.up : Theme.down)
                        .frame(width: 2)
                    Text(coin.symbol)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.leading, 3)
                    Spacer()
                    if showPrice {
                        Text(coin.source == .dexscreener ? (coin.mcFormatted ?? "-") : coin.priceFormatted)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                    } else {
                        Text(coin.changeFormatted)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(coin.isUp ? .green : .red)
                    }
                }
                .frame(height: 14)
                .padding(.trailing, 4)
            }

            if isHovering {
                Button(action: { controller.hide() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 6))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(isHovering ? 1.0 : 0.7)
        .onHover { isHovering = $0 }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showPrice.toggle()
            }
        }
    }
}
