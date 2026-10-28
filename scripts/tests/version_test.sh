#!/usr/bin/env bash
# Tests of scripts/lib/version.sh: every function runs in a fresh $TEST_BASH (default: bash from PATH, /bin/bash 3.2
# on macOS) that sourced it under `set -euo pipefail`, as the scripts that source it run. Files go to a temp dir
# (TMPDIR), with a throwaway git repository for real `git tag` and `git ls-remote --tags` output; git reads only this
# test's config (HOME is the temp dir). The repository is only read: its VERSION, and whether there is an
# Overbright.xcodeproj/project.pbxproj. (workflows_test.sh checks that dist.sh makes the files release_assets names.)
#
#   scripts/tests/version_test.sh          KEEP=1 keeps the temp dir
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
LIB="$TREE/scripts/lib/version.sh"
BASH_BIN="${TEST_BASH:-bash}"
# no temp dir stops here: an empty WORK would make the current directory (the checkout) the work dir, and the
# EXIT trap would delete it
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/version-test.XXXXXX")" || ! WORK="$(cd "$WORK" && pwd -P)"; then
  echo "not ok no temp dir in ${TMPDIR:-/tmp}"
  exit 1
fi
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$WORK"' EXIT; else echo "# work dir: $WORK"; fi

export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
# git never finds a repository above the temp dir (a TMPDIR inside some checkout), nor takes a repository or config
# from the caller's environment (a git hook's GIT_DIR, a GIT_CONFIG_GLOBAL)
GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
export GIT_CEILING_DIRECTORIES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_CONFIG_GLOBAL GIT_CONFIG_PARAMETERS \
  GIT_CONFIG_COUNT
mkdir -p "$HOME"
# the temp files of app_version_set and project_version_set land here: the test checks that none is left behind
mkdir -p "$WORK/tmp"
export TMPDIR="$WORK/tmp"

pass=0 fail=0 RC='' OUT='' ERR=''
ok() {
  echo "ok $1"
  pass=$((pass + 1))
}
nok() {
  echo "not ok $1: $2"
  fail=$((fail + 1))
}
check() {
  if eval "$2"; then ok "$1"; else nok "$1" "rc=$RC; condition: $2; stdout: '$OUT'; stderr: '$ERR'"; fi
}
# fn <stdin (printf %b)> <function> [args...]: the function in a fresh BASH_BIN that sourced version.sh under
# set -euo pipefail; sets OUT, ERR, RC. stderr comes through the command substitution, which waits for every
# process holding it: a process substitution's late error lands in this ERR, not in a later one's
fn() {
  local input="$1"
  shift
  ERR="$(printf '%b' "$input" | "$BASH_BIN" -c 'set -euo pipefail; . "$0"; "$@"' "$LIB" "$@" 2>&1 >"$WORK/out")"
  RC=$?
  OUT="$(cat "$WORK/out")"
}
# fn_file <file> <function> [args...]: fn with the file as stdin, byte for byte
fn_file() {
  local input="$1"
  shift
  ERR="$("$BASH_BIN" -c 'set -euo pipefail; . "$0"; "$@"' "$LIB" "$@" <"$input" 2>&1 >"$WORK/out")"
  RC=$?
  OUT="$(cat "$WORK/out")"
}
# is <name> <rc> <stdout>: the last fn exited with rc and printed exactly stdout, and nothing on stderr
is() {
  if [ "$RC" = "$2" ] && [ "$OUT" = "$3" ] && [ -z "$ERR" ]; then
    ok "$1"
  else
    nok "$1" "want rc=$2 stdout '$3'; got rc=$RC stdout '$OUT' stderr '$ERR'"
  fi
}
lines() { printf '%s\n' "$@"; }
sorted() { printf '%s\n' "$1" | LC_ALL=C sort; }
# ls -l and ls -i, of plain names: the portable way to the mode and the inode (stat differs on BSD and GNU)
# shellcheck disable=SC2012
mode() { ls -l "$1" | cut -c1-10; }
# shellcheck disable=SC2012
inode() { ls -i "$1" | awk '{ print $1 }'; }

echo "# scripts/lib/version.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"'), $(git --version)"

# --- version_valid: X.Y.Z, three numbers without leading zeros, at most 9 digits each
for v in 0.0.0 0.0.1 0.1.0 1.0.0 1.2.3 10.20.30 100000000.0.0 0.100000000.0 0.0.100000000 \
  999999999.999999999.999999999; do
  fn '' version_valid "$v"
  is "version_valid: $v is a version" 0 ''
done
for v in '' 1 1.2 1.2.3.4 1.2.3.4.5 01.2.3 1.02.3 1.2.03 00.0.0 0.00.0 0.0.00 000000001.0.0 v1.2.3 V1.2.3 vv1.2.3 \
  ' 1.2.3' '1.2.3 ' $'\t1.2.3' $'1.2.3\t' $'1.2.3\n' $'\n1.2.3' $'1.2.3\r' $'1.2.3\n4.5.6' '1. 2.3' '1.2.3 1.2.3' \
  1000000000.0.0 0.1000000000.0 0.0.1000000000 9999999999.9999999999.9999999999 1.2.3-rc1 1.2.3+b a.b.c 1..3 .1.2 \
  1.2. -1.2.3 +1.2.3 1,2,3 '١.٢.٣'; do
  fn '' version_valid "$v"
  is "version_valid: $(printf '%q' "$v") is not a version" 1 ''
