import SwiftUI

struct ContentView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        if let message = container.storageErrorMessage {
            ContentUnavailableView {
                Label("Penyimpanan Tidak Tersedia", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(message)
            }
            .padding()
        } else {
            RootTabView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppContainer.makeDefault())
}
