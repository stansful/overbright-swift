// OverbrightTriggersTests/LoggedErrorTests.swift — what a `.public` log line may say about an error: a case name or a
// domain and code, never a description or a path. ARCHITECTURE.md §9.2 rule 8, §8.2 (the Caches folder holds the
// user's home folder name). Files go to a fresh temporary folder only.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightTriggers

@Suite struct LoggedErrorTests {
    private static let path = "/Users/someone/Library/Caches/app.overbright.Overbright/.0000.mov"

    @Test func aFileSystemErrorIsADomainAndCodeWithoutItsPath() {
        let error = CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: Self.path])
        #expect(String(describing: error).contains("someone"), "the description is what must stay private")
        let summary = LoggedError.publicSummary(error)
        #expect(summary == "\(NSCocoaErrorDomain) \(CocoaError.fileWriteNoPermission.rawValue)")
        #expect(!summary.contains("someone") && !summary.contains("/"))
    }

    @Test func stillFailuresAndTriggerErrorsAreTheirCaseNames() {
        let writerError = "Optional(Error Domain=AVFoundationErrorDomain Code=-11800 NSFilePath=\(Self.path))"
        #expect(LoggedError.publicSummary(HLGStillAsset.Failure.startFailed(writerError)) == "startFailed")
        #expect(LoggedError.publicSummary(HLGStillAsset.Failure.finishFailed(writerError)) == "finishFailed")
        #expect(LoggedError.publicSummary(HLGStillAsset.Failure.moveFailed(13)) == "moveFailed(errno 13)")
        #expect(LoggedError.publicSummary(HLGStillAsset.Failure.allCodecsFailed(["proRes422: startFailed"]))
                == "allCodecsFailed(proRes422: startFailed)")
        #expect(LoggedError.publicSummary(TriggerError.displayGone) == "displayGone")
        #expect(LoggedError.publicSummary(TriggerError.needsNewerMacOS(26)) == "needsNewerMacOS(26)")
    }

    @Test func aStillThatCannotBeWrittenFailsWithoutItsPath() async throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: "overbright-hlg-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            try? fm.removeItem(at: folder)
        }
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)   // read-only: every write fails
        do {
            _ = try await HLGStillAsset.ensureCached(level: .black, codecs: [.proRes422], in: folder)
            Issue.record("a read-only folder cannot hold a still")
        } catch let failure as HLGStillAsset.Failure {
            guard case .allCodecsFailed(let entries) = failure else {
                Issue.record("expected allCodecsFailed, got \(failure.publicSummary)")
                return
            }
            #expect(entries.count == 1)
            #expect(entries.first?.hasPrefix("proRes422: ") == true)
            #expect(!String(describing: failure).contains(folder.path), "the error itself carries no path")
        }
    }
}
