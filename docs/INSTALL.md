# Install

Run one command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jonathanpopham/clamshell-sentinel/main/scripts/install.sh)"
```

That installs the app to `~/Applications`, starts it as a user LaunchAgent, and creates the editable watchlist at:

```bash
~/.config/clamshell-sentinel/watchlist.txt
```

Add one simple line per thing to watch:

```text
my-agent
command: make release
docker compose up
```

Save the file. Sentinel reloads it automatically within a few seconds.

Verify the install:

```bash
launchctl print "gui/$(id -u)/com.jonathanpopham.clamshell-sentinel"
~/Applications/Clamshell\ Sentinel.app/Contents/MacOS/ClamshellSentinel --scan-once
```

Uninstall:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jonathanpopham/clamshell-sentinel/main/scripts/uninstall.sh)"
```
