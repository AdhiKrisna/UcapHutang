import Foundation

/// A person picked from the iPhone Contacts app.
struct ContactRef: Hashable, Sendable {
    let identifier: String
    let displayName: String
    let phoneNumber: String?
}

/// Contacts permission as the app treats it. Limited and restricted access count as `.denied`.
enum ContactsAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
