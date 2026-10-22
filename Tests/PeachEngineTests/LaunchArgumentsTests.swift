import Testing
@testable import PeachEngine

/// `launchInteger` reads `-name value` from the launch arguments, negatives
/// included, which the `UserDefaults` argument domain drops.
@Suite("whole numbers passed at launch")
struct LaunchArgumentsTests {
    let app = "/path/to/PeachOfAWord"

    @Test("a negative arrives as a negative")
    func negative() {
        #expect(launchInteger("dayOffset", in: [app, "-dayOffset", "-26"]) == -26)
    }

    @Test("a positive arrives as it did")
    func positive() {
        #expect(launchInteger("dayOffset", in: [app, "-dayOffset", "3"]) == 3)
    }

    @Test("among other arguments, and the last occurrence wins")
    func amongOthers() {
        let args = [app, "-resetProgress", "1", "-dayOffset", "-2", "-seedBoard", "almost",
                    "-dayOffset", "-26"]
        #expect(launchInteger("dayOffset", in: args) == -26)
    }

    @Test("absent, valueless or not a whole number reads nil")
    func nothing() {
        #expect(launchInteger("dayOffset", in: [app]) == nil)
        #expect(launchInteger("dayOffset", in: [app, "-dayOffset"]) == nil)
        #expect(launchInteger("dayOffset", in: [app, "-dayOffset", "soon"]) == nil)
        #expect(launchInteger("dayOffset", in: [app, "-dayOffset", "1.5"]) == nil)
    }

    @Test("a name is matched whole, not as a prefix")
    func wholeName() {
        #expect(launchInteger("dayOffset", in: [app, "-dayOffsetOnResume", "-1"]) == nil)
        #expect(launchInteger("dayOffsetOnResume", in: [app, "-dayOffsetOnResume", "-1"]) == -1)
    }
}
