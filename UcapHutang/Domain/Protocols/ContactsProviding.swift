import Foundation

protocol ContactsProviding: Sendable {
    /// Current permission. Async so MainActor-isolated conformers always satisfy the requirement.
    func access() async -> ContactsAccess
    /// Shows the system prompt only when access is not determined; returns the resulting access.
    func requestAccess() async -> ContactsAccess
    /// Contacts whose name matches `name`. A blank `name` returns every contact sorted A–Z.
    /// Returns `[]` unless access is `.authorized`.
    func search(name: String) async -> [ContactRef]
    /// Contacts for the given identifiers, skipping identifiers that no longer exist.
    /// Returns `[]` unless access is `.authorized`.
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef]
}
