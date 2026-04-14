import SwiftUI
import AppKit

// Custom draggable view that bypasses system window tiling
class DraggableHostingView: NSHostingView<FloatingTickerView> {
    private var dragOrigin: NSPoint?
    private var windowOrigin: NSPoint?
    private var didDrag = false
    weak var controller: FloatingWindowController?

    override func mouseDown(with event: NSEvent) {
        dragOrigin = NSEvent.mouseLocation
        windowOrigin = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let windowOrigin, let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragOrigin.x
        let dy = current.y - dragOrigin.y
        if abs(dx) > 3 || abs(dy) > 3 {
            didDrag = true
        }
        window.setFrameOrigin(NSPoint(x: windowOrigin.x + dx, y: windowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            controller?.snapToEdge()
        } else {
            // Click — toggle price/change
            controller?.toggleShowPrice()
        }
        dragOrigin = nil
        windowOrigin = nil
        didDrag = false
    }
}

class FloatingWindowController: NSObject, ObservableObject {
    @Published var isVisible = false
    @Published var showPrice = false
    @AppStorage("floatingEnabled") private var floatingEnabled = true
    private var panel: NSPanel?
    private var viewModel: CoinViewModel?
    private var toggleTimer: Timer?

    func setup(viewModel: CoinViewModel) {
        self.viewModel = viewModel
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
        floatingEnabled = isVisible
    }

    func toggleShowPrice() {
        showPrice.toggle()
        updateSize()
        // Reset auto timer so it doesn't switch immediately after manual tap
        startToggleTimer()
    }

    func restoreIfNeeded() {
        if floatingEnabled {
            show()
        }
    }

    func show() {
        guard let viewModel else { return }

        if panel == nil {
            let content = FloatingTickerView(viewModel: viewModel, controller: self)
            let hostingView = DraggableHostingView(rootView: content)
            hostingView.controller = self

            let savedX = UserDefaults.standard.double(forKey: "floatingX")
            let savedY = UserDefaults.standard.double(forKey: "floatingY")
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let x = savedX != 0 ? savedX : screen.maxX - 120
            let y = savedY != 0 ? savedY : screen.midY

            let panel = NSPanel(
                contentRect: NSRect(x: x, y: y, width: 130, height: 0),
                styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = false  // We handle dragging ourselves
            panel.contentView = hostingView
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden

            self.panel = panel
        }

        updateSize()
        panel?.orderFront(nil)
        isVisible = true
        startToggleTimer()
    }

    private func startToggleTimer() {
        toggleTimer?.invalidate()
        toggleTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.showPrice.toggle()
            self.updateSize()
        }
    }

    func updateSize() {
        guard let panel, let hostingView = panel.contentView as? DraggableHostingView else { return }
        let size = hostingView.fittingSize
        let width = max(size.width, 130)
        let height = max(size.height, 20)
        let newSize = NSSize(width: width, height: height)
        hostingView.setFrameSize(newSize)
        // Keep top-left pinned when resizing
        var frame = panel.frame
        let dy = newSize.height - frame.height
        frame.origin.y -= dy
        frame.size = newSize
        panel.setFrame(frame, display: true)
    }

    func hide() {
        savePosition()
        toggleTimer?.invalidate()
        toggleTimer = nil
        panel?.orderOut(nil)
        isVisible = false
    }

    func savePosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(frame.origin.x, forKey: "floatingX")
        UserDefaults.standard.set(frame.origin.y, forKey: "floatingY")
    }

    func snapToEdge() {
        guard let panel else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = panel.frame
        let margin: CGFloat = 2
        let snapThreshold: CGFloat = 40  // Only snap when within 40px of edge

        let distLeft = frame.minX - screen.minX
        let distRight = screen.maxX - frame.maxX

        // Only snap X if close to an edge
        if distLeft < snapThreshold {
            frame.origin.x = screen.minX + margin
        } else if distRight < snapThreshold {
            frame.origin.x = screen.maxX - frame.width - margin
        }
        // Otherwise keep where user placed it

        // Clamp Y within screen
        if frame.minY < screen.minY {
            frame.origin.y = screen.minY + margin
        }
        if frame.maxY > screen.maxY {
            frame.origin.y = screen.maxY - frame.height - margin
        }

        panel.setFrame(frame, display: true, animate: true)
        savePosition()
    }
}

struct FloatingTickerView: View {
    @ObservedObject var viewModel: CoinViewModel
    @ObservedObject var controller: FloatingWindowController

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Stale data warning bar
            if viewModel.isDataStale {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                    Text("STALE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.8))
            }

            ForEach(viewModel.coins) { coin in
                let stale = viewModel.isDataStale
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(stale ? Color.gray : (coin.isUp ? Theme.floatUp : Theme.floatDown))
                        .frame(width: 2)
                    Text(coin.symbol)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(stale ? .gray : .primary)
                        .padding(.leading, 3)
                    Spacer()
                    if controller.showPrice {
                        Text(coin.source == .dexscreener ? (coin.mcFormatted ?? "-") : coin.priceFormatted)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(stale ? .gray : .primary)
                    } else {
                        Text(coin.changeFormatted)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(stale ? .gray : (coin.isUp ? Theme.floatUp : Theme.floatDown))
                    }
                }
                .frame(height: 18)
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
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(isHovering ? 1.0 : 0.9)
        .onHover { isHovering = $0 }
        .onChange(of: viewModel.coins.count) { _ in
            controller.updateSize()
        }
    }
}
