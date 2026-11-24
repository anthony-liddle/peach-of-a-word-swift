import Foundation
import Testing
import PeachEngine

/// The privacy manifest says what the app collects, and since the flag it
/// collects one thing: the words a player flags (§5 of "Flagging Words From
/// The Cards"). Apple reads the manifest from the bundle, so it has to say the
/// same as the App Store label will:
/// - **Other User Content,** since a flag is something the player chooses to
///   write, not Product Interaction, which reads as analytics;
/// - **not linked:** a flag carries no ID of the player's, and each flag's own
///   random ID can't tie two together;
/// - **not tracking,** for **App Functionality.**
///
/// Nothing else changes: no tracking, no tracking domains, and the
/// `UserDefaults` reason, CA92.1, which also covers the waiting list.
@Suite("the privacy manifest")
struct PrivacyManifestTests {
    /// The source tree first, then the bundled copy of `App/`, as
    /// `AppVocabularyTests` finds the app's sources.
    nonisolated(unsafe) static let manifest: [String: Any] = {
        var candidates = [repositoryRoot.appendingPathComponent("App/PrivacyInfo.xcprivacy")]
        for bundle in Bundle.allBundles {
            if let resources = bundle.resourceURL {
                candidates.append(resources.appendingPathComponent("App/PrivacyInfo.xcprivacy"))
            }
        }
        for url in candidates {
            if let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
               let dict = plist as? [String: Any] {
                return dict
            }
        }
        return [:]
    }()

    @Test func declaresTheFlaggedWordsAsOtherUserContentNotLinkedAndNotTracking() throws {
        let collected = try #require(Self.manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(collected.count == 1)
        let flag = try #require(collected.first)
        #expect(flag["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeOtherUserContent")
        #expect(flag["NSPrivacyCollectedDataTypeLinked"] as? Bool == false)
        #expect(flag["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        #expect(flag["NSPrivacyCollectedDataTypePurposes"] as? [String]
            == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
    }

    @Test func stillTracksNothingAndKeepsItsOneReason() throws {
        #expect(Self.manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((Self.manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        let apis = try #require(Self.manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(apis.count == 1)
        #expect(apis.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(apis.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
