#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/jonathanpopham/clamshell-sentinel/archive/refs/heads/main.tar.gz"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"

usage() {
  printf 'Usage: %s [--install-dir PATH]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="${2:?missing path after --install-dir}"
      shift 2
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

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

need swift
need make
need curl

if [[ -f Package.swift && -f scripts/install.sh ]]; then
  repo_root="$PWD"
  cleanup=""
else
  tmpdir="$(mktemp -d)"
  cleanup="$tmpdir"
  curl -fsSL "$REPO_URL" | tar -xz -C "$tmpdir" --strip-components 1
  repo_root="$tmpdir"
fi

finish() {
  if [[ -n "${cleanup:-}" ]]; then
    rm -rf "$cleanup"
  fi
}
trap finish EXIT

make -C "$repo_root" install INSTALL_DIR="$INSTALL_DIR"
