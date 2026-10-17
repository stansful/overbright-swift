// OverbrightTriggersTests/Support/PublicLogLint.swift — the `.public` log allowlist scan that
// `TriggerModuleLintTests` runs over the module's sources and checks with its own positive and negative cases.
// ARCHITECTURE.md §9.2 rule 8, §10.5 (C-PLATFORM-10).
import Foundation

/// The `.public` log allowlist of this module (§9.2 rule 8): every `\(value, privacy: .public)` interpolation must be a
/// `LoggedError` summary (inline, or a name every binding of which in the file is one), a case's raw value, one of our
/// asset file names, an ID or a count. Anything else, a description bound to a name first included, is a violation.
/// The file is scanned as one text, so an interpolation split across lines is judged whole, and a `privacy: .public`
/// the scan cannot attribute to one interpolation's last argument is a violation too (C-PLATFORM-10).
enum PublicLogLint {
    /// One `\( … )` interpolation: the line it starts on and its top-level, comma-separated arguments, each with the
    /// character offsets it spans in the scanned text.
    struct Interpolation {
        var line: Int
        var arguments: [(text: String, span: Range<Int>)]
    }

    /// The line numbers of `.public` interpolations off the allowlist, and of `privacy: .public` outside any
    /// interpolation's last argument, in one file's code lines (sorted, each once).
    static func violations(in lines: [(Int, String)]) throws -> [Int] {
        let (characters, lineOf) = text(of: lines)
        let summaries = try summaryNames(in: lines)
        var found = Set<Int>()
        var publicArguments: [Range<Int>] = []
        for interpolation in interpolations(in: characters, lineOf: lineOf) {
            guard interpolation.arguments.count > 1, let last = interpolation.arguments.last, isPublic(last.text) else {
                continue
            }
            publicArguments.append(last.span)
            if !isAllowed(interpolation.arguments[0].text, summaries: summaries) { found.insert(interpolation.line) }
        }
        for offset in try publicPrivacyOffsets(in: String(characters))
        where !publicArguments.contains(where: { $0.contains(offset) }) {
            found.insert(lineOf[offset])
        }
        return found.sorted()
    }

    /// Whether an interpolation argument is `privacy: .public`.
    static func isPublic(_ argument: String) -> Bool {
        argument.filter { !$0.isWhitespace } == "privacy:.public"
    }

    /// Whether `expression` may be logged `.public`.
    static func isAllowed(_ expression: String, summaries: Set<String>) -> Bool {
        let value = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if summaryCallEnd(in: value[...]) == value.endIndex { return true }   // one whole call, nothing after it
        if summaries.contains(value) || value == "count" { return true }
        let path = value.split(separator: ".", omittingEmptySubsequences: false)
        guard path.count > 1, path.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" } })
        else { return false }
        return ["rawValue", "fileName", "id", "count"].contains(String(path[path.count - 1]))
    }

