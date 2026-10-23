import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The two licence texts the app carries for Soundscape, its sound library.
///
/// **They are the package's own files, byte for byte, at the version the app
/// pins:** 0.2.1, revision `2ccda18`. `LICENSE` is the MIT licence; and
/// `LICENSE-CHROMIUM` holds the seven notices for the parts that follow
/// Chromium's design (Chromium's own, four of Google's, Intel's, and Sun's for
/// fdlibm). The BSD-style ones ask that a binary reproduce them, which is why
/// they ship inside `Data/` rather than staying in the repository.
///
/// A hash rather than a comparison with the package, because this runs on
/// Xcode Cloud's test phase, which has no checkout and no package sources to
/// compare with. The `test` workflow job does compare them, with `cmp`,
/// against the checkout it resolved; that is what fails if the package moves
/// and these do not. The hashes are `git show 0.2.1:LICENSE | shasum -a 256`
/// and the same for `LICENSE-CHROMIUM`, in the Soundscape repository.
@Suite("Soundscape's licences in the bundle")
struct SoundscapeLicenceTests {
    static func sha256(_ name: String) throws -> String {
        let data = try Data(contentsOf: dataDirectory.appendingPathComponent(name))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @Test("carry the package's MIT licence as it is at 0.2.1")
    func mit() throws {
        #expect(try Self.sha256("Soundscape-LICENSE.txt")
            == "c910f918f2dd8c89b6ce939486e0204f34bc278f4634811127fae45c1fd80970")
    }

    @Test("carry the package's seven notices as they are at 0.2.1")
    func chromium() throws {
        #expect(try Self.sha256("Soundscape-LICENSE-CHROMIUM.txt")
            == "34a83e8c83f4bfd313d95ee8be763ffad9d2f3f1fe3eec3190b4c3b191f48956")
    }
}
