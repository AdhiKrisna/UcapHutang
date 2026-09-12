import SwiftUI

@main
struct UcapHutangApp: App {
    @StateObject private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
    }
}
