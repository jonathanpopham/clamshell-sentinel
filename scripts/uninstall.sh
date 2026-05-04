#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
BUNDLE_ID="com.jonathanpopham.clamshell-sentinel"
APP_NAME="Clamshell Sentinel"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
CONFIG_DIR="$HOME/.config/clamshell-sentinel"
PURGE_CONFIG="0"

usage() {
  printf 'Usage: %s [--install-dir PATH] [--purge-config]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="${2:?missing path after --install-dir}"
      shift 2
      ;;
    --purge-config)
      PURGE_CONFIG="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
rm -f "$LAUNCH_AGENT"
rm -rf "$INSTALL_DIR/$APP_NAME.app"

if [[ "$PURGE_CONFIG" == "1" ]]; then
  rm -rf "$CONFIG_DIR"
fi

printf 'Removed Clamshell Sentinel.\n'
if [[ "$PURGE_CONFIG" != "1" ]]; then
  printf 'Config remains at %s.\n' "$CONFIG_DIR"
fi