done

# --- version_cmp, version_gt: numbers, not strings
for c in "1.2.3 1.2.3 0" "0.0.0 0.0.0 0" "1.2.3 1.2.4 -1" "1.2.4 1.2.3 1" "1.2.3 1.3.0 -1" "2.0.0 1.9.9 1" \
  "1.10.0 1.9.9 1" "1.9.9 1.10.0 -1" "1.2.10 1.2.9 1" "1.2.9 1.2.10 -1" "2.0.0 10.0.0 -1" "10.0.0 9.99.999 1" \
  "1.0.0 0.999999999.999999999 1" "100000000.0.0 99999999.0.0 1" "0.0.99999999 0.0.100000000 -1" \
  "123456789.0.0 123456788.999999999.999999999 1" "999999999.999999999.999999998 999999999.999999999.999999999 -1" \
  "999999999.999999999.999999999 999999999.999999999.999999999 0"; do
  read -r a b want <<<"$c"
  fn '' version_cmp "$a" "$b"
  is "version_cmp $a $b = $want" 0 "$want"
done
fn '' version_gt 1.10.0 1.9.9
is "version_gt: 1.10.0 > 1.9.9 (numbers, not strings)" 0 ''
fn '' version_gt 1.9.9 1.10.0
is "version_gt: 1.9.9 is not > 1.10.0" 1 ''
fn '' version_gt 1.2.3 1.2.3
is "version_gt: 1.2.3 is not > 1.2.3" 1 ''
fn '' version_gt 10.0.0 9.999999999.999999999
is "version_gt: 10.0.0 > 9.999999999.999999999 (the longer number is the larger)" 0 ''
fn '' version_gt 999999999.0.0 999999998.999999999.999999999
is "version_gt: 999999999.0.0 > 999999998.999999999.999999999 (9 digits)" 0 ''

# --- version_bump
for c in "1.2.3 patch 1.2.4" "1.2.3 minor 1.3.0" "1.2.3 major 2.0.0" "0.0.0 patch 0.0.1" "0.0.0 minor 0.1.0" \
  "0.0.0 major 1.0.0" "0.1.9 patch 0.1.10" "0.9.9 minor 0.10.0" "9.9.9 major 10.0.0" \
  "1.2.999999998 patch 1.2.999999999" "1.999999998.3 minor 1.999999999.0" "999999998.2.3 major 999999999.0.0"; do
  read -r a k want <<<"$c"
  fn '' version_bump "$a" "$k"
  is "version_bump $a $k = $want" 0 "$want"
done
# a bump to 10 digits is still printed, and version_valid refuses it: make-release.sh offers only the valid bumps
for c in "1.2.999999999 patch 1.2.1000000000" "1.999999999.3 minor 1.1000000000.0" \
  "999999999.2.3 major 1000000000.0.0"; do
  read -r a k want <<<"$c"
  fn '' version_bump "$a" "$k"
  bumped=$OUT bump_rc=$RC
  fn '' version_valid "$bumped"
  check "version_bump $a $k = $want, which version_valid refuses (10 digits)" \
    '[ "$bump_rc" = 0 ] && [ "$bumped" = "$want" ] && [ $RC = 1 ]'
done
for k in bogus '' Patch MINOR 'patch ' major+ патч; do
  fn '' version_bump 1.2.3 "$k"
  is "version_bump: '$k' is not a bump" 1 ''
done

# --- app_version_parse, app_version_get: VERSION holds the version alone, its one non-blank line
for c in 'a plain line|1.2.3\n' 'no final newline|1.2.3' 'CRLF|1.2.3\r\n' 'blanks around the version| \t 1.2.3\t \n' \
  'blank lines around it|\n \n\t\n1.2.3\n\n \t \n' 'CRLF and blanks, blank lines around it|\r\n \r\n 1.2.3 \r\n\r\n'; do
  fn "${c#*|}" app_version_parse
  is "app_version_parse: ${c%%|*}" 0 1.2.3
done
# carriage returns are blanks like spaces and tabs, any number of them, at both ends of a line: a line of nothing else
# is blank
for c in 'two carriage returns before the newline (0.1.0\r\r\n)|0.1.0\r\r\n' \
  'carriage returns before the version|\r\r0.1.0\n' \
  'carriage returns among the spaces and tabs at both ends| \r\t0.1.0\r \t\r\n' \
  'lines of carriage returns alone around it|\r\r\n0.1.0\n\r\n \r \n'; do
  fn "${c#*|}" app_version_parse
  is "app_version_parse: ${c%%|*}" 0 0.1.0
