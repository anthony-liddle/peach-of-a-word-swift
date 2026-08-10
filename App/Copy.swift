import Foundation

/// Counted nouns, in one place.
///
/// Written after a find reported "toy, 1 points". The bug was trivial; the
/// reason it existed is that six different strings each did their own
/// pluralising and only some of them remembered. Every counted noun in the app
/// now goes through here, including the ones that cannot currently be one,
/// because "cannot currently be one" is exactly the assumption that rots.
func counted(_ n: Int, _ singular: String, plural: String? = nil) -> String {
    "\(n) \(n == 1 ? singular : (plural ?? singular + "s"))"
}
