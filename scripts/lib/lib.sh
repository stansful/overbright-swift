#!/usr/bin/env bash
# Shared helpers for Overbright scripts (ported from Cranny, ARCHITECTURE.md §8.7). Source it; do not execute it.
# Scripts run on /bin/bash 3.2: no `mapfile`, and guard empty arrays with ${arr[@]+"${arr[@]}"}.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT/Overbright.xcodeproj"
SCHEME="Overbright"
PACKAGE_DIR="$ROOT/Packages/OverbrightKit"
BUILD_DIR="$ROOT/build"
DERIVED_DIR="$BUILD_DIR/DerivedData"
# The intent declarations in App/Intents use `allowedExecutionTargets`, which only Xcode 27's SDK has
# (ARCHITECTURE.md header and §8.6). The package alone still builds with Xcode 26.
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
  pluginkit -r "$appex" >/dev/null 2>&1 || true     # Xcode registered it with PlugInKit when it built it
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

# The read-only measurement tools of scripts/lib/perf.sh and scripts/lib/soak.sh (ARCHITECTURE.md §8.7, energy work H2),
# built from source into $1 when missing or when their source changed (no binary in the repository); sets PIDSTAT,
# SESSION and CONTROL. Nothing here attaches to a process:
# - pidstat <pid…>: proc_pid_rusage (RUSAGE_INFO_V4) and proc_pidinfo of each process, one line each:
#   <pid> <epoch_ms> <cpu_ns> <pkg_idle_wkups> <interrupt_wkups> <phys_footprint_B> <resident_B> <threads>
#   <billed_energy_nJ> <instructions> <cycles> (`<pid> <epoch_ms> NA` for a process that is gone); no argument: epoch ms;
# - sessionstate: "locked=<0|1> onConsole=<0|1>" from CGSessionCopyCurrentDictionary;
# - appchurn <file>: one line `<epoch_ms> <launch|quit|activate>` per app that starts, quits or is activated on this
#   Mac (what Signals' running-list observer sees), until it is terminated (counts only: no name or bundle ID);
# - PerfControl.app: scripts/lib/soak-control.swift, the control app run beside Overbright (`--follow <pid>`).
build_perf_tools() {
  local dir="$1"
  mkdir -p "$dir"
  PIDSTAT="$dir/pidstat"; SESSION="$dir/sessionstate"; APPCHURN="$dir/appchurn"; CONTROL="$dir/PerfControl.app"
  _source_into "$dir/pidstat.c" <<'C'
// pidstat: read-only counters of processes (proc_pid_rusage, proc_pidinfo); never attaches. No arguments: epoch ms.
//   <pid> <epoch_ms> <cpu_ns> <pkg_idle_wkups> <interrupt_wkups> <phys_footprint_B> <resident_B> <threads>
//   <billed_energy_nJ> <instructions> <cycles>
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/time.h>
int main(int argc, char **argv) {
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    struct timeval tv; gettimeofday(&tv, NULL);
    long long ms = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
    if (argc == 1) { printf("%lld\n", ms); return 0; }
    int status = 0;
    for (int i = 1; i < argc; i++) {
        int pid = atoi(argv[i]);
        struct rusage_info_v4 ru;
        if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&ru) != 0) { printf("%d %lld NA\n", pid, ms); status = 1; continue; }
        struct proc_taskinfo ti; int threads = -1;
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, sizeof ti) == (int)sizeof ti) threads = ti.pti_threadnum;
        unsigned long long cpu = (ru.ri_user_time + ru.ri_system_time) * tb.numer / tb.denom;   // ticks → ns
        printf("%d %lld %llu %llu %llu %llu %llu %d %llu %llu %llu\n", pid, ms, cpu,
               (unsigned long long)ru.ri_pkg_idle_wkups, (unsigned long long)ru.ri_interrupt_wkups,
               (unsigned long long)ru.ri_phys_footprint, (unsigned long long)ru.ri_resident_size, threads,
               (unsigned long long)ru.ri_billed_energy, (unsigned long long)ru.ri_instructions,
               (unsigned long long)ru.ri_cycles);
    }
    return status;
}
C
  if [[ ! -x "$PIDSTAT" || "$dir/pidstat.c" -nt "$PIDSTAT" ]]; then
    xcrun clang -O2 -Wall -o "$PIDSTAT" "$dir/pidstat.c" || die "pidstat did not build"
  fi
  _source_into "$dir/sessionstate.swift" <<'SWIFT'
