/// A whole number passed at launch as `-name value`.
///
/// **Foundation's argument domain cannot carry a negative.** It reads
/// `-name value` pairs into `UserDefaults`, and drops a pair whose value begins
/// with "-": `-dayOffset -26` sets nothing at all, so `integer(forKey:)` reads
/// 0 and the app quietly behaves as if no argument had been passed. This reads
/// the arguments themselves, so a negative arrives as a negative.
///
/// The last occurrence wins, as it does in the argument domain. A name with no
/// value after it, or a value that is not a whole number, is nil.
public func launchInteger(_ name: String, in arguments: [String]) -> Int? {
    let flag = "-" + name
    var found: Int?
    for (index, argument) in arguments.enumerated()
    where argument == flag && index + 1 < arguments.count {
        found = Int(arguments[index + 1])
    }
    return found
}
