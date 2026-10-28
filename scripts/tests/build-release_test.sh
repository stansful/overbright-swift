#!/usr/bin/env bash
# Tests of scripts/build-release.sh against a fake tree in a temp dir (TMPDIR): never this repository, never Xcode,
# never a build or a launch of the app (D24). The fake root has the script, scripts/lib/{lib,version}.sh, a VERSION
# and a small Overbright.xcodeproj/project.pbxproj, plus stubs: scripts/lib/build.sh (writes build/Overbright.app of
# the version, the architectures and the signing it is asked for, or as STUB_* says), scripts/lib/smoke.sh,
# scripts/lib/dist.sh (the zip, the disk image and their .sha256 in dist/, with the faults STUB_DIST asks for) and
# scripts/lib/l10n/validate.py, which the real /usr/bin/python3 runs. The tools the script calls by name are stubs
# first in PATH: xcodebuild (-version), plutil, lipo and codesign (which read the fake app), xcrun (stapler validate),
# spctl and make. They sit in the usr/bin of a fake developer dir, DEVELOPER_DIR, so ensure_xcode never asks
# xcode-select; macOS's /usr/bin/python3, a shim that runs "$DEVELOPER_DIR/usr/bin/xcrun python3", gets through the
# xcrun stub to the real python3. Runs the script under $TEST_BASH (default: bash from PATH), on macOS and on Linux
# (the CI's ubuntu).
#
#   scripts/tests/build-release_test.sh          KEEP=1 keeps the temp dir
#
# Prints 'ok <name>' / 'not ok <name>: <why>' and exits non-zero on a failure.
# The conditions of check() are eval'd when it runs: single quotes on purpose, and the variables they read are
# set outside them.
# shellcheck disable=SC2016,SC2034
set -u
# SIGPIPE ignored, as on the GitHub runner (every step inherits that from its Node.js), for these tests and the
# scripts they run: a reader that stops early makes its writer fail with "Broken pipe" there instead of dying quietly
trap "" PIPE

HERE="$(cd "$(dirname "$0")" && pwd -P)"
TREE="$(cd "$HERE/../.." && pwd -P)"
BASH_BIN="${TEST_BASH:-bash}"
# no temp dir stops here: an empty WORK would make the current directory (the checkout) the work dir, and the
# EXIT trap would delete it
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/build-release-test.XXXXXX")" || ! WORK="$(cd "$WORK" && pwd -P)"; then
  echo "not ok no temp dir in ${TMPDIR:-/tmp}"
  exit 1
fi
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$WORK"' EXIT; else echo "# work dir: $WORK"; fi

# git, should anything run it, reads only this test's config (HOME is the temp dir) and finds no repository above it
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
export GIT_CEILING_DIRECTORIES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
# temp files of the scripts and the tools land in the temp dir too
mkdir -p "$HOME" "$WORK/tmp"
export TMPDIR="$WORK/tmp"

# The environment of every run: ad-hoc signing, no build number, no update check, no FILTER of the unit tests (make
# release-test FILTER=… would export one), no stub fault; a test changes a variable for one run with `VAR=value br ...`
unset SIGN_IDENTITY TEAM_ID NOTARY_PROFILE NOTARY_KEYCHAIN BUILD_NUMBER OVERBRIGHT_GITHUB_REPOSITORY CONTROLS SIMULATE
unset CONFIGURATION ARCHS MARKETING_VERSION REBUILD APP VERBOSE FILTER
unset STUB_XCODE STUB_MAKE_FAIL STUB_VALIDATE_RC STUB_PENDING
unset STUB_BUILD_FAIL STUB_APP_VERSION STUB_REPOSITORY STUB_ARCHS STUB_SIGNER STUB_TEAM STUB_RUNTIME
unset STUB_VERIFY_FAIL STUB_SMOKE_FAIL STUB_DIST STUB_STAPLER_FAIL STUB_SPCTL_FAIL
# the caller's DEVELOPER_DIR, for the real python3 behind the xcrun stub
export STUB_REAL_DEVELOPER_DIR="${DEVELOPER_DIR:-}"
export DEVELOPER_DIR="$WORK/developer" STUB_LOG="$WORK/stub.log"
STUBS="$DEVELOPER_DIR/usr/bin"
FAKE="$WORK/fake"
export PATH="$STUBS:$PATH"

V=1.2.3
ID="Developer ID Application: Jane Doe (TEAMID1234)"
TEAM=TEAMID1234
PBX=Overbright.xcodeproj/project.pbxproj
FILES="Overbright-$V.zip Overbright-$V.dmg Overbright-$V.sha256"

