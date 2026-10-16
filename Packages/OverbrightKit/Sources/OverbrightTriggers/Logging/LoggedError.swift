// OverbrightTriggers/Logging/LoggedError.swift — the part of an error that may go into a `.public` log line.
// ARCHITECTURE.md §9.2 rule 8 (no paths or other user data in `.public` logs), §8.2 (the Caches folder holds the
// user's home folder name). Thread: any.
//
// File-system and AVFoundation errors describe themselves with the file path (a CocoaError carries `NSFilePath`,
// e.g. /Users/<name>/Library/Caches/…), so a description is only ever logged `.private`; the public summary is a
// case name, or an `NSError` domain and code.
import Foundation
import OverbrightCore

/// Path-free summaries of errors for `.public` logs.
nonisolated enum LoggedError {
    /// `TriggerError` and `HLGStillAsset.Failure` by case name (and their numbers); any other error as
    /// "<domain> <code>". Never a description, a user-info value or a path.
    static func publicSummary(_ error: any Error) -> String {
        switch error {
        case let failure as HLGStillAsset.Failure:
            return failure.publicSummary
        case let trigger as TriggerError:
            return String(describing: trigger)   // cases carry no user data (at most a macOS version)
        default:
            let error = error as NSError
            return "\(error.domain) \(error.code)"
        }
    }
}