done
fn 'v1.2.3-rc1 \n' app_version_parse
is "app_version_parse: the value is not checked (version_valid does that)" 0 v1.2.3-rc1
for c in 'two non-blank lines|1.2.3\n1.2.4\n' 'two equal lines|1.2.3\n1.2.3\n' \
  'two lines among blank lines|\n1.2.3\n \n1.2.4\n\n' 'an empty file|' 'a blank file| \n\t\n\n' \
  'only CRLFs|\r\n\r\n' 'only two carriage returns (\r\r\n)|\r\r\n' \
  'only a carriage return between spaces ( \r \n)| \r \n'; do
  fn "${c#*|}" app_version_parse
  is "app_version_parse fails, printing nothing: ${c%%|*}" 1 ''
done

ROOT="$WORK/root"
mkdir -p "$ROOT/Overbright.xcodeproj"
printf '\n 1.2.3\r\n\n' >"$ROOT/VERSION"
fn '' app_version_get "$ROOT"
is "app_version_get: app_version_parse of <root>/VERSION" 0 1.2.3
fn '' app_version_get "$WORK/missing"
check "app_version_get: a missing VERSION fails, printing nothing on stdout" '[ $RC != 0 ] && [ -z "$OUT" ]'

# --- app_version_set: in place, only the version line; nothing changes on a refusal
F="$ROOT/VERSION"
printf '\n \n1.2.3\n\t\n\n' >"$F"
printf '\n \n1.3.0\n\t\n\n' >"$WORK/expected"
chmod 640 "$F"
before_mode=$(mode "$F") before_inode=$(inode "$F")
fn '' app_version_set "$ROOT" 1.3.0
is "app_version_set: writes 1.3.0, printing nothing" 0 ''
check "...into the version line; the blank lines around it stay byte for byte" 'cmp -s "$F" "$WORK/expected"'
check "...the file keeps its mode and inode" \
  '[ "$(mode "$F")" = "$before_mode" ] && [ "$(inode "$F")" = "$before_inode" ]'
check "...no temp file is left in TMPDIR" '[ -z "$(ls -A "$WORK/tmp")" ]'
fn '' app_version_get "$ROOT"
is "...app_version_get reads it back" 0 1.3.0
for c in 'blanks around the version|\t 1.2.3 \n' 'CRLF|1.2.3\r\n' 'no final newline|1.2.3' \
  'two carriage returns before the newline|0.1.0\r\r\n'; do
  printf '%b' "${c#*|}" >"$F"
  fn '' app_version_set "$ROOT" 1.3.0
  set_rc=$RC
  fn '' app_version_get "$ROOT"
  check "app_version_set: ${c%%|*}: app_version_get reads 1.3.0 back" \
    '[ "$set_rc" = 0 ] && [ $RC = 0 ] && [ "$OUT" = 1.3.0 ]'
done
# blank to app_version_parse, blank to app_version_set: the version goes into the version line alone
printf '\r\r\n1.2.3\n \r \n' >"$F"
printf '\r\r\n1.3.0\n \r \n' >"$WORK/expected"
fn '' app_version_set "$ROOT" 1.3.0
check "app_version_set: lines of carriage returns alone are blank lines; they stay byte for byte" \
  '[ $RC = 0 ] && [ -z "$OUT$ERR" ] && cmp -s "$F" "$WORK/expected"'

printf '1.3.0\n' >"$F"
cp "$F" "$WORK/before"
for v in '' 1.4 v1.4.0 01.4.0 1.4.0-rc1 ' 1.4.0' '1.4.0 ' $'1.4.0\n2.0.0' 1000000000.0.0; do
  fn '' app_version_set "$ROOT" "$v"
  check "app_version_set: $(printf '%q' "$v") is refused, printing nothing; the file is unchanged" \
    '[ $RC = 1 ] && [ -z "$OUT$ERR" ] && cmp -s "$F" "$WORK/before"'
done
for c in 'two non-blank lines|1.2.3\n1.2.4\n' 'two equal lines|1.2.3\n\n1.2.3\n' 'only blank lines|\n \t\r\n' \
  'nothing in it|' 'only two carriage returns (\r\r\n)|\r\r\n' \
  'only a carriage return between spaces ( \r \n)| \r \n'; do
  printf '%b' "${c#*|}" >"$F"
  cp "$F" "$WORK/before"
  fn '' app_version_set "$ROOT" 2.0.0
  check "app_version_set: a VERSION with ${c%%|*} is refused and stays byte for byte the same" \
    '[ $RC = 1 ] && [ -z "$OUT$ERR" ] && cmp -s "$F" "$WORK/before"'
done
check "...no temp file is left in TMPDIR" '[ -z "$(ls -A "$WORK/tmp")" ]'
printf '1.3.0\n' >"$F"
cp "$F" "$WORK/before"
TMPDIR="$WORK/no-tmp"
fn '' app_version_set "$ROOT" 2.0.0
TMPDIR="$WORK/tmp"
check "app_version_set: no temp file to be had (TMPDIR missing): fails, the file unchanged" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && cmp -s "$F" "$WORK/before"'
# its directory exists, so the file could be created
mkdir -p "$WORK/missing/Overbright.xcodeproj"
fn '' app_version_set "$WORK/missing" 2.0.0
check "app_version_set: a missing VERSION fails and is not created" \
  '[ $RC != 0 ] && [ -z "$OUT" ] && [ ! -e "$WORK/missing/VERSION" ]'