// sessionstate: "locked=<0|1> onConsole=<0|1>" from CGSessionCopyCurrentDictionary (read-only).
import CoreGraphics
let d = (CGSessionCopyCurrentDictionary() as? [String: Any]) ?? [:]
let locked = (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
let console = (d[kCGSessionOnConsoleKey as String] as? Bool) ?? false
print("locked=\(locked ? 1 : 0) onConsole=\(console ? 1 : 0)")
SWIFT
  if [[ ! -x "$SESSION" || "$dir/sessionstate.swift" -nt "$SESSION" ]]; then
    xcrun swiftc -O -o "$SESSION" "$dir/sessionstate.swift" || die "sessionstate did not build"
  fi
  _source_into "$dir/appchurn.swift" <<'SWIFT'
// appchurn <file>: appends `<epoch_ms> <launch|quit|activate>` for every app that starts or quits on this Mac (KVO on
// NSWorkspace.runningApplications, which agents and background apps change too, as Signals observes it) and every
// activation (NSWorkspace's notification), until it is terminated. Counts only: no name or bundle ID. Read-only.
import AppKit
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/dev/stdout"
if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
guard let out = FileHandle(forWritingAtPath: path) else { exit(1) }
out.seekToEndOfFile()
func note(_ kind: String, _ count: Int = 1) {
    let ms = Int64(Date().timeIntervalSince1970 * 1000)
    for _ in 0..<count { out.write(Data("\(ms) \(kind)\n".utf8)) }
}
let running = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new]) { _, change in
    let old = Set((change.oldValue ?? []).map(\.processIdentifier))
    let new = Set((change.newValue ?? []).map(\.processIdentifier))
    note("launch", new.subtracting(old).count)
    note("quit", old.subtracting(new).count)
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                  object: nil, queue: .main) { _ in note("activate") }
RunLoop.main.run()
SWIFT
  if [[ ! -x "$APPCHURN" || "$dir/appchurn.swift" -nt "$APPCHURN" ]]; then
    xcrun swiftc -O -o "$APPCHURN" "$dir/appchurn.swift" || die "appchurn did not build"
  fi
  _source_into "$dir/soak-control.swift" < "$ROOT/scripts/lib/soak-control.swift"
  if [[ ! -x "$CONTROL/Contents/MacOS/PerfControl" || "$dir/soak-control.swift" -nt "$CONTROL/Contents/MacOS/PerfControl" ]]; then
    rm -rf "$CONTROL"; mkdir -p "$CONTROL/Contents/MacOS"
    xcrun swiftc -swift-version 6 -O -o "$CONTROL/Contents/MacOS/PerfControl" "$dir/soak-control.swift" \
      || die "the control did not build"
    cat > "$CONTROL/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>PerfControl</string>
  <key>CFBundleIdentifier</key><string>app.overbright.perf-control</string>
  <key>CFBundleName</key><string>PerfControl</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
    codesign -s - --force "$CONTROL" >/dev/null 2>&1 || die "the control could not be signed"
  fi
}

# Writes standard input to $1 only when it differs from what is there, so a tool is rebuilt when its source changed.
_source_into() {
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if cmp -s "$tmp" "$1"; then rm -f "$tmp"; else mv "$tmp" "$1"; fi
}

# ARCHITECTURE.md §8.5: nothing a QA run does writes the app's own preferences domain. perf.sh and soak.sh export it
# before and after (read-only: `defaults export`; a domain that does not exist exports as an empty dictionary) and fail
# when it changed. They never delete or rewrite it: a key a run left there stays until its owner removes it.
APP_DOMAIN="app.overbright.Overbright"
app_domain_export() {   # <file>
  defaults export "$APP_DOMAIN" - > "$1" 2>/dev/null || : > "$1"
}
# 0 when the domain still reads as in <file>; otherwise prints what changed during <label> and returns 1.
app_domain_unchanged() {   # <file> <label>
  local now
  now="$(mktemp)"
  app_domain_export "$now"
  if cmp -s "$1" "$now"; then rm -f "$now"; return 0; fi
  warn "the app's own preferences domain $APP_DOMAIN changed during $2 (ARCHITECTURE.md §8.5; another QA run on this Mac may have written it; nothing was deleted):"
  diff "$1" "$now" >&2 || true
  rm -f "$now"
  return 1
}
