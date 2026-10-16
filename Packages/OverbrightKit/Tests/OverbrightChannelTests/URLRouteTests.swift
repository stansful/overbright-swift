// OverbrightChannelTests/URLRouteTests.swift — the `overbright://` parser (ARCHITECTURE.md §7.7, D25): `set=off` is
// always accepted, `set=on` only with the app's token (constant-time compare), settings with an optional pane, and
// every malformed URL refused (any web page can try the scheme).
import Foundation
import Testing
@testable import OverbrightChannel

@Suite struct URLRouteTests {
    private let token = String(repeating: "ab", count: 32)

    private func route(_ string: String) throws -> URLRoute? {
        URLRoute.parse(try #require(URL(string: string)))
    }

    @Test func offIsAlwaysAccepted() throws {
        let off = try #require(try route("overbright://control?set=off"))
        #expect(off == .control(on: false, token: nil))
        #expect(off.accepts(token: nil))
        #expect(off.accepts(token: token))
        let withWrongToken = try #require(try route("overbright://control?set=off&token=nonsense"))
        #expect(withWrongToken.accepts(token: token))
    }

    @Test func onNeedsTheAppsToken() throws {
        let bare = try #require(try route("overbright://control?set=on"))
        #expect(bare == .control(on: true, token: nil))
        #expect(!bare.accepts(token: token))
        let right = try #require(try route("overbright://control?set=on&token=\(token)"))
        #expect(right == .control(on: true, token: token))
        #expect(right.accepts(token: token))
        #expect(!right.accepts(token: nil))                              // the app has no token yet
        #expect(!right.accepts(token: ""))
        #expect(!(try #require(try route("overbright://control?token=\(token)&set=on"))).accepts(token: String(token.reversed())))
        #expect(!(try #require(try route("overbright://control?set=on&token=\(token.dropLast())"))).accepts(token: token))
        #expect(!URLRoute.control(on: true, token: token + "00").accepts(token: token))
    }

    @Test func settingsOpenAtAnOptionalPane() throws {
        #expect(try route("overbright://settings") == .settings(pane: nil))
        #expect(try route("overbright://settings/") == .settings(pane: nil))
        #expect(try route("overbright://settings/displays") == .settings(pane: "displays"))
        #expect(try route("overbright://settings/fill-light2") == .settings(pane: "fill-light2"))
        #expect(try route("OVERBRIGHT://Settings/general") == .settings(pane: "general"))
        #expect(try route("overbright://CONTROL?set=off") == .control(on: false, token: nil))
        #expect(URLRoute.settings(pane: "general").accepts(token: nil))
    }

    @Test(arguments: [
        "https://control?set=on",                                  // another scheme
        "overbright:control?set=on",                               // no host
        "overbright://boost?set=on",                               // unknown route
        "overbright://control",                                    // no query
        "overbright://control?set=maybe",
        "overbright://control?set=on&set=off",                     // twice
        "overbright://control?set=on&token=a&token=b",
        "overbright://control?set=on&token=",                      // empty token
        "overbright://control?set=on&level=1000",                  // unknown item
        "overbright://control/extra?set=on",                       // a path
        "overbright://control?set=on#fragment",
        "overbright://user:secret@control?set=on",
        "overbright://control:8080?set=on",
        "overbright://settings?pane=general",                      // settings take no query
        "overbright://settings/general/advanced",                  // one pane at most
        "overbright://settings/General",                           // panes are lowercase
        "overbright://settings/gen%20eral",
        "overbright://settings/1general",
        "overbright://settings/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", // 33 characters
        "overbright://settings#displays",
    ])
    func malformedURLsAreRefused(_ string: String) throws {
        #expect(try route(string) == nil)
    }

    @Test func theURLOfARouteParsesBackToIt() throws {
        let routes: [URLRoute] = [.control(on: true, token: token), .control(on: false, token: nil),
                                  .control(on: false, token: token), .settings(pane: nil), .settings(pane: "advanced")]
        for route in routes {
            let url = try #require(route.url)
            #expect(URLRoute.parse(url) == route, "\(url)")
        }
        #expect(URLRoute.control(on: true, token: token).url?.absoluteString == "overbright://control?set=on&token=\(token)")
    }
}