# --- project_versions, project_version_lines, project_version_set: the MARKETING_VERSION lines of project.pbxproj
# pbx <value> <value> <value>: a project.pbxproj in short whose three MARKETING_VERSION lines hold these values (the
# app's Debug and Release configurations, the Controls extension's); its other lines only mention MARKETING_VERSION
pbx() {
  printf '// !$*UTF8*$!
{
\tobjects = {
\t\tAAAA /* Debug */ = {
\t\t\tbuildSettings = {
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tINFOPLIST_KEY_CFBundleShortVersionString = "$(MARKETING_VERSION)";
\t\t\t\tMARKETING_VERSION = %s;
\t\t\t\tMARKETING_VERSION_SUFFIX = beta;
\t\t\t};
\t\t};
\t\tBBBB /* Release */ = {
\t\t\tbuildSettings = {
\t\t\t\tMARKETING_VERSION = %s;
\t\t\t};
\t\t};
\t\tCCCC /* Release */ = {
\t\t\tbuildSettings = {
\t\t\t\tMARKETING_VERSION = %s;
\t\t\t\tPRODUCT_NAME = OverbrightControls;
\t\t\t};
\t\t};
\t};
}
' "$1" "$2" "$3"
}
# no_version_lines: pbx without its MARKETING_VERSION lines
no_version_lines() { pbx @ @ @ | grep -vF 'MARKETING_VERSION = @;'; }

P="$ROOT/Overbright.xcodeproj/project.pbxproj"
pbx 0.1.0 '"0.2.0"' 0.1.0 >"$P"
fn_file "$P" project_versions
is "project_versions: each value once, in order of appearance, without its quotes" 0 "$(lines 0.1.0 0.2.0)"
pbx '"0.3.0"' 0.2.0 0.3.0 >"$WORK/pbx"
fn_file "$WORK/pbx" project_versions
is "project_versions: not sorted; \"0.3.0\" and 0.3.0 are one value" 0 "$(lines 0.3.0 0.2.0)"
fn ' \t MARKETING_VERSION\t=\t"1.2.3" ; \t\n' project_versions
is "project_versions: blanks around the parts of the line" 0 1.2.3
no_version_lines >"$WORK/pbx"
fn_file "$WORK/pbx" project_versions
is "project_versions: nothing without a MARKETING_VERSION line (lines that only mention it are none)" 0 ''
fn '' project_versions
is "project_versions: nothing for no input" 0 ''

# project_version_lines <X.Y.Z>: how many lines project_version_set changes. That writes "= X.Y.Z;" after what precedes
# the "=", so a MARKETING_VERSION line counts unless it reads exactly "<prefix>= X.Y.Z;": one that holds X.Y.Z in
# quotes, spaced otherwise or with blanks after the ";" is rewritten, so it counts
for c in "0.1.0 1" "0.2.0 3" "0.3.0 3"; do
  read -r v want <<<"$c"
  fn_file "$P" project_version_lines "$v"
  is "project_version_lines $v: $want, of the lines 0.1.0, \"0.2.0\", 0.1.0 (\"0.2.0\" is rewritten without quotes)" \
    0 "$want"
done
for c in 'as Xcode writes it|\t\t\t\tMARKETING_VERSION = 0.2.0;\n' \
  'no blank before the "=" (MARKETING_VERSION= 0.2.0;)|MARKETING_VERSION= 0.2.0;\n' \
  'blanks before and after the name| \t MARKETING_VERSION\t= 0.2.0;\n'; do
  fn "${c#*|}" project_version_lines 0.2.0
  is "project_version_lines 0.2.0: 0 for a line that reads exactly \"<prefix>= 0.2.0;\", ${c%%|*}" 0 0
done
for c in 'MARKETING_VERSION=0.2.0;|MARKETING_VERSION=0.2.0;\n' \
  'two blanks after the ";" (MARKETING_VERSION = 0.2.0;  )|MARKETING_VERSION = 0.2.0;  \n' \
  'a tab after the ";"|\t\t\t\tMARKETING_VERSION = 0.2.0;\t\n' 'in quotes|\t\t\t\tMARKETING_VERSION = "0.2.0";\n' \
  'two spaces after the "="|MARKETING_VERSION =  0.2.0;\n' 'a tab after the "="|MARKETING_VERSION =\t0.2.0;\n' \
  'a space before the ";"|MARKETING_VERSION = 0.2.0 ;\n' \
  'blanks everywhere, in quotes| \t MARKETING_VERSION\t=\t"0.2.0" ; \t\n'; do
  fn "${c#*|}" project_version_lines 0.2.0
  is "project_version_lines 0.2.0: 1 for a line that holds 0.2.0 but is rewritten, ${c%%|*}" 0 1
