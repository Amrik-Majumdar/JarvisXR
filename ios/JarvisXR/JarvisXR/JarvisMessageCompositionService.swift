import Contacts
import ContactsUI
import Foundation
import MessageUI
import UIKit

enum JarvisMessageAction: String, Equatable {
    case begin
    case readBack
    case changeRecipient
    case cancel
    case openComposer
}

struct JarvisMessageCommandDetails: Equatable {
    let action: JarvisMessageAction
    let recipientHint: String?
    let body: String?
}

enum JarvisMessageCommandParser {
    static func parse(_ normalized: String, raw: String? = nil) -> JarvisMessageCommandDetails? {
        let preservedCommand = commandTextPreservingContent(raw ?? normalized)
        if ["read the message back", "read message back", "repeat the message"].contains(normalized) {
            return JarvisMessageCommandDetails(action: .readBack, recipientHint: nil, body: nil)
        }
        if ["change the recipient", "change recipient", "choose another recipient"].contains(normalized) {
            return JarvisMessageCommandDetails(action: .changeRecipient, recipientHint: nil, body: nil)
        }
        if ["cancel the message", "cancel message", "discard the message", "discard message"].contains(normalized) {
            return JarvisMessageCommandDetails(action: .cancel, recipientHint: nil, body: nil)
        }
        if ["open the message composer", "open message composer", "review the message", "review message"].contains(normalized) {
            return JarvisMessageCommandDetails(action: .openComposer, recipientHint: nil, body: nil)
        }
        if normalized.hasPrefix("message ") {
            let recipient = argument(after: "message ", in: preservedCommand)
            guard !recipient.isEmpty else { return nil }
            return JarvisMessageCommandDetails(action: .begin, recipientHint: recipient, body: nil)
        }
        if normalized.hasPrefix("tell ") {
            let remainder = argument(after: "tell ", in: preservedCommand)
            let parts = remainder.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard let recipient = parts.first.map(String.init), !recipient.isEmpty else { return nil }
            let body = parts.count == 2 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil
            return JarvisMessageCommandDetails(
                action: .begin,
                recipientHint: recipient,
                body: body?.isEmpty == false ? body : nil
            )
        }
        return nil
    }

