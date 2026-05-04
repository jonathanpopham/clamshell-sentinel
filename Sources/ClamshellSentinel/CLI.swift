import Foundation
import ClamshellSentinelCore

enum CLI {
    static func runIfRequested(arguments: [String]) -> Bool {
        guard let command = arguments.dropFirst().first else {
            return false
        }

        switch command {
        case "--version", "version":
            print("Clamshell Sentinel 0.1.0")
            return true
        case "--print-default-config":
            printDefaultConfig()
            return true
        case "--print-default-watchlist":
            print(SimpleWatchlist.defaultText, terminator: "")
            return true
        case "--config-path":
            print(ConfigStore.defaultConfigURL().path)
            return true
        case "--watchlist-path":
            print(WatchlistStore.defaultWatchlistURL().path)
            return true
        case "--scan-once":
            scanOnce()
            return true
        case "--diagnose":
            diagnose()
            return true
        default:
            return false
        }
    }

    private static func printDefaultConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(SentinelConfig())
            print(String(decoding: data, as: UTF8.self))
        } catch {
            fputs("Failed to encode default config: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func scanOnce() {
        do {
            let config = try ConfigStore().loadOrCreate()
            let snapshots = try PSProcessLister().processes()
            let matches = ProcessMatcher().matches(config: config, snapshots: snapshots)
            if matches.isEmpty {
                print("No watched processes are running.")
            } else {
                for match in matches {
                    print("\(match.process.name) pid=\(match.snapshot.pid) \(match.snapshot.command)")
                }
            }
        } catch {
            fputs("Scan failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func diagnose() {
        let runner = ShellCommandRunner()
        let commands = [
            ("/usr/bin/sw_vers", []),
            ("/usr/bin/uname", ["-m"]),
            ("/usr/bin/pmset", ["-g", "cap"]),
            ("/usr/bin/pmset", ["-g", "custom"])
        ]

        for (executable, arguments) in commands {
            print("$ \(([executable] + arguments).joined(separator: " "))")
            do {
                print(try runner.run(executable, arguments).trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                print("failed: \(error)")
            }
            print("")
        }

        do {
            let settings = try PowerSettingsProbe(runner: runner).readSettings()
            print("disablesleep visible: \(settings.supportsDisablesleep)")
            if let value = settings.disablesleepValue {
                print("disablesleep value: \(value)")
            }
        } catch {
            print("disablesleep probe failed: \(error)")
        }
    }
}