done
fn_file "$WORK/pbx" project_version_lines 0.1.0
is "project_version_lines: 0 without a MARKETING_VERSION line" 0 0

chmod 604 "$P"
before_mode=$(mode "$P") before_inode=$(inode "$P")
pbx 1.0.0 1.0.0 1.0.0 >"$WORK/expected"
fn '' project_version_set "$ROOT" 1.0.0
is "project_version_set: writes 1.0.0, printing nothing" 0 ''
check "...into every MARKETING_VERSION line (the quotes go); every other line stays byte for byte" \
  'cmp -s "$P" "$WORK/expected"'
check "...the file keeps its mode and inode" \
  '[ "$(mode "$P")" = "$before_mode" ] && [ "$(inode "$P")" = "$before_inode" ]'
check "...no temp file is left in TMPDIR" '[ -z "$(ls -A "$WORK/tmp")" ]'
fn_file "$P" project_versions
is "...project_versions reads it back" 0 1.0.0
printf ' \t MARKETING_VERSION\t=\t"0.1.0" ; \t\n' >"$P"
printf ' \t MARKETING_VERSION\t= 2.0.0;\n' >"$WORK/expected"
fn '' project_version_set "$ROOT" 2.0.0
check "project_version_set: keeps the text before \"=\", blanks and all; the rest of the line is \"= X.Y.Z;\"" \
  '[ $RC = 0 ] && cmp -s "$P" "$WORK/expected"'

# project_version_lines agrees with what project_version_set changes, over a project with every kind of line: diff
# of the file before and after shows as many lines out and as many in as it counts (scripts/make-release.sh expects
# the same of git diff --numstat), and then it counts none. 0.2.0: three lines already read "<prefix>= 0.2.0;";
# 0.1.0: one does; 1.0.0: none does.
printf '%b' '// !$*UTF8*$!\n{\n' '\t\t\t\tINFOPLIST_KEY_CFBundleShortVersionString = "$(MARKETING_VERSION)";\n' \
  '\t\t\t\tMARKETING_VERSION = 0.2.0;\n' '\t\t\t\tMARKETING_VERSION_SUFFIX = beta;\n' \
  '\t\t\t\tMARKETING_VERSION = "0.2.0";\n' 'MARKETING_VERSION=0.2.0;\n' 'MARKETING_VERSION= 0.2.0;\n' \
  'MARKETING_VERSION = 0.2.0;  \n' ' \t MARKETING_VERSION\t= 0.2.0;\n' 'MARKETING_VERSION =  0.2.0;\n' \
  'MARKETING_VERSION = 0.2.0 ;\n' '\t\t\t\tMARKETING_VERSION = 0.2.0;\t\n' '\t\t\t\tMARKETING_VERSION = 0.1.0;\n' \
  '\t\t\t\tMARKETING_VERSION = "0.1.0";\n' '\t\t\t\tPRODUCT_NAME = OverbrightControls;\n' \
  '\t\t\t\tMARKETING_VERSION = 0.3.0;\n' '}\n' >"$WORK/mixed"
for c in "0.2.0 9" "0.1.0 11" "1.0.0 12"; do
  read -r v want <<<"$c"
  cp "$WORK/mixed" "$P"
  fn_file "$WORK/mixed" project_version_lines "$v"
  counted=$OUT errs=$ERR
  fn '' project_version_set "$ROOT" "$v"
  set_rc=$RC errs=$errs$ERR
  lines_out="$(diff "$WORK/mixed" "$P" | grep -c '^<')"
  lines_in="$(diff "$WORK/mixed" "$P" | grep -c '^>')"
  fn_file "$P" project_version_lines "$v"
  after=$OUT errs=$errs$ERR
  RC=$set_rc OUT="counted $counted; diff: $lines_out lines out, $lines_in in; then counted $after" ERR=$errs
  is "project_version_lines $v counts what project_version_set changes in a mixed project (diff before and after)" \
    0 "counted $want; diff: $want lines out, $want in; then counted 0"
done

pbx 1.0.0 1.0.0 1.0.0 >"$P"
cp "$P" "$WORK/before"
for v in '' 1.1 v1.1.0 01.1.0 1.1.0-rc1 '1.1.0;' '1.1.0 ' 1000000000.0.0; do
  fn '' project_version_set "$ROOT" "$v"
  check "project_version_set: $(printf '%q' "$v") is refused, printing nothing; the file is unchanged" \
    '[ $RC = 1 ] && [ -z "$OUT$ERR" ] && cmp -s "$P" "$WORK/before"'
done
no_version_lines >"$P"
cp "$P" "$WORK/before"
fn '' project_version_set "$ROOT" 2.0.0
check "project_version_set: a project without a MARKETING_VERSION line is refused and stays byte for byte the same" \
  '[ $RC = 1 ] && [ -z "$OUT$ERR" ] && cmp -s "$P" "$WORK/before"'
check "...no temp file is left in TMPDIR" '[ -z "$(ls -A "$WORK/tmp")" ]'
fn '' project_version_set "$WORK/missing" 2.0.0
check "project_version_set: a missing project.pbxproj fails and is not created" \
  '[ $RC != 0 ] && [ -z "$OUT" ] && [ ! -e "$WORK/missing/Overbright.xcodeproj/project.pbxproj" ]'

