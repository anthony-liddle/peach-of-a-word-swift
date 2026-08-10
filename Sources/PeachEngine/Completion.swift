/// True once every set word the rack can spell has been found.
///
/// Completion is a WORD COUNT, not a points threshold, and it sits ABOVE the
/// named ladder: a player can hold the top named rank (0.80 of par) with set
/// words still unfound, and only this returns true when the page is clear.
///
/// This function does not exist in the TypeScript engine. There, the same rule
/// is inlined at two UI call sites:
///
///   - `src/ui/share/shareResult.ts:56`
///       `tier.setTotal > 0 && tier.setFound >= tier.setTotal`
///   - `src/ui/useGame.ts:602`
///       `setFound + (rung === 'set' ? 1 : 0) >= setTotal`   // no > 0 guard
///
/// They agree today solely because `minSetSize = 15` makes an empty set
/// impossible, an invariant enforced in a third file entirely. One function,
/// one rule, one test.
public func isComplete(_ standing: TierStanding) -> Bool {
    standing.setTotal > 0 && standing.setFound >= standing.setTotal
}
