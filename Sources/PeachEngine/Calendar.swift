/// Fixed seed for the one-time establishment shuffle and for ordering appended
/// words. A constant so generation is fully deterministic across runs.
public let calendarSeed: UInt32 = 0x5e1e_c7ed

/// Build the daily calendar from the current eligible source words and the
/// existing committed calendar.
///
/// APPEND-ONLY INVARIANT (load-bearing, do not break):
///   The daily calendar is append-only. Never reorder it, never remove from it.
///   New words go on the end. Removing or reordering an entry re-dates every
///   day after it and breaks the promise that a given day is a fixed puzzle.
///
/// First run (existing empty): every eligible word in a deterministic seeded
/// shuffle, so consecutive days do not march alphabetically. Every later run:
/// existing entries keep their position and order untouched, and any eligible
/// word not already present is appended to the end in a deterministic order.
public func generateCalendar(
    eligible: [String],
    existing: [String],
    seed: UInt32 = calendarSeed
) -> [String] {
    let present = Set(existing)
    // Sort for a stable base so the seeded shuffle is independent of input order.
    let sorted = eligible.sorted()
    let shuffled = seededPermutation(sorted.count, seed: seed).map { sorted[$0] }
    return existing + shuffled.filter { !present.contains($0) }
}
