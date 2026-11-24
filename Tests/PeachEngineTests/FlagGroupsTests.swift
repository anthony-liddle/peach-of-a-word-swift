import Testing
@testable import PeachEngine

/// Which reasons the picker offers on a card, in which groups.
///
/// Ported from the web's `src/flags/model.test.ts`, "the picker's groups". The
/// groups' headings and the choices' words are the app's (`FlagCopy`); this is
/// only which reasons each card can take (Antoine, 21 and 23 November).
@Suite("the picker's groups")
struct FlagGroupsTests {
    static let none: Set<FlagReason> = []

    static func reasons(_ groups: [FlagGroup]) -> [[FlagReason]] { groups.map(\.reasons) }
    static func kinds(_ groups: [FlagGroup]) -> [FlagGroup.Kind] { groups.map(\.kind) }
    /// The third group's reasons, the grade's, or nil if there's no third group.
    static func grade(_ groups: [FlagGroup]) -> [FlagReason]? { groups.dropFirst(2).first?.reasons }

    @Test func offersThreeGroupsOnAFoundWord() {
        let groups = flagGroups(card: .definition, grade: .uncommon, flagged: Self.none)
        #expect(Self.kinds(groups) == [.takeItOut, .fixItsCard, .itsGrade])
        #expect(Self.reasons(groups) == [[.notAWord, .offensive], [.definition], [.rarer, .moreCommon]])
    }

    @Test func letsABasketWordBeOnlyRarerAndAMythicWordOnlyMoreCommon() {
        #expect(Self.grade(flagGroups(card: .definition, grade: .set, flagged: Self.none)) == [.rarer])
        #expect(Self.grade(flagGroups(card: .definition, grade: .mythic, flagged: Self.none)) == [.moreCommon])
        #expect(Self.grade(flagGroups(card: .noDefinition, grade: .rare, flagged: Self.none)) == [.rarer, .moreCommon])
    }

    @Test func givesThePeachNoGradeAndNeverCallsItNotAWord() {
        let groups = flagGroups(card: .peach, grade: nil, flagged: Self.none)
        #expect(Self.kinds(groups) == [.takeItOut, .fixItsCard])
        #expect(Self.reasons(groups) == [[.offensive], [.definition]])
    }

    @Test func takesOutAReasonAlreadyFlaggedAndAGroupLeftEmpty() {
        let groups = flagGroups(card: .definition, grade: .set, flagged: [.notAWord, .definition])
        #expect(Self.reasons(groups) == [[.offensive], [.rarer]])
        #expect(Self.kinds(groups) == [.takeItOut, .itsGrade])
    }

    @Test(arguments: [FlagReason.rarer, .moreCommon])
    func takesTheWholeGradeGroupOutOnceEitherGradeReasonIsFlagged(grade: FlagReason) {
        let groups = flagGroups(card: .definition, grade: .rare, flagged: [grade])
        #expect(Self.kinds(groups) == [.takeItOut, .fixItsCard])
        #expect(flagGroups(card: .definition, grade: .rare, flagged: Self.none).count == 3)
    }

    @Test func offersNothingOnceEveryReasonIsUsed() {
        let all = Set(FlagReason.allCases)
        #expect(flagGroups(card: .definition, grade: .uncommon, flagged: all).isEmpty)
        #expect(flagGroups(card: .peach, grade: nil, flagged: [.offensive, .definition]).isEmpty)
    }

    @Test func sendsEachReasonAsTheServerNamesIt() {
        #expect(FlagReason.allCases.map(\.rawValue)
            == ["not-a-word", "offensive", "definition", "should-count", "rarer", "more-common"])
    }
}
