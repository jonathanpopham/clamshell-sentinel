# Clamshell Sentinel

![Clamshell Sentinel header](assets/repo-header.png)

Clamshell Sentinel is a tiny macOS menu bar app for developer laptops: close the lid normally when nothing important is running, but keep the machine awake when an agent or long terminal job is active.

It watches local processes such as Codex, Claude, aider, OpenClaw, Hermes, Cursor Agent, OpenHands, Goose, opencode, SWE-agent, Gemini CLI, Amp, and Docker CLI jobs. The menu bar has one `Enabled` toggle and one `Always Awake on Close` override.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jonathanpopham/clamshell-sentinel/main/scripts/install.sh)"
```

Or build from source:

```bash
git clone https://github.com/jonathanpopham/clamshell-sentinel.git
cd clamshell-sentinel
./scripts/install.sh
```

The installer builds `Clamshell Sentinel.app`, installs it into `~/Applications`, creates `~/.config/clamshell-sentinel/config.json`, and registers a user LaunchAgent so the menu bar app starts at login.

## How It Works

macOS has two relevant mechanisms:

- `pmset disablesleep`: when accepted by the OS, this is the setting that can keep a MacBook awake through lid close. Changing it requires admin permission, so macOS may show a password prompt the first time Sentinel needs to enable or disable it.
- `caffeinate -dimsu`: a fallback power assertion. It prevents idle/display sleep while Sentinel is active, but it is not a complete lid-close guarantee on every Mac.

Sentinel tries `pmset -a disablesleep 1` while a watched process is running or manual mode is enabled. When the process exits, or the app is disabled, it restores `pmset -a disablesleep 0` and stops the fallback assertion.

Run a local capability report with:

```bash
~/Applications/Clamshell\ Sentinel.app/Contents/MacOS/ClamshellSentinel --diagnose
```

## Configure Processes

Edit:

```bash
~/.config/clamshell-sentinel/config.json
```

Add a process:

```json
{
  "id": "release-build",
  "name": "Release build",
  "pattern": "(?i)make\\s+release",
  "enabled": true,
  "matchCommandLine": true
}
```

`pattern` is an `NSRegularExpression`. Leave `matchCommandLine` as `false` for executable/path-style matching, or set it to `true` for full terminal command matching.

See [docs/config.example.json](docs/config.example.json) for the default config.

## Local Development

```bash
make check
make app
make install
```

Useful commands:

```bash
swift run ClamshellSentinelChecks
swift run ClamshellSentinel --scan-once
swift run ClamshellSentinel --print-default-config
```

## Uninstall

```bash
./scripts/uninstall.sh
```

Use `--purge-config` to remove `~/.config/clamshell-sentinel`.

## macOS Only

This project is intentionally macOS-only. It is designed around `pmset`, `caffeinate`, LaunchAgents, and a native AppKit menu bar item.
