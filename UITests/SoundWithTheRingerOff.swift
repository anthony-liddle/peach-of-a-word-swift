import XCTest

/// The game's sounds play with the ringer off, and over other apps' audio,
/// which keeps playing: the session the app sets is `.playback` with
/// `.mixWithOthers`. A simulator has no Ring/Silent switch and plays no
/// podcast, so this holds the session to what the switch and the podcast
/// obey. `-exposeSession 1` shows the app's session after each cue it asks
/// for. The device check in Bea's Ears is where both are heard.
final class SoundWithTheRingerOff: XCTestCase {
    func testTheSessionPlaysWithTheRingerOffAndMixesWithOtherAudio() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-exposeSession", "1"]
        app.launch()
        let shuffle = app.buttons["Shuffle"]
        XCTAssertTrue(shuffle.waitForExistence(timeout: 30), "no Shuffle button")
        let probe = app.staticTexts["DebugSession"]
        XCTAssertTrue(probe.waitForExistence(timeout: 30), "the app never exposed its session")

        // The cues render after launch, and the player sets the session as it
        // builds its engine, so Shuffle is pressed until the session is set,
        // or for 30 seconds
        let wanted = "playback, mixWithOthers"
        let deadline = Date().addingTimeInterval(30)
        repeat {
            shuffle.tap()
        } while probe.label != wanted && Date() < deadline
        XCTAssertEqual(probe.label, wanted,
                       "the session should play with the ringer off and mix with other apps' audio")
    }
}
