import Foundation

enum AppDeepLink: Equatable {
    case catatChooser

    init?(url: URL) {
        guard url.scheme?.lowercased() == "ucaphutang",
              url.host?.lowercased() == "catat" else {
            return nil
        }
        self = .catatChooser
    }
}
