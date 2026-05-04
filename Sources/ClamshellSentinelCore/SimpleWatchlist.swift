import Foundation

public struct SimpleWatchlist: Sendable {
    public static let defaultText = """
    # Add one process or command per line. Changes are picked up automatically.
    # Examples:
    # my-agent
    # command: make release
    # regex: (?i)(^|[\\s/])custom-agent([\\s._/-]|$)

    """

    public init() {}

    public func parse(_ text: String) -> [WatchedProcess] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, rawLine in
                Self.parseLine(String(rawLine), index: index)
            }
    }

    public static func parseLine(_ rawLine: String, index: Int) -> WatchedProcess? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            return nil
        }

        let (name, body) = splitName(trimmed)
        let parsed = parseBody(body)
        let finalName = name ?? parsed.displayName

        return WatchedProcess(
            id: "watchlist-\(index)-\(slug(finalName))",
            name: finalName,
            pattern: parsed.pattern,
            enabled: true,
            matchCommandLine: parsed.matchCommandLine
        )
    }

    private static func splitName(_ line: String) -> (String?, String) {
        guard let separator = line.firstIndex(of: "=") else {
            return (nil, line)
        }

        let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let body = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !body.isEmpty else {
            return (nil, line)
        }

        return (name, body)
    }

    private static func parseBody(_ body: String) -> (displayName: String, pattern: String, matchCommandLine: Bool) {
        let lowercased = body.lowercased()

        if lowercased.hasPrefix("command-regex:") {
            let value = trimmedValue(body, prefix: "command-regex:")
            return (value, value, true)
        }

        if lowercased.hasPrefix("cmd-regex:") {
            let value = trimmedValue(body, prefix: "cmd-regex:")
            return (value, value, true)
        }

        if lowercased.hasPrefix("regex:") {
            let value = trimmedValue(body, prefix: "regex:")
            return (value, value, false)
        }

        if lowercased.hasPrefix("command:") {
            let value = trimmedValue(body, prefix: "command:")
            return (value, literalPattern(value), true)
        }

        if lowercased.hasPrefix("cmd:") {
            let value = trimmedValue(body, prefix: "cmd:")
            return (value, literalPattern(value), true)
        }

        if body.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return (body, literalPattern(body), true)
        }

        return (body, executablePattern(body), false)
    }

    private static func trimmedValue(_ body: String, prefix: String) -> String {
        let index = body.index(body.startIndex, offsetBy: prefix.count)
        return body[index...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func executablePattern(_ value: String) -> String {
        #"(?i)(^|[\s/])"# + NSRegularExpression.escapedPattern(for: value) + #"([\s._/-]|$)"#
    }

    private static func literalPattern(_ value: String) -> String {
        "(?i)" + NSRegularExpression.escapedPattern(for: value)
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

public final class WatchlistStore: Sendable {
    public let watchlistURL: URL
    private let parser: SimpleWatchlist

    public init(watchlistURL: URL = WatchlistStore.defaultWatchlistURL(), parser: SimpleWatchlist = SimpleWatchlist()) {
        self.watchlistURL = watchlistURL
        self.parser = parser
    }

    public func loadOrCreate() throws -> [WatchedProcess] {
        if !FileManager.default.fileExists(atPath: watchlistURL.path) {
            try FileManager.default.createDirectory(
                at: watchlistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try SimpleWatchlist.defaultText.write(to: watchlistURL, atomically: true, encoding: .utf8)
        }

        let text = try String(contentsOf: watchlistURL, encoding: .utf8)
        return parser.parse(text)
    }

    public static func defaultWatchlistURL() -> URL {
        ConfigStore.defaultConfigURL()
            .deletingLastPathComponent()
            .appendingPathComponent(SentinelConfig.defaultWatchlistFileName)
    }
}
