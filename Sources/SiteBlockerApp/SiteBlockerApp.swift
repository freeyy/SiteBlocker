import SwiftUI

@main
struct SiteBlockerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("SiteBlocker", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 460)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 820, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