# --- this repository: its version files are where version.sh looks, and VERSION holds one version. Whether the
# project's MARKETING_VERSION lines hold it too is not checked: scripts/make-release.sh and build-release.sh only warn
# when they do not (a release sets both), so CI does not fail on it either.
names="$("$BASH_BIN" -c '. "$0"; echo "$APP_VERSION_FILE $PROJECT_FILE"' "$LIB")"
if [ "$names" = "VERSION Overbright.xcodeproj/project.pbxproj" ] && [ -f "$TREE/VERSION" ] &&
  [ -f "$TREE/Overbright.xcodeproj/project.pbxproj" ]; then
  ok "APP_VERSION_FILE and PROJECT_FILE: this repository's VERSION and Overbright.xcodeproj/project.pbxproj"
else
  nok "APP_VERSION_FILE and PROJECT_FILE: this repository's version files" "version.sh names '$names'"
fi
fn '' app_version_get "$TREE"
tree_version=$OUT tree_rc=$RC
fn '' version_valid "$tree_version"
check "app_version_get: this repository's VERSION holds one version X.Y.Z ($tree_version)" \
  '[ "$tree_rc" = 0 ] && [ $RC = 0 ]'

# --- release_tag, release_assets
fn '' release_tag 1.2.3
is "release_tag 1.2.3: v1.2.3" 0 v1.2.3
fn '' release_tag 999999999.0.10
is "release_tag 999999999.0.10: v999999999.0.10" 0 v999999999.0.10
fn '' release_assets 1.2.3
is "release_assets 1.2.3: the zip, the disk image, then their SHA-256 sums" 0 \
  "$(lines Overbright-1.2.3.zip Overbright-1.2.3.dmg Overbright-1.2.3.sha256)"
fn '' release_assets 10.0.1
is "release_assets 10.0.1" 0 "$(lines Overbright-10.0.1.zip Overbright-10.0.1.dmg Overbright-10.0.1.sha256)"

# --- release_tags: tag names or `git ls-remote --tags` lines -> "<X.Y.Z> <tag>", once per tag
TAGS='v0.1.0\n0.2.0\nnot-a-release\nv1.2\n\nv01.0.0\nV0.5.0\nvv0.6.0\nv0.3.0-rc1\nv1000000000.0.0\n0.0.1000000000\n'
TAGS="${TAGS}aaaa\trefs/tags/0.3.0\nbbbb\trefs/tags/v0.4.0\ncccc\trefs/tags/v0.4.0^{}\ndddd\trefs/heads/v0.9.0\n"
TAGS="${TAGS}v0.1.0\neeee\trefs/tags/0.4.0\nffff\trefs/tags/v0.10.0"
fn "$TAGS" release_tags
is "release_tags: vX.Y.Z and X.Y.Z tags, from names and ls-remote lines (a peeled one once), nothing else" 0 \
  "$(lines '0.1.0 v0.1.0' '0.2.0 0.2.0' '0.3.0 0.3.0' '0.4.0 v0.4.0' '0.4.0 0.4.0' '0.10.0 v0.10.0')"
# ls-remote prints a peeled line after its tag's own line; alone, it still names its tag
fn 'ffff\trefs/tags/v0.12.0^{}\n' release_tags
is "release_tags: a peeled line names its tag (v0.12.0^{} alone is v0.12.0)" 0 '0.12.0 v0.12.0'
fn '' release_tags
is "release_tags: no input, no tags" 0 ''

# --- highest_tag [skip]
fn "$TAGS" highest_tag
is "highest_tag: the highest version (0.10.0 > 0.4.0)" 0 '0.10.0 v0.10.0'
fn "$TAGS" highest_tag v0.10.0
is "highest_tag v0.10.0: the highest other tag, the first of its version" 0 '0.4.0 v0.4.0'
fn 'v0.9.0\nv0.11.0\n0.11.0\n' highest_tag v0.11.0
is "highest_tag v0.11.0 skips only the tag named v0.11.0, not 0.11.0" 0 '0.11.0 0.11.0'
fn 'v0.9.0\nv0.11.0\n0.11.0\n' highest_tag 0.11.0
is "highest_tag 0.11.0 skips only the tag named 0.11.0, not v0.11.0" 0 '0.11.0 v0.11.0'
fn '99999999.999999999.999999999\nv999999999.0.0\nv1000000000.0.0\n' highest_tag
is "highest_tag: 9-digit numbers; a 10-digit tag is no release tag" 0 '999999999.0.0 v999999999.0.0'
fn 'v0.1.0\n' highest_tag v0.1.0
is "highest_tag: nothing when the skipped tag is the only one" 0 ''
fn 'nope\nv1.2\n' highest_tag
is "highest_tag: nothing without release tags" 0 ''
fn '' highest_tag
is "highest_tag: nothing for no input" 0 ''