pass=0 fail=0
ok() {
  echo "ok $1"
  pass=$((pass + 1))
}
nok() {
  echo "not ok $1: $2"
  fail=$((fail + 1))
}
# check <name> <condition (eval'd)>: on failure prints the script's output and what the stubs logged
check() {
  if eval "$2"; then ok "$1"; else nok "$1" "rc=$RC; condition: $2; output:
$OUT
stubs:
$(cat "$STUB_LOG" 2>/dev/null)"; fi
}
has() { case $OUT in *"$1"*) return 0 ;; esac; return 1; }
logged() { grep -qxF -- "$1" "$STUB_LOG" 2>/dev/null; }
ran() { grep -q "^$1" "$STUB_LOG" 2>/dev/null; }
# built <MARKETING_VERSION> <BUILD_NUMBER> [<SIGN_IDENTITY> <TEAM_ID>]: build.sh got these, CONFIGURATION=Release and
# ARCHS="arm64 x86_64"
built() {
  local want="build.sh CONFIGURATION=Release ARCHS=arm64 x86_64 MARKETING_VERSION=$1 BUILD_NUMBER=$2"
  logged "$want SIGN_IDENTITY=${3-} TEAM_ID=${4-}"
}
# steps: the steps the stubs saw, in order, on one line: make <target>, validate.py, build.sh, smoke.sh, dist.sh
steps() {
  sed -n -E -e 's/^make \[([a-z]+)].*$/make \1/p' -e 's/^(validate\.py|build\.sh|smoke\.sh|dist\.sh)( .*)?$/\1/p' \
    "$STUB_LOG" 2>/dev/null | tr '\n' ' '
}
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}
# sums_ok <dir>: the .sha256 in dir lists the zip and the disk image, in this order, with their right sums
sums_ok() {
  [ "$(cat "$1/Overbright-$V.sha256")" = "$(cd "$1" && sha256 "Overbright-$V.zip" "Overbright-$V.dmg")" ] &&
    (cd "$1" && sha256 -c "Overbright-$V.sha256" >/dev/null 2>&1)
}
# same_files <dir> <dir>: the release files are the same in both
same_files() {
  local f
  for f in $FILES; do cmp -s "$1/$f" "$2/$f" || return 1; done
}
# listing <dir>: the names in dir, hidden ones too, sorted, one line
# shellcheck disable=SC2012 # the release files have plain names
listing() { (cd "$1" && ls -A | LC_ALL=C sort | tr '\n' ' '); }
sorted() { printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' ' '; }
# sizes_listed <dir>: the summary lists each release file of dir with its size, as the script prints it
sizes_listed() {
  local f
  for f in $FILES; do has "$(printf '  %10s  %s' "$(wc -c <"$1/$f" | tr -d ' ')" "$f")" || return 1; done
}
# sums_listed <dir>: the summary lists the sums of the zip and the disk image of dir
sums_listed() {
  has "SHA-256 (Overbright-$V.sha256):" && has "  $(cd "$1" && sha256 "Overbright-$V.zip")" &&
    has "  $(cd "$1" && sha256 "Overbright-$V.dmg")"
}
# also_in <dir>: the names on the summary's line "Also in <dir>, not part of the release:", sorted, one line; fails
# without that line
also_in() {
  local line
  line="$(printf '%s\n' "$OUT" | grep -F "Also in $1, not part of the release:")" || return 1
  printf '%s\n' "${line#"Also in $1, not part of the release:"}" | tr ' ' '\n' | grep . | LC_ALL=C sort | tr '\n' ' '
}

# --- the stubs: the tools, in the fake developer dir
mkdir -p "$STUBS" "$FAKE"
cat >"$STUBS/xcodebuild" <<'EOF'
#!/bin/sh
# xcodebuild stub: -version only (ensure_xcode), Xcode STUB_XCODE (default 27.0); it builds nothing
echo "xcodebuild $*" >>"$STUB_LOG"
if [ "$*" = -version ]; then
  printf 'Xcode %s\nBuild version 27A5000\n' "${STUB_XCODE:-27.0}"
  exit 0
fi
echo "xcodebuild stub: no build here ($*)" >&2
exit 64
EOF
cat >"$STUBS/plutil" <<'EOF'
#!/bin/sh
# plutil stub: plutil -extract <key> raw -o - <plist>, from the "<key>…</key><string>…</string>" lines the build.sh
# stub writes
echo "plutil $*" >>"$STUB_LOG"
if [ $# != 6 ] || [ "$1" != -extract ] || [ "$3 $4 $5" != "raw -o -" ]; then
  echo "plutil stub: unexpected arguments: $*" >&2
  exit 64
fi
if ! line=$(grep -F "<key>$2</key>" "$6" 2>/dev/null); then
  echo "$6: Could not extract value, error: No value at that key path or invalid key path: $2" >&2
  exit 1
fi
printf '%s\n' "$line" | sed 's|.*<string>\(.*\)</string>.*|\1|'
EOF
cat >"$STUBS/lipo" <<'EOF'
#!/bin/sh
# lipo stub: lipo -archs <binary> prints the "archs:" line the build.sh stub writes into the fake binary
echo "lipo $*" >>"$STUB_LOG"
if [ $# != 2 ] || [ "$1" != -archs ]; then
  echo "lipo stub: unexpected arguments: $*" >&2
  exit 64
fi
archs=$(sed -n 's/^archs: //p' "$2" 2>/dev/null)
if [ -z "$archs" ]; then
  echo "fatal error: lipo: can't figure out the architecture type of: $2" >&2
  exit 1
fi
echo "$archs"
EOF
cat >"$STUBS/codesign" <<'EOF'
#!/bin/sh
# codesign stub: --verify --deep --strict <app> (STUB_VERIFY_FAIL=1 fails it) and -dv --verbose=2 <app>, which prints
# on stderr, as codesign does, the signature the build.sh stub wrote into the fake app
echo "codesign $*" >>"$STUB_LOG"
for app; do :; done
if [ ! -d "$app" ]; then
  echo "$app: No such file or directory" >&2
  exit 1
fi
case $1 in
--verify)
  if [ -n "${STUB_VERIFY_FAIL:-}" ]; then
    echo "$app: a sealed resource is missing or invalid" >&2
    exit 1
  fi
  ;;
-dv)
  echo "Executable=$app/Contents/MacOS/Overbright" >&2
  cat "$app/Contents/stub-signature" >&2
  ;;
*)
  echo "codesign stub: unexpected arguments: $*" >&2
  exit 64
  ;;
esac
EOF
cat >"$STUBS/xcrun" <<'EOF'
#!/bin/sh
# xcrun stub: xcrun stapler validate <file> (STUB_STAPLER_FAIL=app or dmg: that file has no ticket). macOS's
# /usr/bin shims (python3, make, lipo, xcodebuild, ...) run "$DEVELOPER_DIR/usr/bin/xcrun <tool> <args>", which is
# this stub: python3 goes on to the real one (the shim again, with the caller's DEVELOPER_DIR), and every other tool is
# refused, so no real Xcode tool runs here
if [ "${1:-}" = python3 ]; then
  shift
  if [ -n "${STUB_REAL_DEVELOPER_DIR:-}" ]; then
    DEVELOPER_DIR=$STUB_REAL_DEVELOPER_DIR
    export DEVELOPER_DIR
  else
    unset DEVELOPER_DIR
  fi
  exec /usr/bin/python3 "$@"
fi
echo "xcrun $*" >>"$STUB_LOG"
if [ $# = 3 ] && [ "$1 $2" = "stapler validate" ]; then
  case ${STUB_STAPLER_FAIL:-}:$3 in
  app:*.app | dmg:*.dmg)
    echo "$3 does not have a ticket stapled to it."
    exit 65
    ;;
  esac
  printf 'Processing: %s\nThe validate action worked!\n' "$3"
  exit 0
