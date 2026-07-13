import Foundation

private struct ReplayFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct CameraQualityReplayCLI {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 10_000)
        let black = [UInt8](repeating: 0, count: 64)
        let normal: [UInt8] = (0..<64).map { index in
            ((index + index / 8) % 2) == 0 ? 70 : 190
        }
        let dark: [UInt8] = (0..<64).map { $0.isMultiple(of: 2) ? 5 : 15 }

        let obstruction = CameraQualityMetricsEngine()
        let startup = obstruction.evaluate(luminanceSamples: black, width: 8, height: 8, at: start)
        try require(startup.condition == .blackFrame, "startup black frame was not distinguished")
        try require(startup.obstructionEvidenceFrames == 1, "startup evidence count was not one")
        _ = obstruction.evaluate(luminanceSamples: black, width: 8, height: 8, at: start.addingTimeInterval(0.7))
        let covered = obstruction.evaluate(
            luminanceSamples: black,
            width: 8,
            height: 8,
            at: start.addingTimeInterval(1.3)
        )
        try require(covered.condition == .obstructed, "sustained obstruction was not confirmed")

        let normalResult = CameraQualityMetricsEngine().evaluate(
            luminanceSamples: normal,
            width: 8,
            height: 8,
            at: start
        )
        try require(normalResult.condition == .valid && normalResult.isUsable, "normal indoor frame was rejected")

        let darkResult = CameraQualityMetricsEngine().evaluate(
            luminanceSamples: dark,
            width: 8,
            height: 8,
            at: start
        )
        try require(darkResult.condition == .underexposed, "dark textured frame was not underexposed")

        let brightResult = CameraQualityMetricsEngine().evaluate(
            luminanceSamples: [UInt8](repeating: 255, count: 64),
            width: 8,
            height: 8,
            at: start
        )
        try require(brightResult.condition == .overexposed, "overexposed frame was not classified")

        let blankResult = CameraQualityMetricsEngine().evaluate(
            luminanceSamples: [UInt8](repeating: 128, count: 64),
            width: 8,
            height: 8,
            at: start
        )
        try require(blankResult.isUsable, "valid blank frame was blocked before inference")
        try require(blankResult.condition != .obstructed, "valid blank frame was called obstructed")

        let invalidResult = CameraQualityMetricsEngine().evaluate(
            luminanceSamples: [0, 1, 2],
            width: 8,
            height: 8,
            at: start
        )
        try require(invalidResult.condition == .invalidPixelBuffer, "malformed frame was not invalid")
        try require(invalidResult.condition != .obstructed, "malformed frame was called obstructed")

        let recovery = obstruction.evaluate(
            luminanceSamples: normal,
            width: 8,
            height: 8,
            at: start.addingTimeInterval(2)
        )
        try require(recovery.obstructionEvidenceFrames == 0, "valid frame did not clear obstruction evidence")

        print("Camera quality replay passed: 7 scenarios")
        print("startup=\(startup.condition.rawValue)")
        print("covered=\(covered.condition.rawValue)")
        print("normal=\(normalResult.condition.rawValue)")
        print("dark=\(darkResult.condition.rawValue)")
        print("bright=\(brightResult.condition.rawValue)")
        print("blank=\(blankResult.condition.rawValue),usable=\(blankResult.isUsable)")
        print("invalid=\(invalidResult.condition.rawValue)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw ReplayFailure(description: message) }
    }
}
