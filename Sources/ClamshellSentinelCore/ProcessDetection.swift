import Foundation

public struct ProcessSnapshot: Equatable, Sendable {
    public var pid: Int32
    public var command: String

    public init(pid: Int32, command: String) {
        self.pid = pid
        self.command = command
    }
}

public struct ProcessMatch: Equatable, Identifiable, Sendable {
    public var id: String { "\(process.id)-\(snapshot.pid)" }
    public var process: WatchedProcess
    public var snapshot: ProcessSnapshot

    public init(process: WatchedProcess, snapshot: ProcessSnapshot) {
        self.process = process
        self.snapshot = snapshot
    }
}

public protocol ProcessListing: Sendable {
    func processes() throws -> [ProcessSnapshot]
}

public struct PSProcessLister: ProcessListing {
    public init() {}

    public func processes() throws -> [ProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let string = String(decoding: data, as: UTF8.self)
        return PSProcessLister.parse(string)
    }

    public static func parse(_ output: String) -> [ProcessSnapshot] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let firstSpace = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
                return nil
            }

            let pidPart = trimmed[..<firstSpace]
            let commandPart = trimmed[firstSpace...].trimmingCharacters(in: .whitespacesAndNewlines)

            guard let pid = Int32(pidPart), !commandPart.isEmpty else {
                return nil
            }

            return ProcessSnapshot(pid: pid, command: commandPart)
        }
    }
}

public struct ProcessMatcher: Sendable {
    public var ownPID: Int32

    public init(ownPID: Int32 = ProcessInfo.processInfo.processIdentifier) {
        self.ownPID = ownPID
    }

    public func matches(config: SentinelConfig, snapshots: [ProcessSnapshot]) -> [ProcessMatch] {
        let compiled = config.watchedProcesses
            .filter(\.enabled)
            .compactMap { watched -> (WatchedProcess, NSRegularExpression)? in
                guard let regex = try? NSRegularExpression(pattern: watched.pattern) else {
                    return nil
                }
                return (watched, regex)
            }

        return snapshots.flatMap { snapshot -> [ProcessMatch] in
            guard snapshot.pid != ownPID else {
                return []
            }

            return compiled.compactMap { watched, regex in
                let subjects = watched.matchCommandLine ? [snapshot.command] : Self.matchSubjects(for: snapshot.command)
                return subjects.contains { subject in
                    let range = NSRange(subject.startIndex..<subject.endIndex, in: subject)
                    return regex.firstMatch(in: subject, range: range) != nil
                } ? ProcessMatch(process: watched, snapshot: snapshot) : nil
            }
        }
    }

    public static func matchSubjects(for command: String) -> [String] {
        let tokens = command
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard let first = tokens.first else {
            return []
        }

        let executableName = URL(fileURLWithPath: first).lastPathComponent.lowercased()
        var subjects = [first]

        if ["node", "python", "python3", "bun", "deno", "npx", "uvx", "pipx"].contains(executableName) {
            subjects.append(command)
        }

        if executableName == "docker" {
            subjects.append(tokens.prefix(4).joined(separator: " "))
        }

        subjects.append(contentsOf: tokens.dropFirst().filter { $0.contains("/") })

        var seen = Set<String>()
        return subjects.filter { seen.insert($0).inserted }
    }
}
