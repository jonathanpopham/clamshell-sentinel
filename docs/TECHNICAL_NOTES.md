# Technical Notes

Clamshell Sentinel is deliberately small because the useful behavior is mostly a power-management policy:

1. Scan the process table.
2. Decide whether any watched agent or job is active.
3. Set the system to stay awake only while needed.
4. Restore normal sleep behavior when the work stops.

## Lid Close vs Idle Sleep

`caffeinate` and I/O Kit power assertions are good at preventing idle sleep. Lid-close sleep is different: on many MacBooks, closing the lid is treated as a stronger hardware/user action than an idle timer.

For the clamshell-close case, Sentinel attempts:

```bash
pmset -a disablesleep 1
```

When no watched process is running, it attempts:

```bash
pmset -a disablesleep 0
```

That `pmset` setting is not shown in every local `man pmset` page or `pmset -g cap` output, so the app also starts a `caffeinate -dimsu` assertion as a fallback. The fallback helps with idle sleep but should not be treated as a universal clamshell guarantee.

## Why a User App Instead of a Privileged Daemon

A privileged LaunchDaemon could avoid repeated admin prompts, but it would make the first release much larger and more security-sensitive. This version keeps the trust boundary visible:

- The menu bar app runs as the user.
- `pmset` changes go through `sudo -n` when already authorized, then an AppleScript administrator prompt when needed.
- Config lives in `~/.config/clamshell-sentinel/config.json`.

If the project grows, a small audited privileged helper is the right next step.

## Process Matching

Default agent patterns use smart matching against the executable path and wrapper command lines. This avoids false positives like `rg codex README.md`.

For custom terminal jobs, set `matchCommandLine` to `true` so the regex runs against the full command line.
