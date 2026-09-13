import Foundation

/// A streak handed over from the web build, as parsed from a `peachofaword://`
/// link. Nothing here is trusted; see `GameStorage.adoptStreak`.
///
/// **This is a disposable path.** It exists to move one person's streak from
/// the web game to this app once. It is not a feature, there is no UI for
/// producing a link inside the app, and the page that produces one is meant to
/// be deleted afterwards. Kept small and separate so removing it later is one
/// file, one plist entry, and one handler.
///
/// **The parameters are unauthenticated on purpose.** Anyone can type any
/// number into the URL. There is no leaderboard, no server, and nobody to
/// cheat: the only person this can lie to is the person typing. Signing the
/// payload would mean a shared secret and a verifier in two codebases to
/// protect a number one player is moving to herself.
///
/// That reasoning expires under one specific condition, which is why it is
/// written here rather than left to be discovered: if scores ever become
/// comparable between players, through a leaderboard, a shared board, or any
/// cross-player comparison, this becomes an unauthenticated writer to a value
/// that then matters. Remove it or sign it before that ships.
public struct StreakTransfer: Equatable {
    public let count: Int
    public let lastClearedDayIndex: Int

    /// The only shape this reads. A link without it, or with any other value,
    /// is refused rather than read for the fields it happens to recognise: a
    /// later format could reuse these names for something else, and reading two
    /// fields out of a message you do not understand is how a streak gets set
    /// from a number that meant something different.
    private static let supportedVersion = "1"

    private static let scheme = "peachofaword"
    private static let host = "streak"

    public init?(url: URL) {
        // `URLComponents` rather than hand-splitting: it does the percent
        // decoding and gives the query back as parsed items, so a value
        // containing an escaped `&` cannot smuggle in a second parameter.
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == Self.scheme,
              parts.host?.lowercased() == Self.host,
              let items = parts.queryItems
        else { return nil }

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        // Whole numbers only. `Int(_:)` refuses "53.5", "fifty" and "239abc"
        // outright, where a scanning parse would read a prefix and discard the
        // rest, turning a mangled link into a plausible-looking streak.
        guard value("v") == Self.supportedVersion,
              let count = value("count").flatMap(Int.init),
              let lastCleared = value("lastCleared").flatMap(Int.init)
        else { return nil }

        self.count = count
        self.lastClearedDayIndex = lastCleared
    }
}
