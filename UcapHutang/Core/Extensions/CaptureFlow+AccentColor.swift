import SwiftUI

/// The color that identifies each capture flow throughout Catat: the chooser tile,
/// the recording screen's listening state, and the sonar ping.
///
/// Kept out of `Domain/Models/TransactionModels.swift` because Domain stays free of
/// SwiftUI imports in this project — this is the one Core-layer companion to that enum.
extension CaptureFlow {
    var accentColor: Color {
        switch self {
        case .personal: AppColors.accent
        case .splitBill: AppColors.split
        }
    }
}
