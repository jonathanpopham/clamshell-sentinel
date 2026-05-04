import Foundation

public enum PowerCommandError: Error, CustomStringConvertible, Sendable {
    case processFailed(command: String, status: Int32, output: String)
    case launchFailed(command: String, message: String)

    public var description: String {
        switch self {
        case let .processFailed(command, status, output):
            return "\(command) exited with \(status): \(output)"
        case let .launchFailed(command, message):
            return "\(command) failed to launch: \(message)"
        }
    }
}

public protocol CommandRunning: Sendable {
    @discardableResult
    func run(_ executable: String, _ arguments: [String]) throws -> String
}

public struct ShellCommandRunner: CommandRunning {
    public init() {}

    @discardableResult
    public func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
        } catch {
            throw PowerCommandError.launchFailed(command: ([executable] + arguments).joined(separator: " "), message: error.localizedDescription)
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let string = String(decoding: data, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw PowerCommandError.processFailed(
                command: ([executable] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: string.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return string
    }
}

public struct PowerSettings: Equatable, Sendable {
    public var supportsDisablesleep: Bool
    public var disablesleepValue: Int?

    public init(supportsDisablesleep: Bool, disablesleepValue: Int?) {
        self.supportsDisablesleep = supportsDisablesleep
        self.disablesleepValue = disablesleepValue
    }
}

public struct PowerSettingsProbe: Sendable {
    public var runner: CommandRunning

    public init(runner: CommandRunning = ShellCommandRunner()) {
        self.runner = runner
    }

    public func readSettings() throws -> PowerSettings {
        let custom = try? runner.run("/usr/bin/pmset", ["-g", "custom"])
        let live = try? runner.run("/usr/bin/pmset", ["-g"])
        let text = [custom, live].compactMap(\.self).joined(separator: "\n")
        return PowerSettingsProbe.parse(text)
    }

    public static func parse(_ text: String) -> PowerSettings {
        let regex = try? NSRegularExpression(pattern: #"(?im)^\s*disablesleep\s+(\d+)\s*$"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard
            let regex,
            let match = regex.firstMatch(in: text, range: range),
            let valueRange = Range(match.range(at: 1), in: text),
            let value = Int(text[valueRange])
        else {
            return PowerSettings(supportsDisablesleep: false, disablesleepValue: nil)
        }

        return PowerSettings(supportsDisablesleep: true, disablesleepValue: value)
    }
}

public struct PrivilegedPMSet: Sendable {
    public var runner: CommandRunning

    public init(runner: CommandRunning = ShellCommandRunner()) {
        self.runner = runner
    }

    public func setDisablesleep(_ enabled: Bool) throws {
        let value = enabled ? "1" : "0"

        do {
            try runner.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
        } catch {
            try runWithAdministratorPrompt(value: value)
        }
    }

    private func runWithAdministratorPrompt(value: String) throws {
        let command = "/usr/bin/pmset -a disablesleep \(value)"
        let script = "do shell script \(Self.appleScriptString(command)) with administrator privileges"
        try runner.run("/usr/bin/osascript", ["-e", script])
    }

    public static func appleScriptString(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

public final class CaffeinateAssertion: @unchecked Sendable {
    private var process: Process?
    private let ownerPID: Int32

    public init(ownerPID: Int32 = ProcessInfo.processInfo.processIdentifier) {
        self.ownerPID = ownerPID
    }

    public var isActive: Bool {
        process?.isRunning == true
    }

    public func start() throws {
        guard process?.isRunning != true else {
            return
        }

        let assertion = Process()
        assertion.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        assertion.arguments = Self.arguments(ownerPID: ownerPID)
        assertion.standardOutput = Pipe()
        assertion.standardError = Pipe()
        try assertion.run()
        process = assertion
    }

    public func stop() {
        guard let process else {
            return
        }

        if process.isRunning {
            process.terminate()
        }

        self.process = nil
    }

    public static func arguments(ownerPID: Int32) -> [String] {
        ["-dimsu", "-w", String(ownerPID)]
    }
}

public final class AwakeController: @unchecked Sendable {
    public private(set) var isAwakeModeActive = false
    public private(set) var lastError: String?
    public private(set) var pmsetWasEnabledByApp = false

    private let pmset: PrivilegedPMSet
    private let caffeinate: CaffeinateAssertion

    public init(
        pmset: PrivilegedPMSet = PrivilegedPMSet(),
        caffeinate: CaffeinateAssertion = CaffeinateAssertion()
    ) {
        self.pmset = pmset
        self.caffeinate = caffeinate
    }

    public func reconcile(shouldStayAwake: Bool, config: SentinelConfig) {
        guard shouldStayAwake != isAwakeModeActive else {
            return
        }

        lastError = nil

        if shouldStayAwake {
            enable(config: config)
        } else {
            disable(config: config)
        }
    }

    public func disable(config: SentinelConfig, forcePMSet: Bool = false) {
        if config.useDisablesleep, pmsetWasEnabledByApp || forcePMSet {
            do {
                try pmset.setDisablesleep(false)
                pmsetWasEnabledByApp = false
            } catch {
                lastError = String(describing: error)
            }
        }

        caffeinate.stop()
        isAwakeModeActive = false
    }

    private func enable(config: SentinelConfig) {
        var didEnable = false

        if config.useDisablesleep {
            do {
                try pmset.setDisablesleep(true)
                pmsetWasEnabledByApp = true
                didEnable = true
            } catch {
                lastError = String(describing: error)
            }
        }

        if config.useCaffeinateFallback {
            do {
                try caffeinate.start()
                didEnable = true
            } catch {
                let message = String(describing: error)
                lastError = [lastError, message].compactMap(\.self).joined(separator: "\n")
            }
        }

        isAwakeModeActive = didEnable
    }
}
