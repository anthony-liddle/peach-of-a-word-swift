import SafariServices
import SwiftUI

/// A page of the game's own website, in a Safari view inside the app, with
/// Safari's own Done button to come back.
///
/// **Only the game's own site opens here.** The privacy policy is the one page
/// of it the app shows. A link to anywhere else, such as the explainer's
/// ENABLE and SCOWL pages, still hands off to Safari, as a link to another
/// site should.
///
/// **A Safari view is Safari,** running outside the app's process: the app
/// sees neither the page nor its cookies, and loads nothing itself. That is
/// what let the privacy policy's claims about the app's network use stand
/// unchanged when this replaced #84's handoff to Safari, which had been chosen
/// so the app would load no page; checked sentence by sentence against the
/// policy on 22 October 2026.
@MainActor
enum SafariPage {
    /// The policy, as the app opens it. `?from=app` tells the page it is in the
    /// app, where it drops its "Back to the game" link: here that would open the
    /// web game inside the app. The App Store record links the bare address.
    static let privacyPolicy = URL(string: "https://peachofaword.com/privacy?from=app")!

    /// Presents `url` over whatever is on screen, Settings included.
    ///
    /// **Presented by UIKit, from the top of what is presented,** which is how
    /// a Safari view is meant to be shown: its Done dismisses the view itself,
    /// and Settings is where it was. Wrapped in a SwiftUI cover instead, Done
    /// would have a cover to unwind that it knows nothing about.
    static func open(_ url: URL) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow),
              var top = window.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let page = SFSafariViewController(url: url)
        page.dismissButtonStyle = .done
        page.preferredControlTintColor = UIColor(Cute.accentDeep)
        top.present(page, animated: true)
    }
}