    private static func argument(after prefix: String, in value: String) -> String {
        String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func commandTextPreservingContent(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["hey jarvis", "okay jarvis", "ok jarvis", "jarvis"] where value.lowercased().hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
            break
        }
        if value.lowercased().hasPrefix("please ") {
            value = String(value.dropFirst("please ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }
}

struct JarvisMessageDraft: Equatable {
    private(set) var recipientDisplayName: String?
    private(set) var recipientAddress: String?
    private(set) var body: String?

    var isReadyForComposer: Bool {
        recipientAddress?.isEmpty == false && body?.isEmpty == false
    }

    mutating func begin(body: String?) {
        recipientDisplayName = nil
        recipientAddress = nil
        self.body = body?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    mutating func selectRecipient(displayName: String, address: String) {
        recipientDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        recipientAddress = address.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    mutating func setBody(_ value: String) {
        body = value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    mutating func clearRecipient() {
        recipientDisplayName = nil
        recipientAddress = nil
    }

    mutating func cancel() {
        self = JarvisMessageDraft()
    }

    var readback: String {
        guard let recipientDisplayName else {
            return "No recipient is selected. Say message followed by a contact name to choose one."
        }
        guard let body else {
            return "The recipient is \(recipientDisplayName). No message body has been provided yet."
        }
        return "Message to \(recipientDisplayName): \(body)"
    }
}

final class JarvisMessageCompositionService: NSObject, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {
    private weak var presenter: UIViewController?
    private let responseHandler: (JarvisResponse) -> Void
    private(set) var draft = JarvisMessageDraft()
    private var recipientHint: String?

    init(presenter: UIViewController, responseHandler: @escaping (JarvisResponse) -> Void) {
        self.presenter = presenter
        self.responseHandler = responseHandler
    }

    func handle(_ details: JarvisMessageCommandDetails) {
        switch details.action {
        case .begin:
            draft.begin(body: details.body)
            recipientHint = details.recipientHint
            presentContactPicker()
        case .readBack:
            respond(draft.readback)
        case .changeRecipient:
            draft.clearRecipient()
            recipientHint = nil
            presentContactPicker()
        case .cancel:
            draft.cancel()
            recipientHint = nil
            respond("Message draft cancelled.")
        case .openComposer:
            presentMessageComposer()
        }
    }

    private func presentContactPicker() {
        guard let presenter, presenter.presentedViewController == nil else {
            respond("Close the current screen, then try choosing a message recipient again.", status: .unavailable)
            return
        }
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        let hint = recipientHint.map { " Select \($0), then choose the phone number to use." } ?? ""
        respond("Choose a contact and phone number in the system contact picker.\(hint)")
        presenter.present(picker, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        guard contactProperty.key == CNContactPhoneNumbersKey,
              let phoneNumber = contactProperty.value as? CNPhoneNumber else {
            respond("That contact property is not a phone number. Choose a phone number to continue.", status: .unavailable)
            return
        }
        let formattedName = CNContactFormatter.string(from: contactProperty.contact, style: .fullName)
        let displayName = formattedName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "selected contact"
        draft.selectRecipient(displayName: displayName, address: phoneNumber.stringValue)
        recipientHint = nil
        if draft.body == nil {
            respond("Recipient selected: \(displayName). Enter or dictate the message body next.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.presentBodyPrompt()
            }
        } else {
            respond("\(draft.readback). Say open the message composer to review and send, read the message back, change the recipient, or cancel the message.")
        }
    }

    private func presentBodyPrompt() {
        guard let presenter, presenter.presentedViewController == nil else {
            respond("Close the current screen, then start the message again to add its body.", status: .unavailable)
            return
        }
        let alert = UIAlertController(
            title: "Message Body",
            message: "Enter or dictate the message. Jarvis will read it back before the system composer can open.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Message"
            field.autocapitalizationType = .sentences
            field.accessibilityLabel = "Message body"
        }
        alert.addAction(UIAlertAction(title: "Cancel Draft", style: .cancel) { [weak self] _ in
            self?.draft.cancel()
            self?.respond("Message draft cancelled.")
        })
        alert.addAction(UIAlertAction(title: "Save Draft", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            self.draft.setBody(alert?.textFields?.first?.text ?? "")
            guard self.draft.body != nil else {
                self.respond("No message body was entered. The draft was not opened in the composer.", status: .confirmationRequired)
                return
            }
            self.respond("\(self.draft.readback). Say open the message composer to review and send, read the message back, change the recipient, or cancel the message.")
        })
        presenter.present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        recipientHint = nil
        respond("Contact selection cancelled. No message was sent.")
    }

    private func presentMessageComposer() {
        guard draft.isReadyForComposer,
              let address = draft.recipientAddress,
              let body = draft.body else {
            respond("The message needs both a selected recipient and a body before the composer can open.", status: .confirmationRequired)
            return
        }
        guard MFMessageComposeViewController.canSendText() else {
            respond("Text messaging is unavailable on this device or is not configured.", status: .unavailable)
            return
        }
        guard let presenter, presenter.presentedViewController == nil else {
            respond("Close the current screen, then ask to open the message composer again.", status: .unavailable)
            return
        }
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = [address]
        composer.body = body
        responseHandler(.ok(
            "Opening the message composer for your review.",
            display: "Opening the system message composer. Sending still requires your action in the composer.",
            shouldSpeak: false
        ))
        presenter.present(composer, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] in
            guard let self else { return }
            switch result {
            case .sent:
                self.draft.cancel()
                self.respond("The system message composer reported that the message was sent.")
            case .cancelled:
                self.respond("The message composer was cancelled. No send was reported.")
            case .failed:
                self.respond("The system message composer reported that sending failed.", status: .error)
            @unknown default:
                self.respond("The message composer closed without a recognized result.", status: .unavailable)
            }
        }
    }

    private func respond(_ text: String, status: JarvisResponseStatus = .ok) {
        responseHandler(JarvisResponse(status: status, spokenResponse: text, displayResponse: text))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
