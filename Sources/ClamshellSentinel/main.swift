import AppKit
import ClamshellSentinelCore

if CLI.runIfRequested(arguments: CommandLine.arguments) {
    exit(0)
}

if let executablePath = Bundle.main.executableURL?.path {
    SingleInstance.terminateOlderInstances(executablePath: executablePath)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
