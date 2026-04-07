import SwiftUI

@main
struct MemeTopApp: App {
    @StateObject private var viewModel = CoinViewModel()
    @StateObject private var floatingController = FloatingWindowController()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel, floatingController: floatingController)
                .frame(width: 240, height: 360)
                .onAppear {
                    floatingController.setup(viewModel: viewModel)
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
