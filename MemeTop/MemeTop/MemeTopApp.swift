import SwiftUI

@main
struct MemeTopApp: App {
    @StateObject private var viewModel = CoinViewModel()
    @StateObject private var floatingController = FloatingWindowController()
    @State private var didSetup = false

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel, floatingController: floatingController)
                .frame(width: 240, height: 360)
                .onAppear {
                    if !didSetup {
                        didSetup = true
                        floatingController.setup(viewModel: viewModel)
                        // Restore floating window state from last session
                        // First launch: enabled by default
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            floatingController.restoreIfNeeded()
                        }
                    }
                }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.menuBarText)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
