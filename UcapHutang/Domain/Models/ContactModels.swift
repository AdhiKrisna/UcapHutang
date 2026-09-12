import Foundation

/// A person picked from the iPhone Contacts app.
struct ContactRef: Hashable, Sendable {
    let identifier: String
    let displayName: String
    let phoneNumber: String?
}
