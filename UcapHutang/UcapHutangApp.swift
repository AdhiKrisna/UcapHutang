import SwiftUI

@main
struct UcapHutangApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
                .onAppear {
                    appDelegate.router = container.router
                }
        }
    }
}