    /// The names bound to one whole `LoggedError.publicSummary(…)` and to nothing else anywhere in the file: a name
    /// that one function binds to a summary and another to a description is no summary, nor is one whose binding goes
    /// on after the call (`LoggedError.publicSummary(error) + detail`, on its line or the next) or that a compound
    /// assignment extends (`summary += detail`) (C-PLATFORM-10). Every `name =` and `name: Type =` counts as a
    /// binding, `let`, `var` and plain assignments alike, and every compound assignment (`+=`, `<<=`, `&+=` …) as one
    /// to something else; `==`, `!=`, `<=` and `>=` are no bindings.
    static func summaryNames(in lines: [(Int, String)]) throws -> Set<String> {
        let code = String(text(of: lines).characters)
        let binding = try Regex(#"\b(\w+)[ \t]*(?::[ \t]*[\w.?!<>\[\]]+[ \t]*)?=(?!=)\s*"#)
        let compound = try Regex(#"\b(\w+)[ \t]*(?:&?[-+*/%]|[&|^]|&?<<|&?>>)=(?!=)"#)
        var summaries = Set<String>(), others = Set<String>()
        for match in code.matches(of: binding) {
            guard let name = match.output[1].substring.map(String.init) else { continue }
            let rest = code[match.range.upperBound...]
            if let end = summaryCallEnd(in: rest), !continues(rest[end...]) {
                summaries.insert(name)
            } else {
                others.insert(name)
            }
        }
        for match in code.matches(of: compound) {
            if let name = match.output[1].substring.map(String.init) { others.insert(name) }
        }
        return summaries.subtracting(others)
    }

    /// Where the `LoggedError.publicSummary(…)` call that `text` starts with ends (just after its closing
    /// parenthesis); nil when `text` does not start with one or it never closes.
    static func summaryCallEnd(in text: Substring) -> String.Index? {
        let call = "LoggedError.publicSummary("
        guard text.hasPrefix(call) else { return nil }
        var depth = 1
        var index = text.index(text.startIndex, offsetBy: call.count)
        while index < text.endIndex {
            if text[index] == "(" { depth += 1 }
            if text[index] == ")" { depth -= 1 }
            index = text.index(after: index)
            if depth == 0 { return index }
        }
        return nil
    }

    /// Whether the expression goes on in `rest`, the text right after a call: on the call's line anything but the
    /// end of the binding (a `,` before the next one, `;`, `}`, `)` or a comment) continues it; on the next code line
    /// a member or an operator does (`.appending(detail)`, `+ detail`).
    static func continues(_ rest: Substring) -> Bool {
        let line = rest.prefix { $0 != "\n" }.trimmingCharacters(in: .whitespaces)
        if let first = line.first { return !(line.hasPrefix("//") || ",;})".contains(first)) }
        let next = rest.drop { $0.isWhitespace }
        guard let first = next.first, !next.hasPrefix("//") else { return false }
        return ".+-*/%&|^<>=!?~".contains(first)
    }

    /// The code lines as one text (each line followed by a newline) and the line number of every character.
    static func text(of lines: [(Int, String)]) -> (characters: [Character], lineOf: [Int]) {
        var characters: [Character] = [], lineOf: [Int] = []
        for (number, line) in lines {
            for character in line + "\n" {
                characters.append(character)
                lineOf.append(number)
            }
        }
        return (characters, lineOf)
    }

    /// The character offsets of every `privacy: .public` (any spacing) in `text`.
    static func publicPrivacyOffsets(in text: String) throws -> [Int] {
        let privacy = try Regex(#"privacy\s*:\s*\.public\b"#)
        return text.matches(of: privacy).map { text.distance(from: text.startIndex, to: $0.range.lowerBound) }
    }

    /// Every `\( … )` interpolation in `characters`, across line ends: its top-level arguments end at a comma or at
    /// the closing parenthesis.
    static func interpolations(in characters: [Character], lineOf: [Int]) -> [Interpolation] {
        var found: [Interpolation] = []
        var index = 0
        while index + 1 < characters.count {
            guard characters[index] == "\\", characters[index + 1] == "(" else { index += 1; continue }
            var depth = 1, cursor = index + 2, start = cursor, current = ""
            var arguments: [(text: String, span: Range<Int>)] = []
            while cursor < characters.count, depth > 0 {
                let character = characters[cursor]
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                if depth == 1, character == "," {
                    arguments.append((current, start..<cursor)); current = ""; start = cursor + 1
                } else if depth > 0 {
                    current.append(character)
                }
                cursor += 1
            }
            arguments.append((current, start..<max(start, cursor - 1)))
            found.append(Interpolation(line: lineOf[index], arguments: arguments))
            index = cursor
        }
        return found
    }

    /// The top-level, comma-separated arguments of every `\( … )` interpolation in one line.
    static func interpolations(in line: String) -> [[String]] {
        let (characters, lineOf) = text(of: [(1, line)])
        return interpolations(in: characters, lineOf: lineOf).map { $0.arguments.map(\.text) }
    }
}
