import SwiftUI

@main
struct UcapHutangApp: App {
    @State private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
    }
}
