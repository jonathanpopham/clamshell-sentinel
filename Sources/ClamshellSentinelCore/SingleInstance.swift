import Foundation

public enum SingleInstance {
    public static func terminateOlderInstances(
        executablePath: String,
        ownPID: Int32 = ProcessInfo.processInfo.processIdentifier,
        lister: ProcessListing = PSProcessLister()
    ) {
        guard let snapshots = try? lister.processes() else {
            return
        }

        for pid in olderInstancePIDs(executablePath: executablePath, ownPID: ownPID, snapshots: snapshots) {
            kill(pid, SIGTERM)
        }
    }

    public static func olderInstancePIDs(
        executablePath: String,
        ownPID: Int32,
        snapshots: [ProcessSnapshot]
    ) -> [Int32] {
        snapshots.compactMap { snapshot in
            guard snapshot.pid != ownPID else {
                return nil
            }

            return isSameAppProcess(command: snapshot.command, executablePath: executablePath) ? snapshot.pid : nil
        }
    }

    public static func isSameAppProcess(command: String, executablePath: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == executablePath else {
            return false
        }

        return executablePath.hasSuffix(".app/Contents/MacOS/ClamshellSentinel")
    }
}
