// OverbrightTriggersTests/TaggedColorTests.swift — EDR colours (macOS 26+): the tag round trip, T1's 1.01 clamp,
// components above 1.0 surviving our builders, and the `NSColor` 8-bit wrap that is why they start from `CGColor`.
// ARCHITECTURE.md §4.7 ("EDR colours start from CGColor", "T1 tag precision"), §10.5. Off screen: colours and layers
// are built in memory; no window exists.
import AppKit
import CoreGraphics
import Foundation
import OverbrightCore
import QuartzCore
import Testing
@testable import OverbrightTriggers

@Suite(.enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26, "tagged colours need macOS 26"))
struct TaggedColorTests {
    @Test(arguments: [1.01, 1.6, 4, 16])
    func tagAndComponentsRoundTrip(tag: Double) throws {
        guard #available(macOS 26.0, *) else { return }
        for value in [0.0, 1.0, 1.6] {
            let color = try #require(TaggedColor.cgColor(value: value, headroom: tag))
            #expect(abs(Double(color.contentHeadroom) - tag) < 1e-3, "tag \(tag) value \(value)")
            #expect(color.components?.map(Double.init) == [value, value, value, 1])
            #expect(color.colorSpace?.name == CGColorSpace.extendedLinearSRGB)
        }
    }

    @Test func t1RaisesEveryTagToAtLeast1_01() throws {
        #expect(TaggedLayerTrigger.effectiveTag(1.0) == 1.01)
        #expect(TaggedLayerTrigger.effectiveTag(1.0001) == 1.01)
        #expect(TaggedLayerTrigger.effectiveTag(0.5) == 1.01)
        #expect(TaggedLayerTrigger.effectiveTag(.nan) == 1.01)
        #expect(TaggedLayerTrigger.effectiveTag(2.5) == 2.5)
        guard #available(macOS 26.0, *) else { return }
        // A tag of 1.0 would not request EDR; the layer T1 builds carries the clamped tag.
        let layer = try TaggedLayerTrigger.makeLayer(pixel: .black, headroomTag: 1.0, allowsLegacyPath: false)
        let tag = Double(try #require(layer.backgroundColor).contentHeadroom)
        #expect(abs(tag - 1.01) < 1e-3)
        #expect(tag > 1.0)
    }

    @Test func t1LayerIsHighDynamicRangeWithATaggedColour() throws {
        guard #available(macOS 26.0, *) else { return }
        let black = try TaggedLayerTrigger.makeLayer(pixel: .black, headroomTag: 16, allowsLegacyPath: false)
        #expect(black.preferredDynamicRange == .high)
        #expect(black.backgroundColor?.contentHeadroom == 16)
        #expect(black.backgroundColor?.components?.prefix(3).allSatisfy { $0 == 0 } == true)
        #expect(black.contentsHeadroom == 0)
        let bright = try TaggedLayerTrigger.makeLayer(pixel: .bright, headroomTag: 16, allowsLegacyPath: false)
        #expect(bright.backgroundColor?.components?.first == 1.6)
    }

    @Test func componentsAboveOneSurviveTheAppKitBuilder() throws {
        guard #available(macOS 26.0, *) else { return }
        let color = try #require(TaggedColor.nsColor(value: 1.6, headroom: 16))
        #expect(color.cgColor.components?.first == 1.6)
        #expect(color.cgColor.contentHeadroom == 16)
        let black = try #require(TaggedColor.nsColor(value: 0, headroom: 16))
        #expect(black.cgColor.contentHeadroom == 16)
        #expect(black.cgColor.components?.prefix(3).allSatisfy { $0 == 0 } == true)
    }

    /// The regression that made "EDR colours start from CGColor" a rule: AppKit's component-array initialiser keeps
    /// 8-bit components and wraps 1.6 to 152/255. If this starts failing, AppKit changed; the rule can then be
    /// revisited (the lint test keeps the initialiser out of Sources either way).
    @Test func appKitComponentInitialiserWrapsValuesAboveOne() throws {
        guard #available(macOS 26.0, *) else { return }
        var components: [CGFloat] = [1.6, 1.6, 1.6, 1]
        let wrapped = NSColor(colorSpace: .extendedSRGB, components: &components, count: 4)
        let stored = Double(try #require(wrapped.cgColor.components?.first))
        #expect(abs(stored - 152.0 / 255.0) < 0.01, "stored \(stored)")
        let ours = try #require(TaggedColor.nsColor(value: 1.6, headroom: 1.6))
        #expect(Double(try #require(ours.cgColor.components?.first)) == 1.6)
    }

    @Test func untaggedColourCarriesNoTag() throws {
        guard #available(macOS 26.0, *) else { return }
        let dim = try #require(TaggedColor.untaggedCGColor(value: 0.7))
        #expect(dim.contentHeadroom == 0)
        #expect(dim.components?.map(Double.init) == [0.7, 0.7, 0.7, 1])
    }

    @Test func componentsAreFiniteAndNonNegative() {
        #expect(TaggedColor.clampedComponent(-0.5) == 0)
        #expect(TaggedColor.clampedComponent(.nan) == 0)
        #expect(TaggedColor.clampedComponent(.infinity) == 0)
        #expect(TaggedColor.clampedComponent(2.5) == 2.5)
        #expect(TaggedColor.edrTag(.infinity) == 1.01)
    }
}
