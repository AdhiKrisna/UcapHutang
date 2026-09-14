import Foundation
import Contacts

final class SystemContactsProvider: ContactsProviding {
    private let store = CNContactStore()

    func access() async -> ContactsAccess {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async -> ContactsAccess {
        let current = await access()
        guard current == .notDetermined else { return current }
        _ = try? await store.requestAccess(for: .contacts)
        return await access()
    }

    func search(name: String) async -> [ContactRef] {
        guard await access() == .authorized else { return [] }
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .givenName
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            request.predicate = CNContact.predicateForContacts(matchingName: trimmed)
        }
        return enumerate(request)
    }

    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] {
        guard !ids.isEmpty, await access() == .authorized else { return [] }
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .givenName
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        return enumerate(request)
    }

    static func map(_ status: CNAuthorizationStatus) -> ContactsAccess {
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted, .limited:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private static var keysToFetch: [CNKeyDescriptor] {
        [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
    }

    private func enumerate(_ request: CNContactFetchRequest) -> [ContactRef] {
        var results: [ContactRef] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            let name = (CNContactFormatter.string(from: contact, style: .fullName) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            results.append(ContactRef(
                identifier: contact.identifier,
                displayName: name,
                phoneNumber: contact.phoneNumbers.first?.value.stringValue
            ))
        }
        return results
    }
}
