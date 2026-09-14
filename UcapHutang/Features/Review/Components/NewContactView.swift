import SwiftUI
import Contacts
import ContactsUI

/// The system "New Contact" form, prefilled with a name. Calls `onComplete` with the saved contact, or `nil` when cancelled.
struct NewContactView: UIViewControllerRepresentable {
    let suggestedName: String
    let onComplete: (ContactRef?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        let components = PersonNameComponentsFormatter().personNameComponents(from: suggestedName)
        contact.givenName = components?.givenName ?? suggestedName
        contact.middleName = components?.middleName ?? ""
        contact.familyName = components?.familyName ?? ""

        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: (ContactRef?) -> Void

        init(onComplete: @escaping (ContactRef?) -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            guard let contact else {
                onComplete(nil)
                return
            }
            let formatted = CNContactFormatter.string(from: contact, style: .fullName)
                ?? "\(contact.givenName) \(contact.familyName)"
            onComplete(ContactRef(
                identifier: contact.identifier,
                displayName: formatted.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: contact.phoneNumbers.first?.value.stringValue
            ))
        }
    }
}
