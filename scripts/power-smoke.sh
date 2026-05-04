#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

need /usr/bin/pmset
need /usr/bin/caffeinate
need /usr/bin/osascript
need /usr/bin/sudo

valid_output="$(
  /usr/bin/pmset -a disablesleep 1 2>&1 || true
)"

case "$valid_output" in
  *"must be run as root"*)
    printf 'ok: pmset recognizes disablesleep and requires root to change it\n'
    ;;
  *"Usage:"*)
    fail "pmset rejected disablesleep as an unknown setting"
    ;;
  *)
    printf '%s\n' "$valid_output"
    fail "unexpected pmset response for disablesleep"
    ;;
esac

invalid_output="$(
  /usr/bin/pmset -a clamshellsentinelnotasetting 1 2>&1 || true
)"

case "$invalid_output" in
  *"Usage:"*)
    printf 'ok: pmset still rejects unknown settings\n'
    ;;
  *)
    printf '%s\n' "$invalid_output"
    fail "unexpected pmset response for invalid setting"
    ;;
esac

caffeinate_help="$(
  /usr/bin/caffeinate -h 2>&1 || true
)"

case "$caffeinate_help" in
  *"usage: caffeinate"*)
    printf 'ok: caffeinate is available\n'
    ;;
  *)
    printf '%s\n' "$caffeinate_help"
    fail "unexpected caffeinate response"
    ;;
esac
