import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer

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
        .environmentObject(AppContainer.makeDefault())
}
