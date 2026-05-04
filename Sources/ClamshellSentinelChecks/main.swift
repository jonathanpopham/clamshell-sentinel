import ClamshellSentinelCore
import Foundation

@discardableResult
@MainActor
func check(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        return true
    }

    fputs("FAIL: \(message)\n", stderr)
    failures += 1
    return false
}

var failures = 0

let psOutput = """
  123 /usr/local/bin/codex run
  456 /bin/zsh -l
"""

check(
    PSProcessLister.parse(psOutput) == [
        ProcessSnapshot(pid: 123, command: "/usr/local/bin/codex run"),
        ProcessSnapshot(pid: 456, command: "/bin/zsh -l")
    ],
    "parses ps output"
)

let snapshots = [
    ProcessSnapshot(pid: 10, command: "/opt/homebrew/bin/codex"),
    ProcessSnapshot(pid: 11, command: "/Users/me/.local/bin/aider --model sonnet"),
    ProcessSnapshot(pid: 12, command: "/usr/local/bin/docker compose up api"),
    ProcessSnapshot(pid: 13, command: "/usr/bin/rg codex README.md")
]

let matches = ProcessMatcher(ownPID: 999).matches(config: SentinelConfig(), snapshots: snapshots)
let ids = matches.map(\.process.id)
check(ids.contains("codex"), "matches Codex")
check(ids.contains("aider"), "matches aider")
check(ids.contains("docker-cli"), "matches Docker CLI jobs")
check(!matches.contains { $0.snapshot.pid == 13 }, "does not match incidental text search")

check(
    ProcessMatcher().matches(
        config: SentinelConfig(),
        snapshots: [ProcessSnapshot(pid: 15, command: "/Applications/Claude.app/Contents/Helpers/chrome-native-host")]
    ).isEmpty,
    "does not match Claude Desktop helper as Claude Code"
)

let customCommandConfig = SentinelConfig(watchedProcesses: [
    WatchedProcess(
        id: "release-build",
        name: "Release build",
        pattern: #"(?i)make\s+release"#,
        matchCommandLine: true
    )
])
check(
    !ProcessMatcher().matches(
        config: customCommandConfig,
        snapshots: [ProcessSnapshot(pid: 14, command: "/usr/bin/rg make release README.md")]
    ).isEmpty,
    "custom matchCommandLine patterns can watch arbitrary terminal commands"
)

let disabledConfig = SentinelConfig(watchedProcesses: [
    WatchedProcess(id: "codex", name: "Codex", pattern: #"(?i)codex"#, enabled: false)
])
check(
    ProcessMatcher().matches(config: disabledConfig, snapshots: [ProcessSnapshot(pid: 10, command: "/opt/homebrew/bin/codex")]).isEmpty,
    "ignores disabled patterns"
)

let disabledDecision = AwakeDecider().decide(
    state: SentinelState(enabled: false),
    matches: [
        ProcessMatch(
            process: WatchedProcess(id: "codex", name: "Codex", pattern: "codex"),
            snapshot: ProcessSnapshot(pid: 1, command: "codex")
        )
    ]
)
check(!disabledDecision.shouldStayAwake, "disabled state restores sleep")
check(disabledDecision.reason == .disabled, "disabled reason is reported")

let manualDecision = AwakeDecider().decide(
    state: SentinelState(enabled: true, manualAwakeMode: .alwaysAwake),
    matches: []
)
check(manualDecision.shouldStayAwake, "manual mode keeps awake")
check(manualDecision.reason == .manualAlwaysAwake, "manual reason is reported")

let settings = PowerSettingsProbe.parse(
    """
    Battery Power:
     sleep                1
     disablesleep         1
    AC Power:
     sleep                1
    """
)
check(settings.supportsDisablesleep, "parses disablesleep support")
check(settings.disablesleepValue == 1, "parses disablesleep value")

let missingSettings = PowerSettingsProbe.parse(
    """
    Battery Power:
     sleep                1
    """
)
check(!missingSettings.supportsDisablesleep, "missing disablesleep is unsupported")
check(missingSettings.disablesleepValue == nil, "missing disablesleep has nil value")

check(
    PrivilegedPMSet.appleScriptString(#"/usr/bin/pmset "x""#) == #""/usr/bin/pmset \"x\"""#,
    "escapes AppleScript shell command"
)

check(
    CaffeinateAssertion.arguments(ownerPID: 12345) == ["-dimsu", "-w", "12345"],
    "binds fallback caffeinate assertion to Sentinel process lifetime"
)

let legacyStateData = Data(#"{"enabled":true,"manualAwakeMode":"automatic"}"#.utf8)
if let legacyState = try? JSONDecoder().decode(SentinelState.self, from: legacyStateData) {
    check(!legacyState.powerOverrideActive, "legacy state defaults power override tracking to false")
} else {
    check(false, "decodes legacy state")
}

if failures == 0 {
    print("All checks passed.")
} else {
    fputs("\(failures) checks failed.\n", stderr)
    exit(1)
}
