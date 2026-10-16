#!/usr/bin/env bash
# Shared helpers for Overbright scripts (ported from Cranny, ARCHITECTURE.md §8.7). Source it; do not execute it.
# Scripts run on /bin/bash 3.2: no `mapfile`, and guard empty arrays with ${arr[@]+"${arr[@]}"}.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Overbright.xcodeproj"
SCHEME="Overbright"
PACKAGE_DIR="$ROOT/Packages/OverbrightKit"
BUILD_DIR="$ROOT/build"
DERIVED_DIR="$BUILD_DIR/DerivedData"
# The intent declarations in App/Intents use `allowedExecutionTargets`, which only Xcode 27's SDK has
# (ARCHITECTURE.md header and §8.6). The package alone still builds with Xcode 26 (CI's macos-26 job).
MIN_XCODE_MAJOR=27
APP_NAME="Overbright"
CONTROLS_APPEX="OverbrightControls.appex"
# One SwiftPM cache for the clone and all its worktrees (ARCHITECTURE.md §10.0, disk budget): the parent directory
# of a worktree is the parent of the main clone. Every `swift build|test|package` call passes these flags.
SWIFTPM_CACHE="$(cd "$ROOT/.." && pwd)/.swiftpm-cache"
SWIFTPM_FLAGS=(--cache-path "$SWIFTPM_CACHE")

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Use a full Xcode even when `xcode-select -p` points at the Command Line Tools
# (common on dev machines; changing it needs sudo). DEVELOPER_DIR wins if set.
ensure_xcode() {
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    local selected
    selected="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$selected" != *.app/Contents/Developer ]]; then
      local candidate
      for candidate in /Applications/Xcode.app /Applications/Xcode-beta.app /Applications/Xcode_*.app /Applications/Xcode*.app; do
        if [[ -x "$candidate/Contents/Developer/usr/bin/xcodebuild" ]]; then
          export DEVELOPER_DIR="$candidate/Contents/Developer"
          break
        fi
      done
      [[ -n "${DEVELOPER_DIR:-}" ]] || die "Xcode not found. Install Xcode $MIN_XCODE_MAJOR+ or set DEVELOPER_DIR."
      log "xcode-select points to '$selected'; using DEVELOPER_DIR=$DEVELOPER_DIR"
    fi
  fi
  local version major
  version="$(xcodebuild -version 2>/dev/null | awk 'NR==1 {print $2}')" || true
  major="${version%%.*}"
  [[ -n "$major" ]] || die "xcodebuild is not usable (DEVELOPER_DIR=${DEVELOPER_DIR:-unset})."
  (( major >= MIN_XCODE_MAJOR )) || die "Xcode $version is too old; need $MIN_XCODE_MAJOR+."
}

# Pretty-print xcodebuild output when xcbeautify is installed (CI images have it).
xcpretty_filter() {
  if command -v xcbeautify >/dev/null 2>&1 && [[ "${VERBOSE:-0}" != 1 ]]; then
    xcbeautify --quieter
  else
    cat
  fi
}

# Read a key from a built app's Info.plist.
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"; }

# Whether the dormant Control Center extension ships (ARCHITECTURE.md D18, §7.7): CONTROLS=1 keeps it; the default is
# 1 when TEAM_ID is set (Developer ID builds) and 0 otherwise (ad-hoc builds).
controls_enabled() {
  local flag="${CONTROLS:-}"
  if [[ -z "$flag" ]]; then
    [[ -n "${TEAM_ID:-}" ]] && flag=1 || flag=0
  fi
  [[ "$flag" == 1 ]]
}

# Remove the Controls extension from a built app and re-sign the app with the identity and entitlements it was signed
# with (the target is always built, so it stays compile-checked; ARCHITECTURE.md §7.7, F1 §4.1). No-op when the app
# has no extension. $1 = path of Overbright.app.
drop_controls_extension() {
  local app="$1" appex="$1/Contents/PlugIns/$CONTROLS_APPEX" identity
  [[ -d "$appex" ]] || return 0
  rm -rf "$appex"
  rmdir "$app/Contents/PlugIns" 2>/dev/null || true
  identity="${SIGN_IDENTITY:--}"
  # Keep what Xcode signed: identifier, entitlements (Debug's get-task-allow included), flags and the hardened
  # runtime. Not the requirements: an ad-hoc designated requirement names the old cdhash.
  local flags=(--force --sign "$identity" --preserve-metadata=identifier,entitlements,flags,runtime)
  [[ "$identity" == - ]] || flags+=(--timestamp)
  codesign "${flags[@]}" "$app" || die "re-signing $app without the Controls extension failed"
  codesign --verify --deep --strict "$app" || die "code signature verification failed after removing the extension"
}

# Unregister a built app and its extension from LaunchServices and PlugInKit (every build registers them, and a dev
# copy can otherwise show up in the Control Center gallery; ARCHITECTURE.md §1.3). $@ = app paths; missing ones are
# skipped.
unregister_app() {
  local lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  local app appex
  for app in "$@"; do
    [[ -d "$app" ]] || continue
    for appex in "$app"/Contents/PlugIns/*.appex; do
      [[ -d "$appex" ]] && pluginkit -r "$appex" >/dev/null 2>&1 || true
    done
    "$lsregister" -u "$app" >/dev/null 2>&1 || true
  done
}
