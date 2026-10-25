import Foundation
import Testing
@testable import PeachEngine

/// Portrait only on an iPhone; any way up on an iPad.
///
/// The app is iPhone only, and App Review often runs iPhone apps on an iPad.
/// There iPadOS 27 gives it a phone-shaped window, and with portrait as its one
/// orientation, turning the iPad to landscape drew the board sideways inside
/// that window, squeezed into its width: half of four tiles, and nothing else
/// of the rack. Found walking a fresh Release install on an iPad Pro 13-inch
/// Simulator, 24 October 2026. With every orientation allowed on an iPad, the
/// window stays upright and the layout is the phone's.
///
/// Read from `App/Info.plist`, which XcodeGen writes from `project.yml` and the
/// repository keeps: the source tree first, then the test bundle's copy, as
/// `AppVocabularyTests` reads `App/`.
@Suite("orientations")
struct OrientationTests {
    /// Each orientation key's list, keyed by its name.
    private static let orientations: [String: [String]] = {
        var candidates = [repositoryRoot.appendingPathComponent("App/Info.plist")]
        for bundle in Bundle.allBundles {
            if let resources = bundle.resourceURL {
                candidates.append(resources.appendingPathComponent("App/Info.plist"))
            }
        }
        for url in candidates {
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                   as? [String: Any] {
                return plist.compactMapValues { $0 as? [String] }
                    .filter { $0.key.hasPrefix("UISupportedInterfaceOrientations") }
            }
        }
        return [:]
    }()

    @Test("an iPhone stays in portrait")
    func iPhone() {
        #expect(Self.orientations["UISupportedInterfaceOrientations"]
                == ["UIInterfaceOrientationPortrait"])
    }

    @Test("an iPad may turn every way, so its window stays upright")
    func iPad() {
        let iPad = Set(Self.orientations["UISupportedInterfaceOrientations~ipad"] ?? [])
        #expect(iPad == [
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
        ])
    }
}
