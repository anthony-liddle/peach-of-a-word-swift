import Foundation
import Testing
@testable import PeachEngine

/// Parsing the one-time transfer link.
///
/// The parse is separated from the accept rule and from the URL handler so it
/// can be tested at all: the app target has no unit-test seam here, and a
/// SwiftUI `.onOpenURL` closure is not a testable surface. Everything that can
/// go wrong with an untrusted string goes wrong in these cases instead.
@Suite("StreakTransfer link parsing")
struct StreakTransferTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test("a well-formed link parses")
    func parsesWellFormed() {
        let t = StreakTransfer(url: url("peachofaword://streak?count=53&lastCleared=239&v=1"))
        #expect(t?.count == 53)
        #expect(t?.lastClearedDayIndex == 239)
    }

    @Test("parameter order does not matter")
    func orderIndependent() {
        let t = StreakTransfer(url: url("peachofaword://streak?v=1&lastCleared=239&count=53"))
        #expect(t?.count == 53)
    }

    @Test("extra parameters are ignored")
    func extrasIgnored() {
        let t = StreakTransfer(url: url("peachofaword://streak?count=53&lastCleared=239&v=1&from=web"))
        #expect(t?.count == 53)
    }

    /// The version is required rather than defaulted. If a later format ever
    /// ships, a v=1 reader must refuse it rather than read two of its fields
    /// and guess at the rest.
    @Test(arguments: [
        "peachofaword://streak?count=53&lastCleared=239",       // no version
        "peachofaword://streak?count=53&lastCleared=239&v=2",   // a version we do not know
        "peachofaword://streak?count=53&lastCleared=239&v=one",
    ])
    func rejectsWrongVersion(link: String) {
        #expect(StreakTransfer(url: url(link)) == nil)
    }

    @Test(arguments: [
        "peachofaword://elsewhere?count=53&lastCleared=239&v=1",  // wrong host
        "peachofaword://?count=53&lastCleared=239&v=1",           // no host
        "https://peachofaword.com/streak?count=53&lastCleared=239&v=1", // wrong scheme
        "peachofaword://streak?count=53&v=1",                     // no lastCleared
        "peachofaword://streak?lastCleared=239&v=1",              // no count
        "peachofaword://streak?count=&lastCleared=239&v=1",       // empty count
        "peachofaword://streak?count=fifty&lastCleared=239&v=1",  // not a number
        "peachofaword://streak?count=53.5&lastCleared=239&v=1",   // not an integer
        "peachofaword://streak?count=53&lastCleared=239abc&v=1",  // trailing junk
        "peachofaword://streak",                                  // nothing at all
    ])
    func rejectsMalformed(link: String) {
        #expect(StreakTransfer(url: url(link)) == nil)
    }

    /// The scheme is matched case-insensitively because that is what the RFC
    /// says a scheme is, and iOS will hand over whatever the page typed.
    @Test("the scheme is case-insensitive, as schemes are")
    func schemeCaseInsensitive() {
        #expect(StreakTransfer(url: url("PeachOfAWord://streak?count=53&lastCleared=239&v=1")) != nil)
    }

    /// Values the parser passes through untouched. Nothing here is trusted:
    /// range and liveness are `GameStorage.adoptStreak`'s job, and splitting it
    /// that way is what lets the accept rule be tested without a URL and the
    /// parse be tested without a store.
    @Test("out-of-range values parse and are left for the accept rule")
    func rangeIsNotTheParsersJob() {
        let t = StreakTransfer(url: url("peachofaword://streak?count=-5&lastCleared=99999&v=1"))
        #expect(t?.count == -5)
        #expect(t?.lastClearedDayIndex == 99999)
    }
}