# --- tag_of_version
fn "$TAGS" tag_of_version 0.4.0
is "tag_of_version 0.4.0: v0.4.0, the first of its two tags" 0 v0.4.0
fn '0.4.0\nv0.4.0\n' tag_of_version 0.4.0
is "tag_of_version 0.4.0: 0.4.0 when that one comes first" 0 0.4.0
fn "$TAGS" tag_of_version 0.2.0
is "tag_of_version 0.2.0: the plain tag 0.2.0" 0 0.2.0
fn "$TAGS" tag_of_version 0.9.0
is "tag_of_version: nothing for a version without a tag (a branch v0.9.0 is not one)" 0 ''
fn "$TAGS" tag_of_version v0.4.0
is "tag_of_version: nothing for a non-version (v0.4.0 is a tag)" 0 ''
# Over 64 KiB (a pipe buffer) of release_tags output after the match: a tag_of_version that stops reading there
# leaves release_tags writing into a closed pipe every time, not only when it loses a race (the CI's Broken pipe)
fn "v0.4.0$(awk 'BEGIN { for (i = 1; i <= 1500; i++) printf "\nv100000000.100000000.%d", 100000000 + i }')" \
  tag_of_version 0.4.0
is "tag_of_version: reads release_tags to the end, past a pipe buffer of tags after the match (no Broken pipe)" 0 v0.4.0

# --- tag_commit <tag>: the commit of refs/tags/<tag> in `git ls-remote --tags` lines
REFS='1111\trefs/tags/v0.1.0\n2222\trefs/tags/v0.2.0\n3333\trefs/tags/v0.2.0^{}\n4444\trefs/tags/0.2.0\n'
REFS="${REFS}5555\trefs/tags/v10.1.0\n6666\trefs/tags/v0.1.0.1\n7777\trefs/tags/v0x1y0\n8888\trefs/heads/v0.5.0\n"
fn "$REFS" tag_commit v0.1.0
is "tag_commit v0.1.0: the lightweight tag's own line (not v0.1.0.1's, not v0x1y0's: no dots as wildcards)" 0 1111
fn "$REFS" tag_commit v0.2.0
is "tag_commit: an annotated tag's peeled line, not the tag object" 0 3333
fn 'cccc\trefs/tags/v0.4.0^{}\naaaa\trefs/tags/v0.4.0\n' tag_commit v0.4.0
is "tag_commit: the peeled line wins wherever it is" 0 cccc
fn "$REFS" tag_commit 0.2.0
is "tag_commit: 0.2.0 is a tag of its own, not v0.2.0" 0 4444
fn "$REFS" tag_commit v0.1.0.1
is "tag_commit: a longer tag name is a tag of its own" 0 6666
fn "$REFS" tag_commit v0.5.0
is "tag_commit: only refs/tags/<tag> counts, not a branch" 0 ''
fn "$REFS" tag_commit v0.3.0
is "tag_commit: nothing for a missing tag" 0 ''
fn '' tag_commit v0.1.0
is "tag_commit: nothing for no input" 0 ''

# --- real `git tag` and `git ls-remote --tags` output, of a throwaway repository: A - B - C, the lightweight release
# tag v0.1.0 on A, the annotated v0.2.0 on B, the plain 0.3.0, the annotated not-a-release and v1000000000.0.0 on C
G="$WORK/git"
(
  set -e
  git -c init.defaultBranch=main init -q "$G"
  cd "$G"
  git commit -q --allow-empty -m A
  git tag v0.1.0
  git commit -q --allow-empty -m B
  git tag -a v0.2.0 -m 'Release 0.2.0'
  git commit -q --allow-empty -m C
  git tag 0.3.0
  git tag -a not-a-release -m 'Not a release'
  git tag v1000000000.0.0
  git ls-remote --tags "$G" >"$WORK/ls-remote"
  git tag -l >"$WORK/tag-l"
  git tag --merged v0.2.0 >"$WORK/merged"
) || {
  echo "not ok the test repository could not be built"
  exit 1
}
A=$(git -C "$G" rev-parse v0.1.0) B=$(git -C "$G" rev-parse 'v0.2.0^{commit}') B_TAG=$(git -C "$G" rev-parse v0.2.0)
C=$(git -C "$G" rev-parse HEAD)
want_tags="$(sorted "$(lines '0.1.0 v0.1.0' '0.2.0 v0.2.0' '0.3.0 0.3.0')")"
fn_file "$WORK/ls-remote" release_tags
check "release_tags over git ls-remote --tags: v0.1.0, v0.2.0 (its peeled line too) and 0.3.0, once each" \
  '[ $RC = 0 ] && [ -z "$ERR" ] && [ "$(sorted "$OUT")" = "$want_tags" ]'
fn_file "$WORK/tag-l" release_tags
check "release_tags over git tag -l: the same three" \
  '[ $RC = 0 ] && [ -z "$ERR" ] && [ "$(sorted "$OUT")" = "$want_tags" ]'
