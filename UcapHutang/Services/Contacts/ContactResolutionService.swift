import Foundation
import Contacts

public struct ContactMatchCandidate: Identifiable, Equatable, Sendable {
    public let id: String
    public let fullName: String
    public let phoneNumber: String?
    public let email: String?

    public init(id: String, fullName: String, phoneNumber: String? = nil, email: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.email = email
    }
}

public enum ContactMatchStatus: String, Codable, CaseIterable, Sendable {
    case matched
    case ambiguous
    case unmatched
    case manuallyConfirmed
}

public struct ContactResolutionResult: Equatable, Sendable {
    public let rawName: String
    public let status: ContactMatchStatus
    public let resolvedIdentifier: String?
    public let resolvedDisplayName: String?
    public let candidates: [ContactMatchCandidate]

    public init(
        rawName: String,
        status: ContactMatchStatus,
        resolvedIdentifier: String? = nil,
        resolvedDisplayName: String? = nil,
        candidates: [ContactMatchCandidate] = []
    ) {
        self.rawName = rawName
        self.status = status
        self.resolvedIdentifier = resolvedIdentifier
        self.resolvedDisplayName = resolvedDisplayName
        self.candidates = candidates
    }
}

@MainActor
public final class ContactResolutionService {
    public static let shared = ContactResolutionService()
    private let contactStore = CNContactStore()

    private init() {}

    public func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return (try? await contactStore.requestAccess(for: .contacts)) ?? false
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    public func resolve(rawName: String) async -> ContactResolutionResult {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ContactResolutionResult(rawName: rawName, status: .unmatched)
        }

        guard await requestAccess() else {
            return ContactResolutionResult(rawName: trimmed, status: .unmatched, resolvedDisplayName: trimmed)
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: trimmed)
        guard let contacts = try? contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch) else {
            return ContactResolutionResult(rawName: trimmed, status: .unmatched, resolvedDisplayName: trimmed)
        }

        let candidates = contacts.map { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = contact.emailAddresses.first?.value as String?
            return ContactMatchCandidate(
                id: contact.identifier,
                fullName: name.isEmpty ? trimmed : name,
                phoneNumber: phone,
                email: email
            )
        }

        if candidates.count == 1 {
            let match = candidates[0]
            return ContactResolutionResult(
                rawName: trimmed,
                status: .matched,
                resolvedIdentifier: match.id,
                resolvedDisplayName: match.fullName,
                candidates: candidates
            )
        } else if candidates.count > 1 {
            return ContactResolutionResult(
                rawName: trimmed,
                status: .ambiguous,
                candidates: candidates
            )
        } else {
            return ContactResolutionResult(
                rawName: trimmed,
                status: .unmatched,
                resolvedDisplayName: trimmed
            )
        }
    }

    public func searchContacts(query: String) async -> [ContactMatchCandidate] {
        guard await requestAccess() else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let predicate = trimmed.isEmpty ? CNContact.predicateForContactsInContainer(withIdentifier: contactStore.defaultContainerIdentifier()) : CNContact.predicateForContacts(matchingName: trimmed)

        guard let contacts = try? contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch) else {
            return []
        }

        return contacts.prefix(25).map { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = contact.emailAddresses.first?.value as String?
            return ContactMatchCandidate(
                id: contact.identifier,
                fullName: name,
                phoneNumber: phone,
                email: email
            )
        }
    }
}
