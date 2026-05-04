APP_NAME := Clamshell Sentinel
EXECUTABLE := ClamshellSentinel
BUNDLE_ID := com.jonathanpopham.clamshell-sentinel
CONFIG_DIR := $(HOME)/.config/clamshell-sentinel
INSTALL_DIR ?= $(HOME)/Applications
BUILD_APP_DIR := .build/app
APP_DIR := $(BUILD_APP_DIR)/$(APP_NAME).app
RELEASE_DIR := .build/release
LAUNCH_AGENT := $(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist

.PHONY: all build check app install uninstall clean

all: app

build:
	swift build -c release

check:
	swift run ClamshellSentinelChecks

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp "$(RELEASE_DIR)/$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"
	cp "Sources/ClamshellSentinel/Resources/AppInfo.plist" "$(APP_DIR)/Contents/Info.plist"
	cp "Sources/ClamshellSentinel/Resources/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	cp "Sources/ClamshellSentinel/Resources/MenuIconTemplate.png" "$(APP_DIR)/Contents/Resources/MenuIconTemplate.png"
	codesign --force --deep --sign - "$(APP_DIR)" >/dev/null
	@echo "Built $(APP_DIR)"

install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_DIR)" "$(INSTALL_DIR)/$(APP_NAME).app"
	mkdir -p "$(CONFIG_DIR)" "$(HOME)/Library/LaunchAgents"
	"$(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(EXECUTABLE)" --print-default-config > "$(CONFIG_DIR)/config.json.tmp"
	if [ ! -f "$(CONFIG_DIR)/config.json" ]; then mv "$(CONFIG_DIR)/config.json.tmp" "$(CONFIG_DIR)/config.json"; else rm "$(CONFIG_DIR)/config.json.tmp"; fi
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>Label</key>' \
		'  <string>$(BUNDLE_ID)</string>' \
		'  <key>ProgramArguments</key>' \
		'  <array>' \
		'    <string>$(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(EXECUTABLE)</string>' \
		'  </array>' \
		'  <key>RunAtLoad</key>' \
		'  <true/>' \
		'  <key>KeepAlive</key>' \
		'  <false/>' \
		'</dict>' \
		'</plist>' > "$(LAUNCH_AGENT)"
	launchctl bootout "gui/$$(id -u)" "$(LAUNCH_AGENT)" >/dev/null 2>&1 || true
	launchctl bootstrap "gui/$$(id -u)" "$(LAUNCH_AGENT)"
	launchctl kickstart -k "gui/$$(id -u)/$(BUNDLE_ID)"
	@echo "Installed $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Config: $(CONFIG_DIR)/config.json"

uninstall:
	launchctl bootout "gui/$$(id -u)" "$(LAUNCH_AGENT)" >/dev/null 2>&1 || true
	rm -f "$(LAUNCH_AGENT)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed Clamshell Sentinel. Config remains at $(CONFIG_DIR)."

clean:
	rm -rf "$(BUILD_APP_DIR)"
	swift package clean