fi
echo "xcrun: error: unable to find utility \"$1\" (the xcrun stub runs none)" >&2
exit 72
EOF
cat >"$STUBS/spctl" <<'EOF'
#!/bin/sh
# spctl stub: spctl --assess --type execute <app> (STUB_SPCTL_FAIL=1 rejects it)
echo "spctl $*" >>"$STUB_LOG"
for app; do :; done
if [ -n "${STUB_SPCTL_FAIL:-}" ]; then
  echo "$app: rejected" >&2
  exit 3
fi
EOF
cat >"$STUBS/make" <<'EOF'
#!/bin/sh
# make stub (--test): logs its arguments, each in brackets, where it runs and the FILTER of its environment, if any
# (in make, an argument FILTER=… overrides that one); STUB_MAKE_FAIL=lint or test fails that target
line=make
for arg; do line="$line [$arg]"; done
line="$line in $(pwd)"
[ -z "${FILTER+set}" ] || line="$line, FILTER=$FILTER in the environment"
printf '%s\n' "$line" >>"$STUB_LOG"
if [ -n "${STUB_MAKE_FAIL:-}" ] && [ "$1" = "$STUB_MAKE_FAIL" ]; then
  echo "make: *** [$1] Error 1" >&2
  exit 2
fi
EOF

# --- the stubs: the fake tree's scripts
cat >"$FAKE/build.sh" <<'EOF'
#!/bin/sh
# scripts/lib/build.sh stub: logs the environment it got and what dist/ holds when it starts, then writes
# build/Overbright.app as Xcode would build it from that environment: Contents/Info.plist (CFBundleShortVersionString
# MARKETING_VERSION, CFBundleVersion BUILD_NUMBER or 1, OverbrightGitHubRepository), Contents/MacOS/Overbright (an
# "archs:" line for the lipo stub: ARCHS), the signature the codesign stub prints (SIGN_IDENTITY's for TEAM_ID, else
# ad-hoc; the hardened runtime on) and Contents/PlugIns/OverbrightControls.appex with CONTROLS=1 (default: 1 with
# TEAM_ID). Built otherwise: STUB_APP_VERSION (another version), STUB_REPOSITORY (another repository), STUB_ARCHS,
# STUB_SIGNER and STUB_TEAM (another signature), STUB_RUNTIME=off (no hardened runtime). STUB_BUILD_FAIL=1 fails before
# building.
root=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
echo "build.sh CONFIGURATION=${CONFIGURATION-} ARCHS=${ARCHS-} MARKETING_VERSION=${MARKETING_VERSION-}" \
  "BUILD_NUMBER=${BUILD_NUMBER-} SIGN_IDENTITY=${SIGN_IDENTITY-} TEAM_ID=${TEAM_ID-}" >>"$STUB_LOG"
echo "dist/ before the build:$(cd "$root/dist" 2>/dev/null && ls -A | LC_ALL=C sort | sed 's/^/ /' | tr -d '\n')" \
  >>"$STUB_LOG"
if [ -n "${STUB_BUILD_FAIL:-}" ]; then
  echo "** BUILD FAILED **" >&2
  exit 65
fi
app="$root/build/Overbright.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Overbright</string>
  <key>CFBundleShortVersionString</key><string>${STUB_APP_VERSION:-${MARKETING_VERSION-}}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER:-1}</string>
  <key>OverbrightGitHubRepository</key><string>${STUB_REPOSITORY:-${OVERBRIGHT_GITHUB_REPOSITORY-}}</string>
</dict>
</plist>
PLIST
archs=${STUB_ARCHS:-${ARCHS-}}
echo "archs: $archs" >"$app/Contents/MacOS/Overbright"
signer=${STUB_SIGNER:-${SIGN_IDENTITY-}}
team=${STUB_TEAM:-${TEAM_ID-}}
{
  echo "Identifier=app.overbright.Overbright"
  echo "Format=app bundle with Mach-O universal ($archs)"
  if [ -z "$signer" ]; then
    if [ "${STUB_RUNTIME:-}" = off ]; then flags='0x2(adhoc)'; else flags='0x10002(adhoc,runtime)'; fi
    echo "CodeDirectory v=20500 size=4242 flags=$flags hashes=121+7 location=embedded"
    echo "Signature=adhoc"
    echo "Info.plist entries=24"
    echo "TeamIdentifier=not set"
  else
    if [ "${STUB_RUNTIME:-}" = off ]; then flags='0x0(none)'; else flags='0x10000(runtime)'; fi
    echo "CodeDirectory v=20500 size=4242 flags=$flags hashes=121+7 location=embedded"
    echo "Signature size=9046"
    echo "Authority=$signer"
    echo "Authority=Developer ID Certification Authority"
    echo "Authority=Apple Root CA"
    echo "Timestamp=28 Oct 2026 at 12:00:00"
    echo "Info.plist entries=24"
    echo "TeamIdentifier=${team:-not set}"
  fi
  echo "Sealed Resources version=2 rules=13 files=118"
  echo "Internal requirements count=1 size=212"
} >"$app/Contents/stub-signature"
controls=${CONTROLS:-}
if [ -z "$controls" ]; then
  if [ -n "${TEAM_ID:-}" ]; then controls=1; else controls=0; fi
fi
[ "$controls" != 1 ] || mkdir -p "$app/Contents/PlugIns/OverbrightControls.appex"
exit 0
EOF
cat >"$FAKE/smoke.sh" <<'EOF'
#!/bin/sh
# scripts/lib/smoke.sh stub: logs the app it is given (APP) and launches nothing; STUB_SMOKE_FAIL=1 fails it
echo "smoke.sh APP=${APP-}" >>"$STUB_LOG"
if [ -n "${STUB_SMOKE_FAIL:-}" ]; then
  echo "error: Overbright --diagnostics failed or timed out" >&2
  exit 1
