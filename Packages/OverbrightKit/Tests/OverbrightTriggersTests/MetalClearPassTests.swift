// OverbrightTriggersTests/MetalClearPassTests.swift — opt-in (OVERBRIGHT_HARDWARE=1): the clear-only pass of T2/T3
// cleared into an OFF-SCREEN 2 × 2 rgba16Float texture reads back 1.6 (half precision: ≈ 1.5996) without any Metal
// library. ARCHITECTURE.md D22, §9.1 ("the off-screen Metal clear only with OVERBRIGHT_HARDWARE=1"), §10.5. No layer,
// no drawable, no window: nothing reaches a display, and CI's virtual machines (which may lack a usable Metal device)
// skip it.
import Foundation
import Metal
import Testing
@testable import OverbrightTriggers

@Suite(.enabled(if: ProcessInfo.processInfo.environment["OVERBRIGHT_HARDWARE"] == "1", "set OVERBRIGHT_HARDWARE=1"))
struct MetalClearPassTests {
    @Test(arguments: [0.0, 1.0, 1.6, 8.0])
    func clearOnlyPassReadsBackTheValue(value: Double) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 2, height: 2,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let commandBuffer = try #require(queue.makeCommandBuffer())
        #expect(MetalClearPass.encode(clearing: texture, to: value, in: commandBuffer))
        if texture.storageMode == .managed, let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: texture)
            blit.endEncoding()
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        #expect(commandBuffer.status == .completed)
        var halves = [UInt16](repeating: 0, count: 2 * 2 * 4)
        halves.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            texture.getBytes(base, bytesPerRow: 2 * 4 * 2, from: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0)
        }
        for (index, half) in halves.enumerated() {
            let expected = index % 4 == 3 ? 1.0 : value
            #expect(abs(Self.float(fromHalf: half) - expected) <= max(0.001, expected * 0.001), "component \(index)")
        }
    }

    /// IEEE 754 half → Double (Float16 is unavailable on x86_64 macOS).
    static func float(fromHalf bits: UInt16) -> Double {
        let sign: Double = bits & 0x8000 == 0 ? 1 : -1
        let exponent = Int((bits >> 10) & 0x1F)
        let fraction = Double(bits & 0x3FF)
        switch exponent {
        case 0: return sign * fraction / 1024 * pow(2, -14)
        case 31: return fraction == 0 ? sign * .infinity : .nan
        default: return sign * (1 + fraction / 1024) * pow(2, Double(exponent - 15))
        }
    }
}
