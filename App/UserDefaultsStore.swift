import Foundation
import PeachEngine

/// `UserDefaults` behind the engine's `KeyValueStore`.
///
/// **Why UserDefaults rather than a file in Documents.** The whole persisted
/// blob is one JSON value holding at most fourteen days. A generous day is
/// around 50 found words averaging 8 characters, so roughly 600 bytes of JSON;
/// fourteen of those plus a streak is under 10 KB. Even a full year kept
/// unpruned would be a few hundred KB. That is comfortably inside what
/// `UserDefaults` is for, and it brings atomic writes, no file coordination, no
/// directory creation, and no partial-write window for free.
///
/// A file in Documents would be the right answer if the history were unbounded
/// or large enough to want streaming, and it is worth revisiting if the found
/// history is ever kept forever rather than pruned to fourteen days. It is not
/// the right answer today, and choosing it now would mean writing crash-safe
/// file replacement by hand for no benefit.
///
/// One consequence worth stating: `UserDefaults` is not encrypted and is
/// included in device backups. Nothing stored here is sensitive (a list of
/// English words and a small integer), so that is fine.
final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    #if TAP_RECORDER
    /// A separate suite for the instrumented diagnostic build.
    ///
    /// The tap recorder is installed over the real app, sharing its bundle
    /// identifier and therefore its `UserDefaults`. Without this, a diagnostic
    /// session plays on the real board, consumes the real day, and writes to
    /// the real streak. Two bad outcomes follow: a completed board leaves
    /// nothing to test with, and a throwaway session can break a streak that
    /// took days to build.
    ///
    /// So the instrumented build gets its own suite. It starts on a fresh
    /// board with no history, and nothing it does is visible to the shipping
    /// app, whose progress and streak sit untouched in the standard suite and
    /// come back the moment a normal build is installed.
    /// `UserDefaults` is documented as thread safe, and this wrapper adds no
    /// mutable state of its own, so the isolation warning is answered rather
    /// than silenced.
    nonisolated(unsafe) static let diagnostic = UserDefaultsStore(
        defaults: UserDefaults(suiteName: "com.anthonyliddle.peachofaword.tapdiag")
            ?? .standard
    )
    #endif

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}
