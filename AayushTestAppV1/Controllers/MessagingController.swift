import UIKit
import MessageUI

/// Controller for presenting the native iOS message composition interface.
///
/// **Purpose**: Provides a clean way to present `MFMessageComposeViewController` for
/// sending messages. Handles the delegate callbacks and error cases.
///
/// **Architecture**: Singleton pattern for convenience, though dependency injection
/// would be preferred in a larger codebase. Conforms to `MFMessageComposeViewControllerDelegate`
/// to handle message composition results.
///
/// **Usage**: Called from SwiftUI views via UIKit interop to present the native
/// Messages composer with pre-filled recipient and body.
final class MessagingController: NSObject, MFMessageComposeViewControllerDelegate {
    /// Shared singleton instance.
    static let shared = MessagingController()
    
    /// Private initializer to enforce singleton pattern.
    private override init() {}
    
    /// Presents the native iOS message composer.
    ///
    /// - Parameters:
    ///   - presentingVC: The view controller to present from (typically the root or topmost VC)
    ///   - recipient: Phone number or email of the recipient
    ///   - body: Pre-filled message body
    ///
    /// **Note**: Checks if device can send messages before presenting. Shows an alert
    /// if Messages is not available (e.g., on iPad without cellular).
    func presentMessageComposer(
        from presentingVC: UIViewController,
        to recipient: String,
        body: String
    ) {
        guard MFMessageComposeViewController.canSendText() else {
            let alert = UIAlertController(
                title: "Cannot send message",
                message: "Messages is not available on this device.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presentingVC.present(alert, animated: true)
            return
        }
        
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = [recipient]
        composer.body = body
        presentingVC.present(composer, animated: true)
    }
    
    // MARK: - MFMessageComposeViewControllerDelegate
    
    /// Called when the message composer finishes (sent, cancelled, or failed).
    ///
    /// - Parameters:
    ///   - controller: The message compose view controller
    ///   - result: The result of the composition (sent, cancelled, failed)
    ///
    /// **Note**: Currently just dismisses the controller. Could be extended to:
    /// - Show success/error messages
    /// - Log analytics
    /// - Update UI state
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}
