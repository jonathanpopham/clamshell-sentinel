import Foundation

public enum ManualAwakeMode: String, Codable, Equatable, Sendable {
    case automatic
    case alwaysAwake
}

public struct SentinelState: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var manualAwakeMode: ManualAwakeMode
    public var powerOverrideActive: Bool

    public init(
        enabled: Bool = true,
        manualAwakeMode: ManualAwakeMode = .automatic,
        powerOverrideActive: Bool = false
    ) {
        self.enabled = enabled
        self.manualAwakeMode = manualAwakeMode
        self.powerOverrideActive = powerOverrideActive
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case manualAwakeMode
        case powerOverrideActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.manualAwakeMode = try container.decodeIfPresent(ManualAwakeMode.self, forKey: .manualAwakeMode) ?? .automatic
        self.powerOverrideActive = try container.decodeIfPresent(Bool.self, forKey: .powerOverrideActive) ?? false
    }
}

public final class StateStore: Sendable {
    public let stateURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(stateURL: URL = StateStore.defaultStateURL()) {
        self.stateURL = stateURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    public func loadOrCreate() throws -> SentinelState {
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let data = try Data(contentsOf: stateURL)
            return try decoder.decode(SentinelState.self, from: data)
        }

        let state = SentinelState()
        try save(state)
        return state
    }

    public func save(_ state: SentinelState) throws {
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    public static func defaultStateURL() -> URL {
        ConfigStore.defaultConfigURL()
            .deletingLastPathComponent()
            .appendingPathComponent("state.json")
    }
}
