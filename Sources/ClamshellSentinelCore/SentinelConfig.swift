import Foundation

public struct WatchedProcess: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var pattern: String
    public var enabled: Bool
    public var matchCommandLine: Bool

    public init(id: String, name: String, pattern: String, enabled: Bool = true, matchCommandLine: Bool = false) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.enabled = enabled
        self.matchCommandLine = matchCommandLine
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pattern
        case enabled
        case matchCommandLine
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.pattern = try container.decode(String.self, forKey: .pattern)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.matchCommandLine = try container.decodeIfPresent(Bool.self, forKey: .matchCommandLine) ?? false
    }
}

public struct SentinelConfig: Codable, Equatable, Sendable {
    public var pollIntervalSeconds: TimeInterval
    public var useDisablesleep: Bool
    public var useCaffeinateFallback: Bool
    public var watchedProcesses: [WatchedProcess]

    public init(
        pollIntervalSeconds: TimeInterval = 8,
        useDisablesleep: Bool = true,
        useCaffeinateFallback: Bool = true,
        watchedProcesses: [WatchedProcess] = SentinelConfig.defaultWatchedProcesses
    ) {
        self.pollIntervalSeconds = pollIntervalSeconds
        self.useDisablesleep = useDisablesleep
        self.useCaffeinateFallback = useCaffeinateFallback
        self.watchedProcesses = watchedProcesses
    }
}

public extension SentinelConfig {
    static let defaultWatchedProcesses: [WatchedProcess] = [
        WatchedProcess(
            id: "codex",
            name: "Codex",
            pattern: #"(?i)(^|[\s/])(codex|codex-cli)([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "claude",
            name: "Claude / Claude Code",
            pattern: #"(?i)(^|[\s/])(claude|claude-code)(\s|$)"#
        ),
        WatchedProcess(
            id: "aider",
            name: "aider",
            pattern: #"(?i)(^|[\s/])aider([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "openclaw",
            name: "OpenClaw",
            pattern: #"(?i)(^|[\s/])(openclaw|clawdbot)([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "hermes",
            name: "Hermes",
            pattern: #"(?i)(^|[\s/])(hermes|hermes-agent)([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "cursor-agent",
            name: "Cursor Agent",
            pattern: #"(?i)(^|[\s/])cursor-agent([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "opencode",
            name: "opencode",
            pattern: #"(?i)(^|[\s/])opencode([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "goose",
            name: "Goose",
            pattern: #"(?i)(^|[\s/])goose([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "openhands",
            name: "OpenHands",
            pattern: #"(?i)(^|[\s/])(openhands|open-hands)([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "swe-agent",
            name: "SWE-agent",
            pattern: #"(?i)(^|[\s/])swe-agent([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "gemini",
            name: "Gemini CLI",
            pattern: #"(?i)(^|[\s/])gemini([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "amp",
            name: "Amp",
            pattern: #"(?i)(^|[\s/])amp([\s._/-]|$)"#
        ),
        WatchedProcess(
            id: "docker-cli",
            name: "Docker CLI jobs",
            pattern: #"(?i)(^|[\s/])docker\s+(build|compose|run|pull|push|exec|logs|up)(\s|$)"#,
            matchCommandLine: true
        )
    ]

    static let defaultConfigDirectoryName = "clamshell-sentinel"
    static let defaultConfigFileName = "config.json"
}

public final class ConfigStore: Sendable {
    public let configURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(configURL: URL = ConfigStore.defaultConfigURL()) {
        self.configURL = configURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    public func loadOrCreate() throws -> SentinelConfig {
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            return try decoder.decode(SentinelConfig.self, from: data)
        }

        let config = SentinelConfig()
        try save(config)
        return config
    }

    public func save(_ config: SentinelConfig) throws {
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    public static func defaultConfigURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent(SentinelConfig.defaultConfigDirectoryName)
            .appendingPathComponent(SentinelConfig.defaultConfigFileName)
    }
}