fi
EOF
cat >"$FAKE/dist.sh" <<'EOF'
#!/bin/sh
# scripts/lib/dist.sh stub: logs REBUILD and NOTARY_PROFILE, then writes dist/Overbright-<the fake app's version>.zip
# and .dmg and their sums in .sha256 (sha256sum or shasum -a 256), as the real one does. It removes nothing first: what
# an earlier build left in dist/ stays there unless build-release.sh removed it. STUB_DIST: nozip, nodmg, nosums (that
# file is not written), extra (the .sha256 lists a third file), renamed (the .sha256 names the disk image
# Overbright.dmg), binary (sums in binary mode, "<sum> *<name>"), corrupt (the disk image changes after its sum), fail
# (exits 1 after writing all three)
root=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
echo "dist.sh REBUILD=${REBUILD-} NOTARY_PROFILE=${NOTARY_PROFILE-}" >>"$STUB_LOG"
v=$(sed -n 's|.*<key>CFBundleShortVersionString</key><string>\(.*\)</string>.*|\1|p' \
  "$root/build/Overbright.app/Contents/Info.plist")
name="Overbright-$v"
sums() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}
mkdir -p "$root/dist" && cd "$root/dist" || exit 1
[ "${STUB_DIST:-}" = nozip ] || echo "zip of Overbright $v" >"$name.zip"
[ "${STUB_DIST:-}" = nodmg ] || echo "disk image of Overbright $v" >"$name.dmg"
set --
for f in "$name.zip" "$name.dmg"; do
  [ ! -e "$f" ] || set -- "$@" "$f"
done
case ${STUB_DIST:-} in
nosums) ;;
binary) sums -b "$@" >"$name.sha256" ;;
extra)
  echo "installer of Overbright $v" >"$name.pkg"
  sums "$@" "$name.pkg" >"$name.sha256"
  ;;
renamed) sums "$@" | sed "s/ $name\\.dmg\$/ Overbright.dmg/" >"$name.sha256" ;;
*) sums "$@" >"$name.sha256" ;;
esac
[ "${STUB_DIST:-}" != corrupt ] || echo corrupt >>"$name.dmg"
[ "${STUB_DIST:-}" != fail ]
EOF
cat >"$FAKE/validate.py" <<'EOF'
# scripts/lib/l10n/validate.py stub, run by the real /usr/bin/python3: logs its arguments; exits with
# STUB_VALIDATE_RC (default 0), a shipped language without a translation whatever the arguments. STUB_PENDING=1:
# strings pending translation, which the real one refuses only with --release (exit 1 then)
import os
import sys

with open(os.environ["STUB_LOG"], "a", encoding="utf-8") as log:
    log.write(" ".join(["validate.py"] + sys.argv[1:]) + "\n")
status = int(os.environ.get("STUB_VALIDATE_RC") or 0)
if status:
    print("de: 2 strings without a translation", file=sys.stderr)
elif os.environ.get("STUB_PENDING") and "--release" in sys.argv[1:]:
    print("de: 2 strings pending translation (needs_review): translate them before a release", file=sys.stderr)
    status = 1
