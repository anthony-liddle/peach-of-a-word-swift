/// Whether past boards can be played.
///
/// **A seam, deliberately placed before it is needed.** The archive is free
/// today and may be gated later. Routing every entry point through one check
/// means that gate is an implementation swapped in at `GameModel.init` rather
/// than an audit of every place a past day can be tapped, and it means the
/// denying case is testable now instead of after StoreKit exists.
///
/// Two rules the implementations must keep. **Today is never gated**: this
/// governs past days only, and the live daily is the free game. And **reading is
/// not playing**: the calendar and its badges are hers either way, because the
/// history is a record of what she did, not a feature she is being sold.
protocol ArchiveAccess {
    var canPlayArchive: Bool { get }
}

/// The archive, free. What ships today.
struct FreeArchive: ArchiveAccess {
    var canPlayArchive: Bool { true }
}
