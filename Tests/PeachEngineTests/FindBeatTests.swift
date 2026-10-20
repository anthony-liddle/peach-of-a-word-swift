import Testing
@testable import PeachEngine

/// The precedence the haptic follows, and the sound will: the web's `submit`.
@Suite("the one beat a find plays")
struct FindBeatTests {
    @Test("completion wins over the source word")
    func completionOverSource() {
        #expect(findBeat(isSourceWord: true, completesBasket: true) == .completion)
    }

    @Test("completion wins over an ordinary find")
    func completionOverFind() {
        #expect(findBeat(isSourceWord: false, completesBasket: true) == .completion)
    }

    @Test("the source word, when it does not complete the basket")
    func sourceAlone() {
        #expect(findBeat(isSourceWord: true, completesBasket: false) == .sourceWord)
    }

    @Test("an ordinary find, otherwise")
    func ordinaryFind() {
        #expect(findBeat(isSourceWord: false, completesBasket: false) == .find)
    }
}