sys.exit(status)
EOF
chmod +x "$STUBS"/* "$FAKE"/*.sh

echo "# scripts/build-release.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"')," \
  "$(/usr/bin/python3 --version 2>&1)"

# pbxproj [version...]: a small project.pbxproj, a build configuration with its MARKETING_VERSION line per version
pbxproj() {
  local v n=0
  printf '// !$*UTF8*$!\n{\n\tobjects = {\n'
  for v; do
    n=$((n + 1))
    printf '\t\t%024d /* Config %d */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n' "$n" "$n"
    printf '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n\t\t\t\tMARKETING_VERSION = %s;\n\t\t\t};\n\t\t};\n' "$v"
  done
  printf '\t};\n}\n'
}
# new_root <name>: a fake tree ROOT with the script, its libraries and the stubs, VERSION V and the project at V (two
# configurations); APP is its app, DIST its dist/
new_root() {
  ROOT="$WORK/$1"
  APP="$ROOT/build/Overbright.app"
  DIST="$ROOT/dist"
  mkdir -p "$ROOT/scripts/lib/l10n" "$ROOT/Overbright.xcodeproj"
  cp "$TREE/scripts/build-release.sh" "$ROOT/scripts/"
  cp "$TREE/scripts/lib/lib.sh" "$TREE/scripts/lib/version.sh" "$FAKE/build.sh" "$FAKE/smoke.sh" "$FAKE/dist.sh" \
    "$ROOT/scripts/lib/"
  cp "$FAKE/validate.py" "$ROOT/scripts/lib/l10n/"
  echo "$V" >"$ROOT/VERSION"
  pbxproj "$V" "$V" >"$ROOT/$PBX"
}
ESC="$(printf '\033')"
# br [args...]: build-release.sh of ROOT, run from WORK with a fresh stub log; sets RC, and OUT to its stdout and
# stderr without the colours of lib.sh's log, warn and die
br() {
  rm -f "$STUB_LOG"
  (cd "$WORK" && "$BASH_BIN" "$ROOT/scripts/build-release.sh" "$@") >"$WORK/output" 2>&1
  RC=$?
  OUT="$(sed "s/$ESC\\[[0-9;]*m//g" "$WORK/output")"
}
# devid / notarized: br with Developer ID signing, and notarized too
devid() { SIGN_IDENTITY="$ID" TEAM_ID="$TEAM" br; }
notarized() { SIGN_IDENTITY="$ID" TEAM_ID="$TEAM" NOTARY_PROFILE=overbright-notary br; }

# --- an ad-hoc release build
new_root main
BUILD_NUMBER=4242 br
check "ad-hoc build: exit 0" '[ $RC = 0 ]'
check "...build.sh gets CONFIGURATION=Release, ARCHS=\"arm64 x86_64\", MARKETING_VERSION from VERSION, BUILD_NUMBER" \
  'built "$V" 4242'
check "...the translations, the build, the smoke test, the packaging, in this order" \
  '[ "$(steps)" = "validate.py build.sh smoke.sh dist.sh " ]'
MSG="==> Translations: every shipped language complete, nothing pending"
check "...validate.py --shipped --release --quiet: nothing may be pending translation" \
  'logged "validate.py --shipped --release --quiet" && has "$MSG (scripts/lib/l10n/validate.py --shipped --release)"'
check "...smoke.sh gets APP=<root>/build/Overbright.app" 'logged "smoke.sh APP=$APP"'
check "...dist.sh gets REBUILD=0: it packages the app checked here, no build of its own" \
  'logged "dist.sh REBUILD=0 NOTARY_PROFILE="'
check "...the app is checked: its version, its architectures, its signature (strict)" \
  'logged "plutil -extract CFBundleShortVersionString raw -o - $APP/Contents/Info.plist" &&
   logged "lipo -archs $APP/Contents/MacOS/Overbright" && logged "codesign --verify --deep --strict $APP" &&
   logged "codesign -dv --verbose=2 $APP"'
check "...no make without --test, no stapler or Gatekeeper check without NOTARY_PROFILE" \
  '! ran make && ! ran xcrun && ! ran spctl'
check "...dist/ holds exactly the three release files, with the right sums" \
  '[ "$(listing "$DIST")" = "$(sorted $FILES)" ] && sums_ok "$DIST"'
check "...the summary: the version, the build number, dist/, each file with its size" \
  'has "Release $V (build 4242): $DIST" && sizes_listed "$DIST"'
check "...the summary: ad-hoc signing, the update check off, the extension removed; no hardened runtime line" \
  'has "Signing: ad-hoc; users allow the app once with \"Open Anyway\"" && ! has "hardened runtime" &&
   has "Update check: off (OVERBRIGHT_GITHUB_REPOSITORY not set; release.yml sets its repository)" &&
   has "Control Center extension: removed (CONTROLS=1 keeps it)"'
check "...the summary: the sums" 'sums_listed "$DIST"'
check "...the progress names the build and the signing" \
  'has "==> Release $V: scripts/lib/build.sh (Release, arm64 x86_64), signing: ad-hoc"'
check "...no warning, no other files, no --allow-pending note" \
  '! has "warning:" && ! has "not part of the release" && ! has "--allow-pending"'
check "...nothing written outside the fake root" '[ -z "$(ls -A "$HOME")" ] && [ -z "$(ls -A "$TMPDIR")" ]'

new_root 'my project'
br
check "a root path with a space builds" \
  '[ $RC = 0 ] && [ "$(listing "$DIST")" = "$(sorted $FILES)" ] && sums_ok "$DIST" && logged "smoke.sh APP=$APP"'

# --- what the build puts in the app: the update check, the Control Center extension
new_root options
OVERBRIGHT_GITHUB_REPOSITORY=owner/overbright CONTROLS=1 br
check "OVERBRIGHT_GITHUB_REPOSITORY, CONTROLS=1: the summary names the update check's repository, the extension kept" \
  '[ $RC = 0 ] && has "Update check: owner/overbright" && has "Control Center extension: kept"'
STUB_REPOSITORY=owner/overbright br
check "...the update check named is the app's own (its Info.plist), not the environment's" \
  '[ $RC = 0 ] && has "Update check: owner/overbright"'

# --- the translations: validate.py, --allow-pending
new_root pending
MSG="a shipped language lacks translations or has strings pending translation (scripts/lib/l10n/README.md)."
MSG="$MSG --allow-pending builds with pending strings; a release never does."
INVALID="a shipped language lacks translations or has invalid ones (scripts/lib/l10n/README.md)."
STUB_VALIDATE_RC=1 br
check "a shipped language without a translation (validate.py fails): stopped before the build" \
  '[ $RC = 1 ] && has "error: $MSG" && logged "validate.py --shipped --release --quiet" && ! ran build.sh &&
   [ ! -e "$DIST" ]'
STUB_PENDING=1 br
check "strings pending translation (validate.py --release fails): stopped before the build" \
  '[ $RC = 1 ] && has "error: $MSG" && logged "validate.py --shipped --release --quiet" && ! ran build.sh &&
   [ ! -e "$DIST" ]'
STUB_VALIDATE_RC=1 br --allow-pending
check "--allow-pending: a shipped language without a translation (validate.py --shipped fails) still stops the build" \
  '[ $RC = 1 ] && has "error: $INVALID" && ! has "--allow-pending builds" && [ "$(steps)" = "validate.py " ] &&
   logged "validate.py --shipped --quiet" && [ ! -e "$DIST" ] && ! has "Translations: strings pending"'
STUB_PENDING=1 br --allow-pending
ALLOWED="pending strings allowed (scripts/lib/l10n/validate.py --shipped)"
check "--allow-pending: strings pending translation build; validate.py --shipped --quiet first (no --release)" \
  '[ $RC = 0 ] && logged "validate.py --shipped --quiet" &&
   [ "$(steps)" = "validate.py build.sh smoke.sh dist.sh " ] &&
   has "==> Translations: every shipped language complete, $ALLOWED"'
check "...the summary says so" \
  'has "Translations: strings pending translation allowed (--allow-pending); a release refuses them"'

# --- --test
new_root checks
br --test
check "--test: make lint, then make test FILTER= (every unit test) in the root, before the translations and the build" \
  '[ $RC = 0 ] && [ "$(steps)" = "make lint make test validate.py build.sh smoke.sh dist.sh " ] &&
   logged "make [lint] in $ROOT" && logged "make [test] [FILTER=] in $ROOT" && has "==> Checks: make lint" &&
   has "==> Unit tests: make test"'
FILTER=SomeSuite br --test
check "--test with FILTER=SomeSuite in the environment: still make test FILTER=, which overrides it in make" \
  '[ $RC = 0 ] && logged "make [test] [FILTER=] in $ROOT, FILTER=SomeSuite in the environment" &&
   [ "$(steps)" = "make lint make test validate.py build.sh smoke.sh dist.sh " ]'
STUB_MAKE_FAIL="lint" br --test
check "--test: a failing make lint stops everything" \
  '[ $RC = 1 ] && has "error: make lint failed." && [ "$(steps)" = "make lint " ]'
STUB_MAKE_FAIL="test" br --test
check "--test: failing unit tests stop the build" \
  '[ $RC = 1 ] && has "error: the unit tests failed." && [ "$(steps)" = "make lint make test " ]'

# --- --out DIR
new_root outroot
mkdir -p "$WORK/out"
echo notes >"$WORK/out/notes.txt"
echo hidden >"$WORK/out/.hidden"
echo older >"$WORK/out/Overbright-1.2.2.zip"
echo stale >"$WORK/out/Overbright-$V.zip"
br --out out
check "--out DIR (relative to the current directory): the three release files copied there, with the right sums" \
  '[ $RC = 0 ] && same_files "$DIST" "$WORK/out" && sums_ok "$WORK/out" &&
   [ "$(listing "$DIST")" = "$(sorted $FILES)" ]'
check "...the summary is about DIR, and names its other files as not part of the release" \
  'has "Release $V (build 1): $WORK/out" && sizes_listed "$WORK/out" &&
   [ "$(also_in "$WORK/out")" = "$(sorted .hidden Overbright-1.2.2.zip notes.txt)" ]'
check "...and leaves them alone" \
  '[ "$(cat "$WORK/out/notes.txt")" = notes ] && [ "$(cat "$WORK/out/.hidden")" = hidden ] &&
   [ "$(cat "$WORK/out/Overbright-1.2.2.zip")" = older ]'
br "--out=$WORK/out 2/new"
check "--out=DIR, a new DIR in a new directory (a path with a space): made, exactly the three release files" \
  '[ $RC = 0 ] && [ "$(listing "$WORK/out 2/new")" = "$(sorted $FILES)" ] && sums_ok "$WORK/out 2/new" &&
   has "Release $V (build 1): $WORK/out 2/new" && ! has "not part of the release"'
NEW="$WORK/new/nested/dir"
br --out new/nested/dir
check "--out DIR, a new DIR three levels down (relative): made, the release files copied there, its full path named" \
  '[ $RC = 0 ] && [ "$(listing "$NEW")" = "$(sorted $FILES)" ] && same_files "$DIST" "$NEW" && sums_ok "$NEW" &&
   has "Release $V (build 1): $NEW" && sizes_listed "$NEW" && ! has "not part of the release"'
br --out "$DIST"
check "--out dist/ itself: nothing copied, the summary is about dist/" \
  '[ $RC = 0 ] && has "Release $V (build 1): $DIST" && [ "$(listing "$DIST")" = "$(sorted $FILES)" ] &&
   ! has "not part of the release"'
br --out
check "--out without DIR is a usage error (exit 2), before anything runs" \
  '[ $RC = 2 ] && has "error: --out needs a directory" &&
   has "scripts/build-release.sh [--test] [--allow-pending] [--out DIR]" && [ ! -s "$STUB_LOG" ]'
br --out ''
check "--out '' is a usage error" '[ $RC = 2 ] && has "error: --out needs a directory" && [ ! -s "$STUB_LOG" ]'
br --out=
check "--out= is a usage error" '[ $RC = 2 ] && has "error: " && [ ! -s "$STUB_LOG" ]'
br --out "$WORK/never made" --bogus
check "a usage error after --out DIR: DIR is not made (every option is read first)" \
  '[ $RC = 2 ] && has "error: unknown option --bogus" && [ ! -e "$WORK/never made" ] && [ ! -s "$STUB_LOG" ]'

# --- --out that is no directory this script can write to: refused before anything runs, so nothing is built
new_root outfile
echo text >"$WORK/a file"
br --out "$WORK/a file"
check "--out a regular file fails before anything runs (no build.sh): nothing built, the file left as it is" \
  '[ $RC = 1 ] && has "error: --out $WORK/a file is not a directory this script can write to." &&
   [ ! -s "$STUB_LOG" ] && [ ! -e "$ROOT/build" ] && [ ! -e "$DIST" ] && [ "$(cat "$WORK/a file")" = text ]'
br "--out=$WORK/a file/new"
check "--out=DIR below a regular file fails the same way" \
  '[ $RC = 1 ] && has "error: --out $WORK/a file/new is not a directory this script can write to." &&
   [ ! -s "$STUB_LOG" ] && [ ! -e "$ROOT/build" ] && [ ! -e "$DIST" ] && [ "$(cat "$WORK/a file")" = text ]'
mkdir "$WORK/read-only"
chmod 555 "$WORK/read-only"
if [ -w "$WORK/read-only" ]; then
  echo "# skipped: --out a directory without write permission (this user can write to it all the same, as root does)"
else
  br --out "$WORK/read-only"
  check "--out a directory without write permission fails the same way" \
    '[ $RC = 1 ] && has "error: --out $WORK/read-only is not a directory this script can write to." &&
     [ ! -s "$STUB_LOG" ] && [ ! -e "$ROOT/build" ] && [ ! -e "$DIST" ] && [ -z "$(ls -A "$WORK/read-only")" ]'
fi
chmod 755 "$WORK/read-only"
mkdir "$WORK/no entry"
chmod 600 "$WORK/no entry"
if (cd "$WORK/no entry" 2>/dev/null); then
  echo "# skipped: --out a directory this user cannot enter (this user enters it all the same, as root does)"
else
  br --out "$WORK/no entry"
  check "--out a directory this user cannot enter fails the same way, and the message still names it" \
    '[ $RC = 1 ] && has "error: --out $WORK/no entry is not a directory this script can write to." &&
     [ ! -s "$STUB_LOG" ] && [ ! -e "$ROOT/build" ] && [ ! -e "$DIST" ]'
fi
chmod 755 "$WORK/no entry"

# --- an exported CDPATH with a scripts/lib of its own: run as scripts/build-release.sh from the root, lib.sh's ROOT is
# this tree all the same (cd would otherwise follow the CDPATH and print where it went)
new_root cdpath
mkdir -p "$WORK/elsewhere/scripts/lib"
rm -f "$STUB_LOG"
(cd "$ROOT" && CDPATH="$WORK/elsewhere" BUILD_NUMBER=9 "$BASH_BIN" scripts/build-release.sh) >"$WORK/output" 2>&1
RC=$?
OUT="$(sed "s/$ESC\\[[0-9;]*m//g" "$WORK/output")"
check "an exported CDPATH with a scripts/lib of its own: scripts/build-release.sh builds this tree" \
  '[ $RC = 0 ] && built "$V" 9 && has "Release $V (build 9): $DIST"'

# --- usage
br -h
check "-h prints the usage, exit 0, nothing runs" \
  '[ $RC = 0 ] && has "scripts/build-release.sh [--test] [--allow-pending] [--out DIR]" &&
   has "--allow-pending  build even when strings are pending translation" && [ ! -s "$STUB_LOG" ]'
br --help
check "--help prints the usage" \
  '[ $RC = 0 ] && has "scripts/build-release.sh [--test] [--allow-pending] [--out DIR]" && [ ! -s "$STUB_LOG" ]'
br --bogus
check "an unknown option is a usage error (exit 2)" \
  '[ $RC = 2 ] && has "error: unknown option --bogus" && has "scripts/build-release.sh [--test]" &&
   [ ! -s "$STUB_LOG" ]'
br 1.2.3
check "an argument is a usage error" '[ $RC = 2 ] && has "error: unknown option 1.2.3" && [ ! -s "$STUB_LOG" ]'

# --- dist/: what an earlier build left there, what dist.sh writes
new_root stale
mkdir -p "$DIST"
for f in "Overbright-$V.zip" "Overbright-$V.dmg" notarize-upload.zip Overbright-1.2.2.zip; do
  echo "earlier $f" >"$DIST/$f"
done
(cd "$DIST" && sha256 "Overbright-$V.zip" "Overbright-$V.dmg" >"Overbright-$V.sha256")
STUB_DIST=nodmg br
check "the files of this version an earlier build left in dist/ are gone before the build (another version's stay)" \
  'logged "dist/ before the build: Overbright-1.2.2.zip"'
check "...so a dist.sh that writes no disk image fails: dist/ lacks it" \
  '[ $RC = 1 ] && has "error: dist/ lacks: Overbright-$V.dmg." && ! has "Release $V (build"'
br
check "...the next build names the other version's file in dist/ as not part of the release, and leaves it" \
  '[ $RC = 0 ] && [ "$(also_in "$DIST")" = "$(sorted Overbright-1.2.2.zip)" ] &&
   [ "$(cat "$DIST/Overbright-1.2.2.zip")" = "earlier Overbright-1.2.2.zip" ]'

new_root faults
for c in nozip:zip nodmg:dmg nosums:sha256; do
  STUB_DIST=${c%:*} br
  check "a dist.sh that writes no .${c#*:} fails: dist/ lacks it" \
    '[ $RC = 1 ] && has "error: dist/ lacks: Overbright-$V.${c#*:}." && ! has "Release $V (build"'
done
WANTED="instead of Overbright-$V.dmg Overbright-$V.zip."
STUB_DIST=extra br
check "a .sha256 that lists a third file fails" \
  '[ $RC = 1 ] && ! has "Release $V (build" &&
   has "error: Overbright-$V.sha256 lists Overbright-$V.dmg Overbright-$V.pkg Overbright-$V.zip $WANTED"'
STUB_DIST=renamed br
check "a .sha256 that names another file fails" \
  '[ $RC = 1 ] && has "error: Overbright-$V.sha256 lists Overbright-$V.zip Overbright.dmg $WANTED"'
STUB_DIST=corrupt br
check "a file that does not match its sum fails" \
  '[ $RC = 1 ] && has "error: the files in dist/ do not match Overbright-$V.sha256." && ! has "Release $V (build"'
STUB_DIST=binary br
check "sums in binary mode (\"<sum> *<name>\") are fine" '[ $RC = 0 ] && has "Release $V (build 1): $DIST"'
STUB_DIST=fail br
check "a failing dist.sh fails the build" '[ $RC != 0 ] && ran dist.sh && ! has "Release $V (build"'

# --- what build.sh built, wrong
new_root app
STUB_APP_VERSION=1.2.4 br
check "an app of another version than VERSION fails, before the smoke test" \
  '[ $RC = 1 ] && has "error: $APP is version 1.2.4, not $V." && ! ran smoke.sh && ! ran dist.sh'
STUB_ARCHS=arm64 br
check "an app without x86_64 fails" \
  '[ $RC = 1 ] && has "error: $APP is built for arm64, not arm64 and x86_64." && ! ran smoke.sh'
STUB_ARCHS=x86_64 br
check "an app without arm64 fails" \
  '[ $RC = 1 ] && has "error: $APP is built for x86_64, not arm64 and x86_64." && ! ran smoke.sh'
STUB_VERIFY_FAIL=1 br
check "an app whose signature does not verify (codesign --verify --deep --strict) fails" \
  '[ $RC = 1 ] && has "error: the code signature of $APP does not verify." && ! ran smoke.sh'
STUB_RUNTIME=off br
check "an app without the hardened runtime fails, ad-hoc signed too, before the smoke test" \
  '[ $RC = 1 ] && has "error: $APP is signed without the hardened runtime." && ! ran smoke.sh && ! ran dist.sh &&
   ! has "Release $V (build"'
STUB_SIGNER="Apple Development: Jane Doe (ABCDE12345)" STUB_TEAM=ABCDE12345 br
check "an app that is not ad-hoc signed, without SIGN_IDENTITY, fails" \
  '[ $RC = 1 ] && has "error: $APP is not ad-hoc signed, although SIGN_IDENTITY is not set." && ! ran smoke.sh'
STUB_BUILD_FAIL=1 br
check "a failing build.sh fails the build, before the checks of the app" \
  '[ $RC != 0 ] && ran build.sh && ! ran lipo && ! ran smoke.sh && ! ran dist.sh'
STUB_SMOKE_FAIL=1 br
check "a failing smoke test fails the build, before the packaging" '[ $RC != 0 ] && ran smoke.sh && ! ran dist.sh'

# --- the signing variables: both or neither, notarization only with them
new_root signing
SIGN_IDENTITY="$ID" br
check "SIGN_IDENTITY without TEAM_ID fails before the build" \
  '[ $RC = 1 ] && ! ran build.sh &&
   has "error: set both SIGN_IDENTITY and TEAM_ID for Developer ID signing, or neither for an ad-hoc signed build."'
TEAM_ID="$TEAM" br
check "TEAM_ID without SIGN_IDENTITY fails before the build" \
  '[ $RC = 1 ] && has "error: set both SIGN_IDENTITY and TEAM_ID" && ! ran build.sh'
NOTARY_PROFILE=overbright-notary br
check "NOTARY_PROFILE without SIGN_IDENTITY fails before the build" \
  '[ $RC = 1 ] && ! ran build.sh &&
   has "error: NOTARY_PROFILE needs SIGN_IDENTITY and TEAM_ID: Apple notarizes Developer ID builds only."'

# --- Developer ID
BUILD_NUMBER=7 devid
check "Developer ID: exit 0, build.sh gets SIGN_IDENTITY and TEAM_ID" '[ $RC = 0 ] && built "$V" 7 "$ID" "$TEAM"'
check "...the summary: the Authority and team, not notarized, the extension kept (TEAM_ID); no hardened runtime line" \
  'has "Release $V (build 7): $DIST" && has "Signing: $ID (team $TEAM)" &&
   has "  not notarized (no NOTARY_PROFILE): Gatekeeper asks users to allow the app" &&
   ! has "hardened runtime" && has "Control Center extension: kept" &&
   has "signing: Developer ID ($ID), not notarized (no NOTARY_PROFILE)"'
check "...no stapler or Gatekeeper check without NOTARY_PROFILE" \
  '! ran xcrun && ! ran spctl && logged "dist.sh REBUILD=0 NOTARY_PROFILE="'
STUB_TEAM=OTHERTEAM9 devid
check "Developer ID: an app signed for another team than TEAM_ID fails" \
  '[ $RC = 1 ] && has "error: $APP is signed for team OTHERTEAM9, not $TEAM." && ! ran smoke.sh'
STUB_RUNTIME=off devid
check "Developer ID: an app without the hardened runtime fails" \
  '[ $RC = 1 ] && has "error: $APP is signed without the hardened runtime." && ! ran smoke.sh &&
   ! has "Release $V (build"'

# --- notarized
new_root notary
notarized
check "notarized: exit 0, dist.sh gets NOTARY_PROFILE" \
  '[ $RC = 0 ] && logged "dist.sh REBUILD=0 NOTARY_PROFILE=overbright-notary"'
check "...the stapled tickets of the app and the disk image are validated, Gatekeeper is asked about the app" \
  'logged "xcrun stapler validate $APP" && logged "xcrun stapler validate $DIST/Overbright-$V.dmg" &&
   logged "spctl --assess --type execute $APP"'
check "...the summary says notarized; no hardened runtime line" \
  'has "Signing: $ID (team $TEAM)" && has "  notarized, the ticket stapled to the app and the disk image" &&
   has "signing: Developer ID ($ID), notarized" && ! has "hardened runtime"'
STUB_STAPLER_FAIL=app notarized
check "notarized: an app without a valid stapled ticket fails" \
  '[ $RC = 1 ] && has "error: $APP has no valid stapled notarization ticket." && ! has "Release $V (build"'
STUB_STAPLER_FAIL=dmg notarized
check "notarized: a disk image without a valid stapled ticket fails" \
  '[ $RC = 1 ] && has "error: $DIST/Overbright-$V.dmg has no valid stapled notarization ticket." &&
   ! has "Release $V (build"'
STUB_SPCTL_FAIL=1 notarized
check "notarized: an app Gatekeeper rejects fails" \
  '[ $RC = 1 ] && has "error: Gatekeeper does not accept $APP (spctl --assess)." && ! has "Release $V (build"'

# --- VERSION, and the project's MARKETING_VERSION
new_root version
for bad in 1.2 v1.2.3 01.2.3 1.2.3.4 1.2.3-rc1 1000000000.0.0; do
  echo "$bad" >"$ROOT/VERSION"
  br
  MSG="VERSION holds '$bad', not X.Y.Z (no leading zeros, no 'v', at most 9 digits per number)."
  check "VERSION '$bad' fails before the build" '[ $RC = 1 ] && has "error: $MSG" && ! ran build.sh'
done
MSG="VERSION must hold the version alone, one line X.Y.Z."
printf '%s\n%s\n' "$V" "$V" >"$ROOT/VERSION"
br
check "a VERSION of two lines fails before the build" '[ $RC = 1 ] && has "error: $MSG" && ! ran build.sh'
: >"$ROOT/VERSION"
br
check "an empty VERSION fails before the build" '[ $RC = 1 ] && has "error: $MSG" && ! ran build.sh'
rm -f "$ROOT/VERSION"
br
check "no VERSION fails before the build" '[ $RC = 1 ] && has "error: $MSG" && ! ran build.sh'
printf ' %s \r\n\n' "$V" >"$ROOT/VERSION"
br
check "VERSION with blanks, CRLF and an empty line around the version: that version is built" \
  '[ $RC = 0 ] && has "Release $V (build 1): $DIST" && built "$V" ""'

new_root project
pbxproj 1.2.2 1.2.2 >"$ROOT/$PBX"
br
MSG="$PBX has MARKETING_VERSION 1.2.2; the release is $V (VERSION), and scripts/make-release.sh sets both."
check "a project.pbxproj MARKETING_VERSION other than VERSION only warns; the release is VERSION's" \
  '[ $RC = 0 ] && has "warning: $MSG" && has "Release $V (build 1): $DIST" && built "$V" ""'
pbxproj "$V" 1.2.2 >"$ROOT/$PBX"
br
check "...two different MARKETING_VERSIONs: both named" \
  '[ $RC = 0 ] && has "warning: $PBX has MARKETING_VERSION $V 1.2.2;"'
pbxproj >"$ROOT/$PBX"
br
check "a project.pbxproj without MARKETING_VERSION: no warning" '[ $RC = 0 ] && ! has "warning:"'

# --- Xcode
new_root xcode
STUB_XCODE=26.4 br
check "an Xcode older than 27 fails before the build" \
  '[ $RC = 1 ] && has "error: Xcode 26.4 is too old; need 27+." && ! ran build.sh'

echo "# $pass passed, $fail failed"
[ "$fail" = 0 ]
