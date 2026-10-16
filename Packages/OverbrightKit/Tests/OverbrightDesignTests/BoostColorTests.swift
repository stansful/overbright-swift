// OverbrightDesignTests/BoostColorTests.swift — `BoostColor.warmNSColor` follows the appearance (DESIGN.md §2.1) and its
// dynamic provider, a callback AppKit may run on any thread that resolves a colour, works off the main thread
// (ARCHITECTURE.md §8.1 rule 2, §9.2 rule 9). `NSAppearance(named:)` cannot make a high-contrast appearance (the
// system makes those while Increase Contrast is on), so the four variants are checked on the provider's mapping and the
// resolution off the main thread against the appearance each name really gives.
import AppKit
import Testing
@testable import OverbrightDesign

@Suite struct BoostColorTests {
    /// `name`'s appearance and its resolution of the warm colour, in sRGB components; nil when it does not resolve.
    nonisolated static func resolve(_ name: NSAppearance.Name) -> (expected: SRGBA, resolved: SRGBA?)? {
        guard let appearance = NSAppearance(named: name) else { return nil }
        let expected = BoostColor.warm(matching: appearance.bestMatch(from: BoostColor.appearanceNames))
        var resolved: SRGBA?
        appearance.performAsCurrentDrawingAppearance {
            if let color = BoostColor.warmNSColor.usingColorSpace(.sRGB) {
                resolved = SRGBA(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent,
                                 alpha: color.alphaComponent)
            }
        }
        return (expected, resolved)
    }

    /// Whether this runs on the main thread, and every appearance's resolution.
    nonisolated static func resolveAll() -> (onMain: Bool, results: [(expected: SRGBA, resolved: SRGBA?)?]) {
        (Thread.isMainThread, BoostColor.appearanceNames.map(resolve))
    }

    private func isClose(_ a: SRGBA, _ b: SRGBA) -> Bool {
        abs(a.red - b.red) < 0.01 && abs(a.green - b.green) < 0.01 && abs(a.blue - b.blue) < 0.01
    }

    /// The provider's mapping: #B35F00 / #FFB020, Increase Contrast #8F4A00 / #FFC65C (DESIGN.md §2.1).
    @Test func theWarmColourFollowsTheAppearance() {
        #expect(BoostColor.warm(matching: .aqua) == SRGBA(hex: 0xB35F00))
        #expect(BoostColor.warm(matching: .darkAqua) == SRGBA(hex: 0xFFB020))
        #expect(BoostColor.warm(matching: .accessibilityHighContrastAqua) == SRGBA(hex: 0x8F4A00))
        #expect(BoostColor.warm(matching: .accessibilityHighContrastDarkAqua) == SRGBA(hex: 0xFFC65C))
        #expect(BoostColor.warm(matching: nil) == SRGBA(hex: 0xB35F00), "no match is light")
    }

    @Test func theWarmColourResolvesOffTheMainThread() async throws {
        let all = await Task.detached { Self.resolveAll() }.value
        #expect(!all.onMain, "resolved on a background thread")
        for (name, result) in zip(BoostColor.appearanceNames, all.results) {
            let (expected, resolved) = try #require(result, "\(name.rawValue)")
            let color = try #require(resolved, "\(name.rawValue)")
            #expect(isClose(color, expected), "\(name.rawValue): \(color) vs \(expected)")
        }
        let light = try #require(all.results.first??.resolved), dark = try #require(all.results[1]?.resolved)
        #expect(isClose(light, SRGBA(hex: 0xB35F00)) && isClose(dark, SRGBA(hex: 0xFFB020)))
    }

    @Test func manyThreadsResolveItAtOnce() async {
        let names = BoostColor.appearanceNames
        let results = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<16 {
                group.addTask {
                    guard let result = Self.resolve(names[index % names.count]), let color = result.resolved else {
                        return false
                    }
                    return abs(color.red - result.expected.red) < 0.01 && abs(color.blue - result.expected.blue) < 0.01
                }
            }
            var all: [Bool] = []
            for await result in group { all.append(result) }
            return all
        }
        #expect(results.count == 16 && results.allSatisfy { $0 })
    }
}