fn_file "$WORK/ls-remote" highest_tag
is "highest_tag over git ls-remote --tags: 0.3.0" 0 '0.3.0 0.3.0'
fn_file "$WORK/ls-remote" highest_tag 0.3.0
is "highest_tag 0.3.0 over git ls-remote --tags: v0.2.0" 0 '0.2.0 v0.2.0'
fn_file "$WORK/merged" highest_tag v0.2.0
is "highest_tag v0.2.0 over git tag --merged v0.2.0: v0.1.0, the release before (release-notes.sh)" 0 '0.1.0 v0.1.0'
fn_file "$WORK/ls-remote" tag_of_version 0.2.0
is "tag_of_version 0.2.0 over git ls-remote --tags: v0.2.0" 0 v0.2.0
fn_file "$WORK/ls-remote" tag_commit v0.1.0
check "tag_commit over git ls-remote --tags: a lightweight tag's commit" \
  '[ $RC = 0 ] && [ -z "$ERR" ] && [ -n "$A" ] && [ "$OUT" = "$A" ]'
fn_file "$WORK/ls-remote" tag_commit v0.2.0
check "tag_commit over git ls-remote --tags: an annotated tag's commit, not the tag object" \
  '[ $RC = 0 ] && [ -z "$ERR" ] && [ -n "$B" ] && [ "$OUT" = "$B" ] && [ "$B" != "$B_TAG" ]'
fn_file "$WORK/ls-remote" tag_commit 0.3.0
check "tag_commit over git ls-remote --tags: the plain tag 0.3.0's commit" \
  '[ $RC = 0 ] && [ -z "$ERR" ] && [ -n "$C" ] && [ "$OUT" = "$C" ]'
fn_file "$WORK/ls-remote" tag_commit v0.3.0
is "tag_commit over git ls-remote --tags: nothing for a tag that is not there (v0.3.0)" 0 ''

# --- sourced into a `set -euo pipefail` script and called the ways scripts/*.sh, .github/scripts/*.sh and release.yml
# call it: sourcing changes no shell option, the functions keep their variables to themselves (local), and finding
# nothing is no failure. The script prints one line of results or stops at the first failure.
S="$WORK/strict"
mkdir -p "$S/Overbright.xcodeproj"
printf '1.0.0\n' >"$S/VERSION"
pbx 1.0.0 '"1.0.0"' 0.9.0 >"$S/Overbright.xcodeproj/project.pbxproj"
cat >"$WORK/strict.sh" <<'EOF'
set -euo pipefail
trap 'echo "failed at line $LINENO" >&2' ERR
options="$(set -o; shopt)"
. "$1"
[ "$(set -o; shopt)" = "$options" ] || { echo "sourcing version.sh changed the shell options" >&2; exit 1; }
root=$2 refs=$3
a=a b=b x=x y=y z=z line=line ref=ref v=v t=t seen=seen skip=skip best=best best_tag=best_tag found=found file=file
program=program tmp=tmp ifs=$IFS
version_valid 1.2.3
if version_valid 1.2; then exit 1; fi
version_gt 1.10.0 1.9.9
if version_gt 1.2.3 1.2.3; then exit 1; fi
version_cmp 1.2.3 1.2.4 >/dev/null
version_bump 1.2.3 patch >/dev/null
if version_bump 1.2.3 bogus; then exit 1; fi
app_version_set "$root" 1.1.0
project_version_set "$root" 1.1.0
release_tags <"$refs" >/dev/null
highest_tag <"$refs" >/dev/null
tag_of_version 0.2.0 <"$refs" >/dev/null
vars="$a $b $x $y $z $line $ref $v $t $seen $skip $best $best_tag $found $file $program $tmp"
[ "$vars" = "a b x y z line ref v t seen skip best best_tag found file program tmp" ] && [ "$IFS" = "$ifs" ] ||
  { echo "a version.sh function changed the caller's variables: $vars" >&2; exit 1; }
tags=''
current="$(app_version_get "$root")"
project="$(project_versions <"$root/$PROJECT_FILE" | tr '\n' ' ')"
changed="$(project_version_lines 1.2.0 <"$root/$PROJECT_FILE")"
none="$(printf 'x\n' | project_versions)"
highest="$(printf '%s\n' "$tags" | highest_tag)"
tag="$(printf '%s\n' "$tags" | tag_of_version "$current")"
sha="$(tag_commit "$(release_tag "$current")" <<<"$tags")"
peeled="$(cat "$refs" | tag_commit v0.2.0)"
next="$(version_bump "$current" minor)"
n=0
while read -r asset; do n=$((n + 1)); done < <(release_assets "$next")
echo "$current|$project|$changed|$none|$highest|$tag|$sha|$peeled|$next|$n"
EOF
OUT="$("$BASH_BIN" "$WORK/strict.sh" "$LIB" "$S" "$WORK/ls-remote" 2>"$WORK/err")"
RC=$?
ERR="$(cat "$WORK/err")"
is "sourced into a set -euo pipefail script: options and the caller's variables kept, finding nothing no failure" \
  0 "1.1.0|1.1.0 |3|||||$B|1.2.0|3"

echo "# $pass passed, $fail failed"
[ "$fail" = 0 ]
