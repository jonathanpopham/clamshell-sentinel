import AppKit

if CLI.runIfRequested(arguments: CommandLine.arguments) {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
