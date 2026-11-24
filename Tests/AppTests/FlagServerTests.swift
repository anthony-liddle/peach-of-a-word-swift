import Foundation
import Testing
import PeachEngine

/// Where a flag goes from the app, and what goes with it.
///
/// **No preview, simulator, Debug build or test ever sends a flag to the live
/// store.** Only a Release build posts to peachofaword.com; this bundle is a
/// Debug build, so it's the place to hold that: if `FlagServer.endpoint` were
/// ever set in Debug, every UI test that flags a word would send it.
@Suite("where a flag goes")
struct FlagServerTests {
    @Test func aDebugBuildNeverHasTheLiveServer() {
        #expect(FlagServer.endpoint == nil)
    }

    @Test func aReleaseBuildPostsToTheGamesOwnSiteOnly() {
        #expect(FlagServer.production.absoluteString == "https://peachofaword.com/api/flag")
    }

    @Test func aStandInAnswersAsItsLaunchArgumentSaysAndNothingAnswersWithout() async {
        let post = FlagRequest(method: .post, body: Data("{}".utf8))
        #expect(await FlagServer.standIn("took")(post) == 202)
        #expect(await FlagServer.standIn("refused")(post) == 400)
        #expect(await FlagServer.standIn("busy")(post) == 503)
        #expect(await FlagServer.standIn("off")(post) == 403)
        #expect(await FlagServer.standIn(nil)(post) == nil)
        let delete = FlagRequest(method: .delete, body: Data("{}".utf8))
        #expect(await FlagServer.standIn("took")(delete) == 204)
    }

    @Test func buildsTheRequestTheServerReads() throws {
        let body = Data(#"{"ids":["x"]}"#.utf8)
        let request = FlagServer.urlRequest(FlagRequest(method: .delete, body: body), to: FlagServer.production)
        #expect(request.url == FlagServer.production)
        #expect(request.httpMethod == "DELETE")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody == body)
        #expect(request.timeoutInterval <= 20)
    }

    /// A flag carries nothing about the player, so the request mustn't either:
    /// no cookies either way, and nothing kept on the phone after.
    @Test func sendsNoCookiesAndKeepsNothing() {
        let config = FlagServer.sessionConfiguration
        #expect(config.httpShouldSetCookies == false)
        #expect(config.httpCookieAcceptPolicy == .never)
        #expect(config.urlCache == nil)
        #expect(config.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func sendsTheVersionAndBuildAsTheServerTakesThem() {
        let version = FlagServer.version(short: "1.4", build: "125")
        #expect(version == "1.4 (125)")
        #expect(version.range(of: "^[0-9A-Za-z.() +-]{1,24}$", options: .regularExpression) != nil)
    }
}
