import Testing
import PeachEngine

/// The flag's words, as the wording pass has them with Antoine's lines (21,
/// 22 and 23 November), and as the web's `src/flags/model.ts` says them.
///
/// The app has only the cute theme, so a basket word is "a basket word".
@Suite("the flag's words")
struct FlagCopyTests {
    @Test func namesTheCardsFlagWithAHintForVoiceOver() {
        #expect(FlagCopy.flagLabel == "Flag this word")
        #expect(FlagCopy.flagHint == "Report a problem with this word")
    }

    @Test func titlesThePickerWithTheWordAndNoQuestionMark() {
        #expect(FlagCopy.pickerTitle("zorp") == "Flag “zorp”")
    }

    @Test func headsEachGroup() {
        #expect(FlagCopy.heading(.takeItOut) == "Take it out")
        #expect(FlagCopy.heading(.fixItsCard) == "Fix its card")
        #expect(FlagCopy.heading(.itsGrade) == "Its grade")
    }

    @Test func saysEachChoiceAsTheWordingPassHasIt() {
        #expect(FlagCopy.choice(.notAWord, card: .definition, grade: .set) == "It's not a real word")
        #expect(FlagCopy.choice(.offensive, card: .peach, grade: nil) == "It's offensive")
        #expect(FlagCopy.choice(.definition, card: .definition, grade: .set) == "The definition is wrong")
        #expect(FlagCopy.choice(.definition, card: .noDefinition, grade: .set) == "It needs a definition")
        #expect(FlagCopy.choice(.definition, card: .peach, grade: nil) == "The definition or origin is wrong")
    }

    @Test func namesTheGradeAsTheGameShowsIt() {
        #expect(FlagCopy.choice(.rarer, card: .definition, grade: .set) == "It's rarer than a basket word")
        #expect(FlagCopy.choice(.rarer, card: .definition, grade: .uncommon) == "It's rarer than Uncommon")
        #expect(FlagCopy.choice(.rarer, card: .definition, grade: .rare) == "It's rarer than Rare")
        #expect(FlagCopy.choice(.moreCommon, card: .definition, grade: .uncommon) == "It's more common than Uncommon")
        #expect(FlagCopy.choice(.moreCommon, card: .definition, grade: .rare) == "It's more common than Rare")
        #expect(FlagCopy.choice(.moreCommon, card: .definition, grade: .mythic) == "It's more common than Mythic")
    }

    @Test func saysWhatAFlagSendsAndThatNothingAboutThePlayerGoes() {
        #expect(FlagCopy.pickerNote == "Sends the word, its day and your reason. Nothing about you.")
        #expect(FlagCopy.cancel == "Cancel")
    }

    @Test func hasAShortFormForEachReason() {
        #expect(FlagReason.allCases.map(FlagCopy.shortForm) == [
            "not a real word", "offensive", "its definition", "suggested", "rarer", "more common",
        ])
    }

    @Test func saysWhatWasFlaggedOnTheCardAndWhetherItWent() {
        #expect(FlagCopy.cardLine([.notAWord], waiting: false)
            == "You flagged this: not a real word. Sent.")
        #expect(FlagCopy.cardLine([.offensive, .rarer], waiting: true)
            == "You flagged this: offensive, rarer. Waiting to send.")
        #expect(FlagCopy.yourFlags == "Your flags")
    }

    @Test func saysFlaggedThenTheStateToVoiceOver() {
        #expect(FlagCopy.spoken(sent: true) == "Flagged. Sent.")
        #expect(FlagCopy.spoken(sent: false) == "Flagged. Waiting to send.")
    }

    @Test func wordsYourFlags() {
        #expect(FlagCopy.state(.sent) == "Sent")
        #expect(FlagCopy.state(.waiting) == "Waiting to send")
        #expect(FlagCopy.row(word: "zorp", reason: .definition) == "zorp, its definition")
        #expect(FlagCopy.takeBack == "Take back")
        #expect(FlagCopy.listNote
            == "Flags send right away, or once you're back online. You can take one back for 60 days.")
        #expect(FlagCopy.full == "50 flags are waiting to send. They'll go once you're online.")
    }

    @Test func neverNamesAnyoneInTheGamesOwnScreens() {
        let all = [
            FlagCopy.flagLabel, FlagCopy.flagHint, FlagCopy.pickerTitle("zorp"), FlagCopy.pickerNote,
            FlagCopy.cardLine([.notAWord], waiting: true), FlagCopy.listNote, FlagCopy.full,
        ] + FlagReason.allCases.map { FlagCopy.choice($0, card: .definition, grade: .uncommon) }
        for line in all {
            #expect(!line.contains("Antoine"), "\(line)")
        }
    }
}
