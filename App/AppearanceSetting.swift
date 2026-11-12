import SwiftUI
import UIKit

/// The game's appearance: the phone's, or always light, or always dark.
///
/// **System is the default, and follows the phone,** including when the phone
/// switches on its own at sunset. Light and Dark hold the game there whatever
/// the phone does. Chosen in Settings (Antoine, 11 November 2026), kept on
/// this phone in `UserDefaults` under `key`.
///
/// **Applied to the windows, not to a view.** `overrideUserInterfaceStyle` on
/// every window reaches whatever they present, so Settings, the cards, the
/// Safari page and the share sheet all follow it, and setting it back to
/// `.unspecified` hands the window back to the phone straight away. A
/// `preferredColorScheme` on a view has to propagate up through SwiftUI's
/// presentations to get there, and a sheet that was already up when it
/// changed could keep the old one.
///
/// **What it can't reach is the launch screen.** iOS draws that before any of
/// the game's code runs, from the `LaunchBackground` colour, which follows the
/// phone. So a phone in light mode with the game set to Dark shows the light
/// launch screen for a moment, about 1.7 seconds on the simulator, before the
/// game turns dark. The reverse, a dark phone set to Light, shows a dark launch
/// screen and then the light game it asked for.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    static let key = "appearance"

    var id: String { rawValue }

    /// The choice as saved, System when nothing is.
    static var current: AppearanceSetting {
        UserDefaults.standard.string(forKey: key).flatMap(AppearanceSetting.init(rawValue:)) ?? .system
    }

    /// Its name in Settings.
    var title: String {
        switch self {
        case .system: Vocabulary.appearanceSystem
        case .light: Vocabulary.appearanceLight
        case .dark: Vocabulary.appearanceDark
        }
    }

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Puts every window the game has in this appearance.
    @MainActor
    static func apply(_ choice: AppearanceSetting = current) {
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows {
                window.overrideUserInterfaceStyle = choice.style
            }
        }
    }
}
