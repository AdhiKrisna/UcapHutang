import SwiftUI
import Combine

@MainActor
protocol DraftContactPickerViewModelProtocol: ObservableObject {
    var searchQuery: String { get set }
    var isMultiSelect: Bool { get }
    var totalAmount: Int64 { get set }
    var selectedContacts: [SelectedContactUIModel] { get set }
    var recentContacts: [ContactUIModel] { get }
    var deviceContacts: [ContactUIModel] { get }
    var filteredRecentContacts: [ContactUIModel] { get }
    var filteredDeviceContacts: [ContactUIModel] { get }
    var totalAllocatedAmount: Int64 { get }
    var hasNoResults: Bool { get }

    func toggleSelection(for contact: ContactUIModel)
    func updateCustomAmount(for contactID: String, amount: Int64)
    func createNewContact(name: String) -> ContactUIModel
    func isSelected(contactID: String) -> Bool
}

@MainActor
final class DraftContactPickerViewModel: DraftContactPickerViewModelProtocol {
    @Published var searchQuery: String = ""
    let isMultiSelect: Bool
    @Published var totalAmount: Int64
    @Published var selectedContacts: [SelectedContactUIModel] = []
    @Published private(set) var recentContacts: [ContactUIModel] = []
    @Published private(set) var deviceContacts: [ContactUIModel] = []

    init(
        isMultiSelect: Bool = false,
        totalAmount: Int64 = 300_000,
        initialSelected: [SelectedContactUIModel] = [],
        recentContacts: [ContactUIModel] = DraftMockData.sampleHistoryContacts,
        deviceContacts: [ContactUIModel] = DraftMockData.sampleDeviceContacts
    ) {
        self.isMultiSelect = isMultiSelect
        self.totalAmount = totalAmount
        self.recentContacts = recentContacts
        self.deviceContacts = deviceContacts

        if !initialSelected.isEmpty {
            self.selectedContacts = initialSelected
        } else if isMultiSelect {
            // Mock sample multi-selection for preview if empty
            self.selectedContacts = [
                SelectedContactUIModel(id: "1", name: "Orang A", amount: 100_000),
                SelectedContactUIModel(id: "2", name: "Orang B", amount: 100_000),
                SelectedContactUIModel(id: "3", name: "Orang C", amount: 100_000)
            ]
        }
    }

    var filteredRecentContacts: [ContactUIModel] {
        guard !searchQuery.isEmpty else { return recentContacts }
        return recentContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var filteredDeviceContacts: [ContactUIModel] {
        guard !searchQuery.isEmpty else { return deviceContacts }
        return deviceContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var totalAllocatedAmount: Int64 {
        selectedContacts.reduce(0) { $0 + $1.amount }
    }

    var hasNoResults: Bool {
        !searchQuery.isEmpty && filteredRecentContacts.isEmpty && filteredDeviceContacts.isEmpty
    }

    func isSelected(contactID: String) -> Bool {
        selectedContacts.contains { $0.id == contactID }
    }

    func toggleSelection(for contact: ContactUIModel) {
        if isMultiSelect {
            if let index = selectedContacts.firstIndex(where: { $0.id == contact.id }) {
                selectedContacts.remove(at: index)
            } else {
                selectedContacts.append(SelectedContactUIModel(id: contact.id, name: contact.fullName, amount: 0))
            }
            recalculateEqualSplit()
        } else {
            selectedContacts = [SelectedContactUIModel(id: contact.id, name: contact.fullName, amount: totalAmount)]
        }
    }

    func updateCustomAmount(for contactID: String, amount: Int64) {
        guard let index = selectedContacts.firstIndex(where: { $0.id == contactID }) else { return }
        selectedContacts[index].amount = amount
        selectedContacts[index].isCustomAmount = true
    }

    func createNewContact(name: String) -> ContactUIModel {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newContact = ContactUIModel(id: UUID().uuidString, fullName: clean, phoneNumber: nil, isFromHistory: true)
        recentContacts.insert(newContact, at: 0)
        toggleSelection(for: newContact)
        searchQuery = ""
        return newContact
    }

    private func recalculateEqualSplit() {
        guard !selectedContacts.isEmpty, totalAmount > 0 else { return }
        let uncustomized = selectedContacts.filter { !$0.isCustomAmount }
        let customTotal = selectedContacts.filter { $0.isCustomAmount }.reduce(Int64(0)) { $0 + $1.amount }
        let remaining = max(0, totalAmount - customTotal)

        guard !uncustomized.isEmpty else { return }
        let share = remaining / Int64(uncustomized.count)

        for i in selectedContacts.indices where !selectedContacts[i].isCustomAmount {
            selectedContacts[i].amount = share
        }
    }
}
