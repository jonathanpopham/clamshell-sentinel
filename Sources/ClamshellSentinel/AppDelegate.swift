import AppKit
import ClamshellSentinelCore
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let configStore = ConfigStore()
    private let stateStore = StateStore()
    private let processLister = PSProcessLister()
    private let matcher = ProcessMatcher()
    private let decider = AwakeDecider()
    private let awakeController = AwakeController()

    private var timer: Timer?
    private var config = SentinelConfig()
    private var state = SentinelState()
    private var matches: [ProcessMatch] = []
    private var decision = AwakeDecision(shouldStayAwake: false, reason: .noMatches)
    private var lastRefreshError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureIcon()
        refresh()
        scheduleTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        awakeController.disable(config: config)
        persistPowerOverride(awakeController.pmsetWasEnabledByApp)
    }

    private func configureIcon() {
        guard let button = statusItem.button else {
            return
        }

        if let imageURL = Bundle.main.url(forResource: "MenuIconTemplate", withExtension: "png") ?? Bundle.module.url(forResource: "MenuIconTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: imageURL) {
            image.isTemplate = true
            button.image = image
        } else if let image = NSImage(systemSymbolName: "laptopcomputer.and.arrow.down", accessibilityDescription: "Clamshell Sentinel") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "CS"
        }

        button.toolTip = "Clamshell Sentinel"
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = max(3, config.pollIntervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        do {
            config = try configStore.loadOrCreate()
            state = try stateStore.loadOrCreate()
            matches = matcher.matches(config: config, snapshots: try processLister.processes())
            decision = decider.decide(state: state, matches: matches)

            if state.powerOverrideActive && !decision.shouldStayAwake {
                awakeController.disable(config: config, forcePMSet: true)
            } else {
                awakeController.reconcile(shouldStayAwake: decision.shouldStayAwake, config: config)
            }

            persistPowerOverride(awakeController.pmsetWasEnabledByApp)
            lastRefreshError = nil
            scheduleTimer()
        } catch {
            lastRefreshError = error.localizedDescription
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusTitle(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let detail = statusDetail() {
            let detailItem = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            menu.addItem(detailItem)
        }

        if let error = lastRefreshError ?? awakeController.lastError {
            let errorItem = NSMenuItem(title: "Last error: \(Self.truncate(error, length: 72))", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())

        let enabled = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = state.enabled ? .on : .off
        menu.addItem(enabled)

        let alwaysAwake = NSMenuItem(title: "Always Awake on Close", action: #selector(toggleAlwaysAwake), keyEquivalent: "")
        alwaysAwake.target = self
        alwaysAwake.state = state.manualAwakeMode == .alwaysAwake ? .on : .off
        menu.addItem(alwaysAwake)

        menu.addItem(.separator())

        let checkNow = NSMenuItem(title: "Check Now", action: #selector(checkNow), keyEquivalent: "r")
        checkNow.target = self
        menu.addItem(checkNow)

        let openConfig = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: ",")
        openConfig.target = self
        menu.addItem(openConfig)

        let revealConfig = NSMenuItem(title: "Reveal Config", action: #selector(revealConfig), keyEquivalent: "")
        revealConfig.target = self
        menu.addItem(revealConfig)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func statusTitle() -> String {
        switch decision.reason {
        case .disabled:
            return "Clamshell Sentinel Off"
        case .manualAlwaysAwake:
            return awakeController.isAwakeModeActive ? "Keeping Awake: Manual" : "Manual Awake Pending"
        case .processMatches:
            return awakeController.isAwakeModeActive ? "Keeping Awake: Agent Running" : "Agent Found"
        case .noMatches:
            return "No Watched Agents Running"
        }
    }

    private func statusDetail() -> String? {
        switch decision.reason {
        case .disabled:
            return "Close lid behavior is untouched."
        case .manualAlwaysAwake:
            return "Manual override is active."
        case let .processMatches(matches):
            let names = matches.prefix(4).map { "\($0.process.name) (\($0.snapshot.pid))" }.joined(separator: ", ")
            if matches.count > 4 {
                return "\(names), +\(matches.count - 4) more"
            }
            return names
        case .noMatches:
            return "Normal sleep behavior is restored."
        }
    }

    @objc private func toggleEnabled() {
        mutateState { state in
            state.enabled.toggle()
        }
    }

    @objc private func toggleAlwaysAwake() {
        mutateState { state in
            state.manualAwakeMode = state.manualAwakeMode == .alwaysAwake ? .automatic : .alwaysAwake
        }
    }

    @objc private func checkNow() {
        refresh()
    }

    @objc private func openConfig() {
        do {
            _ = try configStore.loadOrCreate()
            NSWorkspace.shared.open(configStore.configURL)
        } catch {
            lastRefreshError = error.localizedDescription
            rebuildMenu()
        }
    }

    @objc private func revealConfig() {
        do {
            _ = try configStore.loadOrCreate()
            NSWorkspace.shared.activateFileViewerSelecting([configStore.configURL])
        } catch {
            lastRefreshError = error.localizedDescription
            rebuildMenu()
        }
    }

    @objc private func quit() {
        awakeController.disable(config: config)
        NSApp.terminate(nil)
    }

    private func mutateState(_ update: (inout SentinelState) -> Void) {
        do {
            var next = try stateStore.loadOrCreate()
            update(&next)
            try stateStore.save(next)
            refresh()
        } catch {
            lastRefreshError = error.localizedDescription
            rebuildMenu()
        }
    }

    private func persistPowerOverride(_ active: Bool) {
        guard state.powerOverrideActive != active else {
            return
        }

        do {
            state.powerOverrideActive = active
            try stateStore.save(state)
        } catch {
            lastRefreshError = error.localizedDescription
        }
    }

    private static func truncate(_ value: String, length: Int) -> String {
        guard value.count > length else {
            return value
        }
        return String(value.prefix(length - 1)) + "..."
    }
}
