import Foundation

public enum AwakeReason: Equatable, Sendable {
    case disabled
    case manualAlwaysAwake
    case processMatches([ProcessMatch])
    case noMatches
}

public struct AwakeDecision: Equatable, Sendable {
    public var shouldStayAwake: Bool
    public var reason: AwakeReason

    public init(shouldStayAwake: Bool, reason: AwakeReason) {
        self.shouldStayAwake = shouldStayAwake
        self.reason = reason
    }
}

public struct AwakeDecider: Sendable {
    public init() {}

    public func decide(state: SentinelState, matches: [ProcessMatch]) -> AwakeDecision {
        guard state.enabled else {
            return AwakeDecision(shouldStayAwake: false, reason: .disabled)
        }

        if state.manualAwakeMode == .alwaysAwake {
            return AwakeDecision(shouldStayAwake: true, reason: .manualAlwaysAwake)
        }

        if !matches.isEmpty {
            return AwakeDecision(shouldStayAwake: true, reason: .processMatches(matches))
        }

        return AwakeDecision(shouldStayAwake: false, reason: .noMatches)
    }
}
