// OverbrightTriggersTests/TriggerGeometryTests.swift — trigger and overlay frames without a screen: corners, the
// notch with global and screen-local auxiliary areas, fallbacks, edge clamping and pixel rounding.
// ARCHITECTURE.md §4.7 (placement), §7.5, §10.5.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightTriggers

@Suite struct TriggerGeometryTests {
    private let builtIn = TriggerTestBed.builtInGeometry
    private let external = TriggerTestBed.externalGeometry

    @Test func topRightCornerIsFlushWithTheTopRightOfTheScreen() {
        let frame = TriggerGeometry.triggerFrame(on: builtIn, placement: .topRightCorner, edgePoints: 1)
        #expect(frame == CGRect(x: 1511, y: 981, width: 1, height: 1))
        let onExternal = TriggerGeometry.triggerFrame(on: external, placement: .topRightCorner, edgePoints: 2)
        #expect(onExternal == CGRect(x: 1512 + 3840 - 2, y: 2158, width: 2, height: 2))
    }

    @Test func topLeftCornerIsFlushWithTheTopLeftOfTheScreen() {
        let frame = TriggerGeometry.triggerFrame(on: external, placement: .topLeftCorner, edgePoints: 1)
        #expect(frame == CGRect(x: 1512, y: 2159, width: 1, height: 1))
    }

    @Test func notchPlacementCentresTheTriggerInTheCameraHousing() {
        // Housing from x 662 to 850: centre 756, minus half the edge, rounded.
        let frame = TriggerGeometry.triggerFrame(on: builtIn, placement: .notch, edgePoints: 1)
        #expect(frame == CGRect(x: 756, y: 981, width: 1, height: 1))
        let wide = TriggerGeometry.triggerFrame(on: builtIn, placement: .notch, edgePoints: 4)
        #expect(wide == CGRect(x: 754, y: 978, width: 4, height: 4))
        #expect(wide.minX > 662 && wide.maxX < 850)
    }

    @Test func notchAreasInScreenLocalCoordinatesAreMovedToGlobalOnes() {
        // A notched built-in that is not the primary screen: AppKit documents global coordinates, but screen-local
        // ones (H-T6) must land in the same place.
        let frame = CGRect(x: -1512, y: 300, width: 1512, height: 982)
        let localLeft = CGRect(x: 0, y: 950, width: 662, height: 32)
        let localRight = CGRect(x: 850, y: 950, width: 662, height: 32)
        let global = ScreenGeometry(frame: frame, auxiliaryTopLeftArea: localLeft.offsetBy(dx: -1512, dy: 300),
                                    auxiliaryTopRightArea: localRight.offsetBy(dx: -1512, dy: 300))
        let local = ScreenGeometry(frame: frame, auxiliaryTopLeftArea: localLeft, auxiliaryTopRightArea: localRight)
        let fromGlobal = TriggerGeometry.triggerFrame(on: global, placement: .notch, edgePoints: 1)
        let fromLocal = TriggerGeometry.triggerFrame(on: local, placement: .notch, edgePoints: 1)
        // Housing from x −850 to −662: centre −756, minus half the edge (−756.5), rounded away from zero.
        #expect(fromGlobal == CGRect(x: -757, y: 1281, width: 1, height: 1))
        #expect(fromLocal == fromGlobal)
        #expect(frame.contains(fromLocal))
    }

    @Test func notchPlacementFallsBackToTheTopRightCornerWithoutAHousing() {
        let corner = TriggerGeometry.triggerFrame(on: external, placement: .topRightCorner, edgePoints: 1)
        #expect(TriggerGeometry.triggerFrame(on: external, placement: .notch, edgePoints: 1) == corner)
        var onlyLeft = builtIn
        onlyLeft.auxiliaryTopRightArea = nil
        #expect(TriggerGeometry.triggerFrame(on: onlyLeft, placement: .notch, edgePoints: 1)
                == CGRect(x: 1511, y: 981, width: 1, height: 1))
        var overlapping = builtIn
        overlapping.auxiliaryTopRightArea = CGRect(x: 600, y: 950, width: 912, height: 32)
        #expect(TriggerGeometry.triggerFrame(on: overlapping, placement: .notch, edgePoints: 1)
                == CGRect(x: 1511, y: 981, width: 1, height: 1))
    }

    @Test func edgesAreClampedToOneThroughSixteenPoints() {
        #expect(TriggerGeometry.clampedEdge(0) == 1)
        #expect(TriggerGeometry.clampedEdge(-3) == 1)
        #expect(TriggerGeometry.clampedEdge(.nan) == 1)
        #expect(TriggerGeometry.clampedEdge(.infinity) == 1)
        #expect(TriggerGeometry.clampedEdge(5) == 5)
        #expect(TriggerGeometry.clampedEdge(400) == 16)
        let frame = TriggerGeometry.triggerFrame(on: builtIn, placement: .topRightCorner, edgePoints: 0)
        #expect(frame.size == CGSize(width: 1, height: 1))
    }

    @Test func pixelEdgeFollowsTheBackingScale() {
        #expect(TriggerGeometry.pixelEdge(points: 1, backingScale: 2) == 2)
        #expect(TriggerGeometry.pixelEdge(points: 1, backingScale: 1) == 1)
        #expect(TriggerGeometry.pixelEdge(points: 1.4, backingScale: 2) == 3)
        #expect(TriggerGeometry.pixelEdge(points: 1, backingScale: 0) == 1)
        #expect(TriggerGeometry.pixelEdge(points: 0.1, backingScale: 1) == 1)
    }

    @Test func overlayCoversTheWholeScreenIncludingTheMenuBar() {
        #expect(TriggerGeometry.overlayFrame(on: builtIn) == builtIn.frame)
        #expect(TriggerGeometry.overlayFrame(on: external) == external.frame)
    }

    @Test func everyPlacementStaysInsideItsScreen() {
        for screen in [builtIn, external] {
            for placement in [TriggerPlacement.topRightCorner, .topLeftCorner, .notch] {
                for edge in [1.0, 2, 16] {
                    let frame = TriggerGeometry.triggerFrame(on: screen, placement: placement, edgePoints: edge)
                    #expect(screen.frame.contains(frame), "\(placement) \(edge)")
                    #expect(frame.maxY == screen.frame.maxY, "\(placement) \(edge) touches the top edge")
                }
            }
        }
    }
}
