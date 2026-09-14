import Foundation
@testable import UcapHutang

@MainActor
final class FakeContactsProvider: ContactsProviding {
    var currentAccess: ContactsAccess
    var accessAfterRequest: ContactsAccess
    var allContacts: [ContactRef]
    private(set) var requestAccessCallCount = 0

    init(
        access: ContactsAccess = .authorized,
        accessAfterRequest: ContactsAccess = .authorized,
        contacts: [ContactRef] = []
    ) {
        self.currentAccess = access
        self.accessAfterRequest = accessAfterRequest
        self.allContacts = contacts
    }

    func access() async -> ContactsAccess {
        currentAccess
    }

    func requestAccess() async -> ContactsAccess {
        requestAccessCallCount += 1
        if currentAccess == .notDetermined {
            currentAccess = accessAfterRequest
        }
        return currentAccess
    }

    func search(name: String) async -> [ContactRef] {
        guard currentAccess == .authorized else { return [] }
        let sorted = allContacts.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }

    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] {
        guard currentAccess == .authorized else { return [] }
        return allContacts.filter { ids.contains($0.identifier) }
    }
}
