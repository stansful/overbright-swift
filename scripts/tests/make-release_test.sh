#!/usr/bin/env bash
# Tests of scripts/make-release.sh: throwaway repositories, each a clone of its own local bare "origin", in a temp
# dir (TMPDIR), with the script, scripts/lib/version.sh, VERSION and a small Overbright.xcodeproj/project.pbxproj. The
# script runs from a directory outside the repository, under $TEST_BASH (default: bash from PATH, /bin/bash 3.2 on
# macOS), its answers fed on stdin; for what happens while it waits at its question (a file changed meanwhile, a
# signal) it runs in the background, its answers written to a FIFO, and every wait is bounded. git reads only this
# test's config (HOME is the temp dir). Nothing here builds or launches the app.
#
#   scripts/tests/make-release_test.sh          KEEP=1 keeps the temp dir
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
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/make-release-test.XXXXXX")" || ! WORK="$(cd "$WORK" && pwd -P)"; then
  echo "not ok no temp dir in ${TMPDIR:-/tmp}"
  exit 1
fi
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$WORK"' EXIT; else echo "# work dir: $WORK"; fi

export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
# git never finds a repository above the temp dir (a TMPDIR inside some checkout), nor takes a repository or config
# from the caller's environment (a git hook's GIT_DIR, a GIT_CONFIG_GLOBAL: a check here writes the global config)
GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
export GIT_CEILING_DIRECTORIES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR \
  GIT_NAMESPACE GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
mkdir -p "$HOME"
# the script's temp files (scripts/lib/version.sh rewrites the version files through one) land here, an absolute path
# whatever the caller's TMPDIR (the script runs from WORK); the last check finds none left behind
mkdir -p "$WORK/tmp"
export TMPDIR="$WORK/tmp"

pass=0 fail=0
ok() {
  echo "ok $1"
  pass=$((pass + 1))
}
nok() {
  echo "not ok $1: $2"
  fail=$((fail + 1))
}
# check <name> <condition (eval'd)>: on failure prints the script's output
check() {
  if eval "$2"; then ok "$1"; else nok "$1" "rc=$RC; condition: $2; output:
$OUT"; fi
}
has() { case $OUT in *"$1"*) return 0 ;; esac; return 1; }
NL='
'
# line <text>: a line of the output is exactly the text
line() { case "$NL$OUT$NL" in *"$NL$1$NL"*) return 0 ;; esac; return 1; }

echo "# scripts/make-release.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"'), $(git --version)"

PF=Overbright.xcodeproj/project.pbxproj
# mvl <version>: a MARKETING_VERSION line of the fixture's project.pbxproj
mvl() { printf '\t\t\t\tMARKETING_VERSION = %s;' "$1"; }
# configuration <id> <name> <version> <setting>: a build configuration of the fixture's project.pbxproj: its
# MARKETING_VERSION line among other settings, one of which only refers to MARKETING_VERSION
configuration() {
  printf '\t\t%s\n' "$1 /* $2 */ = {"
  printf '\t\t\t%s\n' 'isa = XCBuildConfiguration;' 'buildSettings = {'
  printf '\t\t\t\t%s\n' 'CODE_SIGN_STYLE = Manual;' 'CURRENT_PROJECT_VERSION = 1;' \
    'INFOPLIST_KEY_CFBundleShortVersionString = "$(MARKETING_VERSION)";' 'MACOSX_DEPLOYMENT_TARGET = 14.0;'
  printf '%s\n' "$(mvl "$3")"
  printf '\t\t\t\t%s\n' "$4" 'SDKROOT = macosx;'
  printf '\t\t\t%s\n' '};' "name = $2;"
  printf '\t\t%s\n' '};'
}
# pbxproj <version> [<version of Release>]: the fixture's project.pbxproj, tab-indented as Xcode writes it, the version
# in the MARKETING_VERSION lines of its Debug and Release configurations
pbxproj() {
  printf '%s\n' '// !$*UTF8*$!' '{'
  printf '\t%s\n' 'archiveVersion = 1;' 'objectVersion = 77;' 'objects = {'
  printf '%s\n' '' '/* Begin XCBuildConfiguration section */'
  configuration 0B21E7000000000000000051 Debug "$1" 'ONLY_ACTIVE_ARCH = YES;'
  configuration 0B21E7000000000000000052 Release "${2-$1}" 'ONLY_ACTIVE_ARCH = NO;'
  printf '%s\n' '/* End XCBuildConfiguration section */'
  printf '\t%s\n' '};' 'rootObject = 0B21E7000000000000000001 /* Project object */;'
  printf '%s\n' '}'
}
# not_version <answer> <suggestion>, v_hint <answer>: why the script refuses an answer that is not X.Y.Z, and one
# with a "v" in front
not_version() {
  printf "'%s' is not a version X.Y.Z (three numbers without leading zeros, at most 9 digits each, like %s)" "$1" "$2"
}
v_hint() { printf "'%s': give the version without 'v', like %s" "$1" "${1#?}"; }
# unreleased <version>: the note that the current version has no release tag yet
unreleased() {
  printf 'No tag v%s yet: once a commit with version %s is on main on GitHub, release %s goes out' "$1" "$1" "$1"
  printf ' without a new version too.'
}
# what the script says of a version file that changed after it wrote it, instead of restoring it (a file it did not
# write is never overwritten; every other version file is restored)
kept="left as it is: it changed after the version was written (git diff)"

# --- the template: origin.git with main (VERSION and project.pbxproj at 0.1.0, the script) and the tag v0.1.0 on its
# first commit
TPL="$WORK/tpl"
mkdir -p "$TPL/seed/Overbright.xcodeproj" "$TPL/seed/scripts/lib"
cp "$TREE/scripts/make-release.sh" "$TPL/seed/scripts/"
cp "$TREE/scripts/lib/version.sh" "$TPL/seed/scripts/lib/"
echo 0.1.0 >"$TPL/seed/VERSION"
pbxproj 0.1.0 >"$TPL/seed/$PF"
echo readme >"$TPL/seed/README"
printf 'build/\n' >"$TPL/seed/.gitignore"
(
  set -e
  cd "$TPL/seed"
  git -c init.defaultBranch=main init -q .
  git symbolic-ref HEAD refs/heads/main
  git add -A
  git commit -q -m init
  git tag v0.1.0
  echo more >>README
  git commit -q -am 'Fix something'
  git init -q --bare "$TPL/origin.git"
  git -C "$TPL/origin.git" symbolic-ref HEAD refs/heads/main
  git push -q "$TPL/origin.git" main v0.1.0
) || {
  echo "not ok the test fixture could not be built"
  exit 1
}

# new_case <name>: CASE/origin.git (a copy of the template's) and its clone REPO; a name used twice stops the tests
# (the clone would fail and the case would run in the earlier case's repository)
new_case() {
  CASE="$WORK/$1"
  if [ -e "$CASE" ]; then
    echo "not ok the test case name '$1' is used twice"
    exit 1
  fi
  mkdir -p "$CASE"
  cp -R "$TPL/origin.git" "$CASE/origin.git"
  git clone -q "$CASE/origin.git" "$CASE/repo"
  REPO="$CASE/repo"
}
# mr <stdin (printf %b)> [args...]: make-release.sh of REPO, run from WORK; sets OUT and RC
mr() {
  local input="$1"
  shift
  OUT="$(cd "$WORK" && printf '%b' "$input" | "$BASH_BIN" "$REPO/scripts/make-release.sh" "$@" 2>&1)"
  RC=$?
}
# from <dir> <script path> [args...]: the script run from <dir> by that path, no input; sets OUT and RC
from() {
  local dir="$1" path="$2"
  shift 2
  OUT="$(cd "$dir" && "$BASH_BIN" "$path" "$@" </dev/null 2>&1)"
  RC=$?
}
g() { git -C "$REPO" "$@"; }
count() { g rev-list --count HEAD; }
subject() { g log -1 --format=%s; }
clean() { [ -z "$(g status --porcelain)" ]; }
# refs_out: origin's branches and tags, and the local tags: what a push or a new tag would change
refs_out() {
  git -C "$CASE/origin.git" for-each-ref --format='%(objectname) %(refname)'
  g tag -l
}
# files_are <version> [<version of Release>]: VERSION and project.pbxproj are the fixture's with that version, byte for
# byte
files_are() {
  printf '%s\n' "$1" >"$WORK/want.version" && pbxproj "$@" >"$WORK/want.pbxproj" &&
    cmp -s "$WORK/want.version" "$REPO/VERSION" && cmp -s "$WORK/want.pbxproj" "$REPO/$PF"
}
# release_commit <old> <new>: HEAD is the release commit of <new>: its subject, and against HEAD^ it changes the line
# of VERSION and the two MARKETING_VERSION lines of project.pbxproj from <old> to <new> and nothing else (no other
# line, file or mode). Its diffs are in git's path order, whatever a diff.orderFile setting says (-O/dev/null).
release_commit() {
  [ "$(subject)" = "feat: release - version $2" ] &&
    [ "$(g diff -O/dev/null --numstat HEAD^ HEAD)" = "$(printf '2\t2\t%s\n1\t1\tVERSION' "$PF")" ] &&
    [ -z "$(g diff --summary HEAD^ HEAD)" ] &&
    [ "$(g diff -O/dev/null -U0 HEAD^ HEAD | grep '^[-+][^-+]')" = \
      "$(printf -- '-%s\n+%s\n' "$(mvl "$1")" "$(mvl "$2")" "$(mvl "$1")" "$(mvl "$2")" "$1" "$2")" ]
}
# set_version <version> [<version of Release>]: commits VERSION and project.pbxproj at that version
set_version() {
  echo "$1" >"$REPO/VERSION"
  pbxproj "$@" >"$REPO/$PF"
  g commit -q -am "feat: release - version $1"
}

# --- Enter takes the suggestion, the next minor version
new_case enter
before=$(count) head=$(g rev-parse HEAD) out_before=$(refs_out)
mr '\n\n'
check "prints the current version" 'line "Current version:  0.1.0 (VERSION)"'
check "prints the last release tag" 'line "Last release tag: v0.1.0"'
check "...and no 'not released yet' note for a released version" '! has "No tag v0.1.0 yet"'
check "prints the next patch, minor and major versions" 'line "Next: 0.1.1 (patch), 0.2.0 (minor), 1.0.0 (major)."'
check "suggests the next minor version" 'has "New version [0.2.0]: "'
check "shows the diff of both files and asks to commit them" \
  'has "+0.2.0" && has "+$(mvl 0.2.0)" && has "Commit VERSION $PF as \"feat: release - version 0.2.0\"? [Y/n] "'
check "Enter takes 0.2.0, Enter commits (run from outside the repository)" '[ $RC = 0 ] && files_are 0.2.0'
check "...exactly one new commit, on the old HEAD" \
  '[ "$(count)" = $((before + 1)) ] && [ "$(g rev-parse HEAD^)" = "$head" ]'
check "...'feat: release - version 0.2.0', only the line of VERSION and the two MARKETING_VERSION lines" \
  'release_commit 0.1.0 0.2.0 && clean'
check "...prints the commit" 'has "Commit $(g rev-parse --short HEAD): feat: release - version 0.2.0"'
check "...pushes nothing and makes no tag: origin and the tags untouched" '[ "$(refs_out)" = "$out_before" ]'
check "...and says what to push" \
  'has "Push it (git push origin main): release 0.2.0 (tag v0.2.0) goes out once this commit is on main on GitHub"'

new_case 'with space'
mr '' --yes
check "a repository path with a space works" '[ $RC = 0 ] && files_are 0.2.0 && release_commit 0.1.0 0.2.0 && clean'

# --- bump words at the prompt
for c in 'patch|0.1.1' 'Patch|0.1.1' 'minor|0.2.0' 'MINOR|0.2.0' 'major|1.0.0' 'Major|1.0.0' '  patch  |0.1.1'; do
  w=${c%|*} want=${c#*|}
  new_case "prompt-$want-$(printf '%s' "$w" | od -An -tx1 | tr -d ' \n')"
  mr "$w\n\n"
  check "prompt: '$w' is $want" '[ $RC = 0 ] && files_are "$want" && release_commit 0.1.0 "$want" && clean'
done

# --- bump words as the argument
new_case words
before=$(count)
for c in 'patch|0.1.1' 'minor|0.2.0' 'major|1.0.0' 'Patch|0.1.1' 'MINOR|0.2.0' 'Major|1.0.0' 'PATCH|0.1.1' \
  'Minor|0.2.0' 'MAJOR|1.0.0'; do
  w=${c%|*} want=${c#*|}
  mr '' "$w" --no-commit
  check "argument '$w' is $want" \
    '[ $RC = 0 ] && line "New version: $want" && files_are "$want" && [ "$(count)" = "$before" ]'
  g checkout -q -- VERSION "$PF"
done
mr '' minor --yes
check "argument minor --yes commits 0.2.0" '[ $RC = 0 ] && release_commit 0.1.0 0.2.0 && clean'

# --- an explicit version
new_case explicit
mr '0.3.7\n\n'
check "prompt: an explicit 0.3.7 is taken" '[ $RC = 0 ] && files_are 0.3.7 && release_commit 0.1.0 0.3.7 && clean'
mr '' 0.10.0 --yes
check "argument: 0.10.0 is above 0.3.7 (numbers, not strings), committed without a question" \
  '[ $RC = 0 ] && ! has "[Y/n]" && files_are 0.10.0 && release_commit 0.3.7 0.10.0 && clean'
mr '' 999999999.999999999.999999999 -y
check "argument: 999999999.999999999.999999999, 9 digits each, is a version" \
  '[ $RC = 0 ] && release_commit 0.10.0 999999999.999999999.999999999 && clean'

# --- the prompt asks again after a refused answer
new_case reask
before=$(count)
wrong='0.0.9\n0.1.0\n1.2\nv0.2.0\nV0.2.0\n01.2.3\n0.02.0\n0.1.00\n1234567890.0.0\n0.1.1234567890\n0.2.0-rc1'
mr "$wrong\nbump\nnext version\n  0.3.0  \ny\n"
check "prompt: a lower version is refused" \
  'has "  version 0.0.9 is not higher than the current version 0.1.0. Enter another version."'
check "prompt: a released version (its tag exists) is refused" \
  'has "  tag v0.1.0 exists: version 0.1.0 was released already. Enter another version."'
check "prompt: 'v0.2.0' and 'V0.2.0' are refused, with the version without the v" \
  'has "  $(v_hint v0.2.0). Enter another version." && has "  $(v_hint V0.2.0). Enter another version."'
for v in 1.2 01.2.3 0.02.0 0.1.00 1234567890.0.0 0.1.1234567890 0.2.0-rc1 bump 'next version'; do
  check "prompt: '$v' is not X.Y.Z, refused" 'has "  $(not_version "$v" 0.2.0). Enter another version."'
done
check "prompt: each of the 13 refused answers asks again" \
  '[ "$(printf "%s\n" "$OUT" | grep -c "Enter another version\.$")" = 13 ] &&
    [ "$(printf "%s\n" "$OUT" | grep -cF "New version [0.2.0]: ")" = 14 ]'
check "prompt: then 0.3.0 (blanks trimmed) is taken and committed" \
  '[ $RC = 0 ] && files_are 0.3.0 && [ "$(count)" = $((before + 1)) ] && release_commit 0.1.0 0.3.0 && clean'

# --- end of input at the prompt
new_case eof
before=$(count)
mr 'bump\n'
check "end of input at the prompt changes nothing" \
  '[ $RC = 1 ] && has "error: input ended, nothing changed." && files_are 0.1.0 && [ "$(count)" = "$before" ] && clean'
mr ''
check "...no input at all: the same" \
  '[ $RC = 1 ] && has "error: input ended, nothing changed." && files_are 0.1.0 && clean'

# --- refused versions given as the argument
new_case refuse
before=$(count)
for c in "0.0.9|version 0.0.9 is not higher than the current version 0.1.0" \
  "0.1.0|tag v0.1.0 exists: version 0.1.0 was released already" \
  "v0.2.0|$(v_hint v0.2.0)" "V1.0.0|$(v_hint V1.0.0)" "1.2|$(not_version 1.2 0.2.0)" \
  "1.2.3.4|$(not_version 1.2.3.4 0.2.0)" "01.2.3|$(not_version 01.2.3 0.2.0)" "1.02.3|$(not_version 1.02.3 0.2.0)" \
  "1.2.03|$(not_version 1.2.03 0.2.0)" "0.2.0-rc1|$(not_version 0.2.0-rc1 0.2.0)" \
  " 0.2.0|$(not_version ' 0.2.0' 0.2.0)" "1234567890.0.0|$(not_version 1234567890.0.0 0.2.0)" \
  "0.1234567890.0|$(not_version 0.1234567890.0 0.2.0)" "0.1.1234567890|$(not_version 0.1.1234567890 0.2.0)" \
  "bump|$(not_version bump 0.2.0)" "pAtch|$(not_version pAtch 0.2.0)" "|no version given"; do
  v=${c%%|*} want=${c#*|}
  mr '' --yes "$v"
  check "argument '$v' is refused: $want" \
    '[ $RC = 1 ] && has "error: $want." && files_are 0.1.0 && [ "$(count)" = "$before" ] && clean'
done
mr '\n\n' 0.0.9
check "a refused argument does not fall back to the prompt" \
  '[ $RC = 1 ] && ! has "New version [" && files_are 0.1.0 && [ "$(count)" = "$before" ]'

# --- tags: local ones, origin's (only git ls-remote sees them), plain X.Y.Z and annotated ones, and tags that are no
# release tags
new_case tags
g tag v0.5.0
g tag 0.6.0
g tag v5.0.0-rc1
g tag nightly
git clone -q "$CASE/origin.git" "$CASE/other"
git -C "$CASE/other" tag 0.7.0
git -C "$CASE/other" tag -a v0.9.0 -m 'Release 0.9.0'
git -C "$CASE/other" tag v10.0
git -C "$CASE/other" push -q origin 0.7.0 v0.9.0 v10.0
before=$(count) out_before=$(refs_out)
mr '' --yes 0.5.0
check "a local tag v0.5.0 is refused" \
  '[ $RC = 1 ] && has "error: tag v0.5.0 exists: version 0.5.0 was released already."'
mr '' --yes 0.6.0
check "a local plain tag 0.6.0 is refused" \
  '[ $RC = 1 ] && has "error: tag 0.6.0 exists: version 0.6.0 was released already."'
mr '' --yes 0.7.0
check "a plain tag 0.7.0 only origin has is refused" \
  '[ $RC = 1 ] && has "error: tag 0.7.0 exists: version 0.7.0 was released already."'
mr '' --yes 0.9.0
check "an annotated tag v0.9.0 only origin has is refused" \
  '[ $RC = 1 ] && has "error: tag v0.9.0 exists: version 0.9.0 was released already."'
mr '' --yes 0.8.0
check "a version below the highest tag, one only origin has, is refused" \
  '[ $RC = 1 ] && has "error: version 0.8.0 is not higher than the last release tag v0.9.0."'
check "...nothing changed" 'files_are 0.1.0 && [ "$(count)" = "$before" ] && clean && [ "$(refs_out)" = "$out_before" ]'
mr '0.7.0\n0.8.0\n'
check "the last tag and the suggestions come from every release tag, other tags left out" \
  'line "Last release tag: v0.9.0" && line "Next: 0.9.1 (patch), 0.10.0 (minor), 1.0.0 (major)." &&
    has "New version [0.10.0]: " && [ $RC = 1 ]'
check "...the prompt refuses them too" \
  'has "  tag 0.7.0 exists: version 0.7.0 was released already. Enter another version." &&
    has "  version 0.8.0 is not higher than the last release tag v0.9.0. Enter another version."'
for c in 'patch|0.9.1' 'MINOR|0.10.0' 'Major|1.0.0'; do
  w=${c%|*} want=${c#*|}
  mr '' "$w" --no-commit
  check "'$w' bumps the highest tag, v0.9.0, not the current version: $want" '[ $RC = 0 ] && files_are "$want"'
  g checkout -q -- VERSION "$PF"
done
mr '' --yes
check "--yes takes the next minor version, 0.10.0, and commits without a question" \
  '[ $RC = 0 ] && ! has "[Y/n]" && release_commit 0.1.0 0.10.0 && [ "$(count)" = $((before + 1)) ] && clean'
check "...and pushes nothing" '[ "$(refs_out)" = "$out_before" ]'

new_case localtag
g tag v0.5.0
mr '' --yes 0.4.0
check "a version below the highest tag, a local one, is refused" \
  '[ $RC = 1 ] && has "error: version 0.4.0 is not higher than the last release tag v0.5.0." && files_are 0.1.0 &&
    clean'
mr '' --yes
check "...--yes takes 0.6.0" '[ $RC = 0 ] && line "Last release tag: v0.5.0" && release_commit 0.1.0 0.6.0 && clean'

# --- origin's tags cannot be read: a warning, then the local tags only
new_case badorigin
git clone -q "$CASE/origin.git" "$CASE/other"
git -C "$CASE/other" tag v0.7.0
git -C "$CASE/other" push -q origin v0.7.0
g remote set-url origin "$CASE/missing.git"
want="warning: could not read origin's tags ($CASE/missing.git): comparing with the local tags only."
mr '' -y
check "origin unreachable: a warning, the local tags only, the commit is made" \
  '[ $RC = 0 ] && line "$want" && line "Last release tag: v0.1.0 (of the local tags)" && release_commit 0.1.0 0.2.0 &&
    clean'

new_case notags-offline
g tag -d v0.1.0 >/dev/null
g remote set-url origin "$CASE/missing.git"
want="Release tags unknown: no local ones, and origin's could not be read."
mr '0.2.0\n' --no-commit
check "origin unreachable and no local tags: a warning, no claim about tags or an unreleased version" \
  '[ $RC = 0 ] && has "warning: could not read origin" && line "$want" && ! has "No release tag yet" && ! has " yet:"'
g checkout -q -- VERSION "$PF"
g tag v0.1.0 HEAD~1
mr '0.2.0\n' --no-commit
check "origin unreachable with local tags: the last local tag, marked as such" \
  '[ $RC = 0 ] && line "Last release tag: v0.1.0 (of the local tags)" && ! has " yet:"'
g checkout -q -- VERSION "$PF"

# --- no release tags at all
new_case notags
g tag -d v0.1.0 >/dev/null
git -C "$CASE/origin.git" tag -d v0.1.0 >/dev/null
mr ''
check "no tags: says so, and that the current version is not released yet" \
  'line "No release tag yet." && line "$(unreleased 0.1.0)" && has "New version [0.2.0]: "'
mr '' 0.1.0 --yes
check "no tags: the current version itself is still refused" \
  '[ $RC = 1 ] && has "error: version 0.1.0 is not higher than the current version 0.1.0." && files_are 0.1.0 && clean'

# --- a dirty tree
new_case dirty
before=$(count)
echo change >>"$REPO/README"
mr '' --yes 0.2.0
check "a modified file is refused" \
  '[ $RC = 1 ] && has "error: there are uncommitted changes (working tree or index):" && line " M README" &&
    files_are 0.1.0 && [ "$(count)" = "$before" ]'
check "...and stays modified" '[ "$(g status --porcelain)" = " M README" ]'
g checkout -q -- README
echo 0.5.0 >"$REPO/VERSION"
mr '' --yes 0.2.0
check "a modified VERSION is refused and left as it is" \
  '[ $RC = 1 ] && has "uncommitted changes" && [ "$(cat "$REPO/VERSION")" = 0.5.0 ] && [ "$(count)" = "$before" ]'
g checkout -q -- VERSION
pbxproj 0.5.0 >"$REPO/$PF"
mr '' --yes 0.2.0
check "a modified project.pbxproj is refused and left as it is" \
  '[ $RC = 1 ] && line " M $PF" && printf "0.1.0\n" | cmp -s - "$REPO/VERSION" && [ "$(count)" = "$before" ] &&
    pbxproj 0.5.0 >"$WORK/want.pbxproj" && cmp -s "$WORK/want.pbxproj" "$REPO/$PF"'
g checkout -q -- "$PF"
echo new >"$REPO/newfile"
g add newfile
mr '' --yes 0.2.0
check "a staged file is refused" \
  '[ $RC = 1 ] && has "uncommitted changes" && files_are 0.1.0 && [ "$(count)" = "$before" ] &&
    [ "$(g status --porcelain)" = "A  newfile" ]'
g reset -q
mkdir -p "$REPO/build"
echo log >"$REPO/build/build.log"
mr '' --yes 0.2.0
check "an untracked file is only a warning, and stays out of the commit" \
  '[ $RC = 0 ] && line "warning: these files are not in git, so the release does not have them:" && line "  newfile" &&
    release_commit 0.1.0 0.2.0 && [ "$(g status --porcelain)" = "?? newfile" ]'
check "...ignored files are not listed" '! has "build.log"'
new_case untracked
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do echo x >"$REPO/f$i"; done
mr '' --yes 0.2.0
check "more than 10 untracked files: the first 10 and …" \
  '[ $RC = 0 ] && line "  f10" && ! has "f11" && line "  …" && release_commit 0.1.0 0.2.0'

# --- git hooks: they run on the commit's own index, so what a pre-commit hook stages lands in the commit
# hook <commands> [<name>]: REPO's git hook of that name, pre-commit by default
hook() {
  local name="${2:-pre-commit}"
  mkdir -p "$REPO/.git/hooks"
  printf '#!/bin/sh\n%s\n' "$1" >"$REPO/.git/hooks/$name"
  chmod +x "$REPO/.git/hooks/$name"
}
no_verify="  git commit --no-verify -m 'feat: release - version 0.2.0' -- VERSION $PF"
hook_error="error: a git hook (pre-commit or another) changed the release commit, which must hold the version lines"
hook_error="$hook_error of VERSION $PF with version 0.2.0 and nothing else. The commit had:"
new_case hooknew
hook 'echo x >>other && git add other'
head=$(g rev-parse HEAD) out_before=$(refs_out)
mr '' 0.2.0 --yes
check "a hook that stages another file: the release commit is undone, exit 1" \
  '[ $RC = 1 ] && line "$hook_error" && [ "$(g rev-parse HEAD)" = "$head" ] && [ "$(refs_out)" = "$out_before" ]'
check "...it names the files the commit had, the extra one too, and how to commit past the hook" \
  'has "$(printf "  %s\n  VERSION\n  other\n" "$PF")" && has "scripts/make-release.sh 0.2.0 --no-commit, then" &&
    line "$no_verify"'
check "...VERSION and project.pbxproj are back in the tree and the index, the hook's file is left untracked" \
  'files_are 0.1.0 && [ "$(g status --porcelain)" = "?? other" ]'
new_case hooktracked
hook 'echo x >>README && git add README'
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a hook that stages a tracked file: the commit is undone, the hook's change is left unstaged" \
  '[ $RC = 1 ] && line "  README" && [ "$(g rev-parse HEAD)" = "$head" ] && files_are 0.1.0 &&
    [ "$(g status --porcelain)" = " M README" ]'
new_case hookversion
hook 'echo 9.9.9 >VERSION && git add VERSION'
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a hook that rewrites the version in VERSION: the commit is undone, VERSION restored all the same" \
  '[ $RC = 1 ] && has "changed the release commit" && [ "$(g rev-parse HEAD)" = "$head" ] && files_are 0.1.0 && clean &&
    has "The commit is undone and VERSION $PF restored; what the hook changed in other files is still there"'
new_case hookproject
hook "sed 's/= 0.2.0;/= 9.9.9;/' $PF >.git/p && cat .git/p >$PF && git add $PF"
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a hook that rewrites the MARKETING_VERSION lines: the commit is undone" \
  '[ $RC = 1 ] && has "changed the release commit" && [ "$(g rev-parse HEAD)" = "$head" ] && files_are 0.1.0 && clean'
new_case hookline
hook "echo '// formatted' >>$PF && git add $PF"
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a hook that adds a line to project.pbxproj: the commit is undone" \
  '[ $RC = 1 ] && has "changed the release commit" && line "  $PF" && [ "$(g rev-parse HEAD)" = "$head" ] &&
    files_are 0.1.0 && clean'
new_case hookfail
hook 'exit 1'
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a failing hook: no commit, VERSION and project.pbxproj are back" \
  '[ $RC = 1 ] && has "error: git commit failed; VERSION $PF restored." && [ "$(g rev-parse HEAD)" = "$head" ] &&
    files_are 0.1.0 && clean'
new_case hookfail-changed
hook "echo '// formatted' >>$PF; exit 1"
head=$(g rev-parse HEAD)
mr '' 0.2.0 --yes
check "a failing hook that changed project.pbxproj: no commit, VERSION restored, project.pbxproj left as it is" \
  '[ $RC = 1 ] && has "error: git commit failed; VERSION restored; $PF $kept." && [ "$(g rev-parse HEAD)" = "$head" ] &&
    [ "$(cat "$REPO/VERSION")" = 0.1.0 ] && { pbxproj 0.2.0 && echo "// formatted"; } | cmp -s - "$REPO/$PF"'
new_case hookok
hook "git add VERSION $PF"
before=$(count)
mr '' 0.2.0 --yes
check "a hook that stages only the version files (a formatter) keeps the release commit" \
  '[ $RC = 0 ] && [ "$(count)" = $((before + 1)) ] && release_commit 0.1.0 0.2.0 && clean'

# --- the confirmation, --no-commit, options
new_case decline
before=$(count)
mr '0.2.0\nn\n'
check "a declined commit puts VERSION and project.pbxproj back, exit 1" \
  '[ $RC = 1 ] && has "Cancelled: VERSION $PF restored, no commit." && files_are 0.1.0 && [ "$(count)" = "$before" ] &&
    clean'
mr '\nno\n'
check "...'no' declines too" '[ $RC = 1 ] && has "Cancelled:" && files_are 0.1.0 && [ "$(count)" = "$before" ] && clean'
mr '0.2.0\n'
check "end of input at the confirmation puts them back" \
  '[ $RC = 1 ] && has "error: input ended; VERSION $PF restored." && files_are 0.1.0 && [ "$(count)" = "$before" ] &&
    clean'
mr '0.2.0\nYES\n'
check "'YES' confirms" '[ $RC = 0 ] && release_commit 0.1.0 0.2.0 && clean'

new_case nocommit
before=$(count)
mr '' 0.2.0 --no-commit
check "--no-commit writes VERSION and project.pbxproj and commits nothing" \
  '[ $RC = 0 ] && files_are 0.2.0 && [ "$(count)" = "$before" ] &&
    [ "$(g status --porcelain)" = "$(printf " M %s\n M VERSION" "$PF")" ] &&
    line "VERSION $PF: version 0.2.0. No commit (--no-commit). Commit only these files:"'
check "...the change is the version lines only" \
  '[ "$(g diff --numstat)" = "$(printf "2\t2\t%s\n1\t1\tVERSION" "$PF")" ]'
commit_cmd="  git commit -m 'feat: release - version 0.2.0' -- VERSION $PF"
check "...shows the diff and the commit command" \
  'line "-0.1.0" && line "+0.2.0" && line "-$(mvl 0.1.0)" && line "+$(mvl 0.2.0)" && line "$commit_cmd"'
printed="$(printf '%s\n' "$OUT" | sed -n 's/^  git commit -m /git commit -m /p')"
(cd "$REPO" && eval "$printed") >/dev/null
check "...that command, run as printed, makes the release commit" \
  '[ -n "$printed" ] && release_commit 0.1.0 0.2.0 && clean'
g reset -q --hard HEAD^
mr '\n' --no-commit
check "--no-commit at the prompt: Enter writes 0.2.0, no question" \
  '[ $RC = 0 ] && files_are 0.2.0 && ! has "[Y/n]" && [ "$(count)" = "$before" ]'
g checkout -q -- VERSION "$PF"
mr '' --yes --no-commit
check "--yes --no-commit: 0.2.0 written, no question, no commit" \
  '[ $RC = 0 ] && files_are 0.2.0 && ! has "[Y/n]" && [ "$(count)" = "$before" ]'
g checkout -q -- VERSION "$PF"

new_case options
before=$(count)
usage_line="  scripts/make-release.sh [X.Y.Z|patch|minor|major] [--yes] [--no-commit]"
mr '' --bogus
check "an unknown option is a usage error, exit 2" \
  '[ $RC = 2 ] && line "error: unknown option --bogus" && line "$usage_line"'
mr '' --push
check "--push is not an option: the script never pushes" '[ $RC = 2 ] && line "error: unknown option --push"'
mr '' 0.2.0 0.3.0
check "the version given twice is a usage error, exit 2" \
  '[ $RC = 2 ] && line "error: the version is given twice: 0.2.0 and 0.3.0" && line "$usage_line"'
mr '' patch 0.3.0
check "...a bump word and a version too" '[ $RC = 2 ] && line "error: the version is given twice: patch and 0.3.0"'
mr '' --help
check "--help prints the usage, exit 0" \
  '[ $RC = 0 ] && has "Prepares an Overbright release" && line "$usage_line" && ! has "Current version"'
mr '' -h
check "-h prints the usage, exit 0" \
  '[ $RC = 0 ] && line "  --no-commit    only write the version, no commit" && line "$usage_line" &&
    ! has "Current version"'
mr '' 0.2.0 --yes -h
check "...whatever else is given" '[ $RC = 0 ] && line "$usage_line" && ! has "New version"'
check "...options change nothing" 'files_are 0.1.0 && [ "$(count)" = "$before" ] && clean'

# --- while the script waits at its question: a version file changed meanwhile (Xcode rewrites project.pbxproj
# whenever it saves a setting), a signal. The script runs in the background (mr_bg), its stdin a FIFO this test
# holds open on fd 3: an answer is a write there. Every wait is bounded: a script that hangs is killed and fails its
# check.

# within <condition (eval'd)>: whether the condition holds within 10 s (polled every 0.05 s)
within() {
  local i=0
  until eval "$1"; do
    [ "$i" -lt 200 ] || return 1
    sleep 0.05
    i=$((i + 1))
  done
}
# mr_bg [args...]: starts make-release.sh of REPO in the background, from WORK, as mr runs it; its stdin is the FIFO
# CASE/in, which fd 3 of this test holds open (read-write: that open waits for no reader; the script sees the end of
# input once fd 3 is closed), its output goes to CASE/out; sets PID, the script's own bash. Job control (set -m)
# starts it with SIGINT as this test has it: without it bash 3.2 starts a background command with SIGINT ignored,
# which no trap undoes.
mr_bg() {
  rm -f "$CASE/in"
  mkfifo "$CASE/in"
  : >"$CASE/out"
  exec 3<>"$CASE/in"
  set -m
  (cd "$WORK" && exec "$BASH_BIN" "$REPO/scripts/make-release.sh" "$@") <"$CASE/in" >"$CASE/out" 2>&1 3>&- &
  PID=$!
  set +m
}
# ended: the script's bash has ended; asks: its output so far has the [Y/n] question
ended() { ! kill -0 "$PID" 2>/dev/null; }
asks() { case "$(cat "$CASE/out")" in *'"? [Y/n] '*) return 0 ;; esac; return 1; }
# asked: waits until the script asks [Y/n]; fails when it ends first or does not ask within 10 s
asked() { within 'asks || ended' && asks; }
# mr_end: waits until the script ends, at most 10 s (then kills it: RC=killed), and closes fd 3; sets OUT and RC
mr_end() {
  if within ended; then
    wait "$PID"
    RC=$?
  else
    kill -KILL "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    RC=killed
  fi
  exec 3>&-
  OUT="$(cat "$CASE/out")"
}
# trappable <signal>: whether a bash this test starts can trap the signal. One that was ignored when this test started
# (nohup ignores HUP; a non-interactive shell starts a background command with INT ignored) stays ignored in every
# bash it starts, which no trap changes: the checks that send it are skipped then.
trappable() {
  set -m
  "$BASH_BIN" -c 'trap "exit 7" "$1"; kill -s "$1" $$; exit 0' sh "$1" </dev/null >/dev/null 2>&1 &
  set +m
  wait "$!"
  [ $? = 7 ]
}
# xcode_saves: project.pbxproj changes as when Xcode saves a setting (CURRENT_PROJECT_VERSION 1 becomes 2); CASE/saved
# is what it holds then
xcode_saves() {
  sed 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = 2;/' "$REPO/$PF" >"$CASE/saved" &&
    cat "$CASE/saved" >"$REPO/$PF"
}
changed_error="error: $PF changed while the script waited, so nothing is committed: VERSION restored; $PF $kept. Undo"
changed_error="$changed_error the new version lines there (git checkout -p -- $PF) or commit the other change first,"
changed_error="$changed_error then run the script again."

new_case changed-yes
head=$(g rev-parse HEAD)
mr_bg 0.2.0
asked && xcode_saves && printf 'y\n' >&3
mr_end
check "project.pbxproj changed while [Y/n] waits, then y: exit 1, no commit" \
  '[ $RC = 1 ] && has "$changed_error" && [ "$(g rev-parse HEAD)" = "$head" ]'
check "...VERSION restored, project.pbxproj as saved meanwhile (the new version lines in it), nothing staged" \
  '[ "$(cat "$REPO/VERSION")" = 0.1.0 ] && cmp -s "$CASE/saved" "$REPO/$PF" &&
    [ "$(g status --porcelain)" = " M $PF" ]'
new_case changed-no
head=$(g rev-parse HEAD)
mr_bg 0.2.0
asked && xcode_saves && printf 'n\n' >&3
mr_end
check "...then n: cancelled, exit 1, no commit, VERSION restored, project.pbxproj left as it is" \
  '[ $RC = 1 ] && has "Cancelled: VERSION restored; $PF $kept, no commit." && [ "$(g rev-parse HEAD)" = "$head" ] &&
    [ "$(cat "$REPO/VERSION")" = 0.1.0 ] && cmp -s "$CASE/saved" "$REPO/$PF"'
new_case changed-eof
head=$(g rev-parse HEAD)
mr_bg 0.2.0
asked && echo 0.2.1 >"$REPO/VERSION" && exec 3>&-
mr_end
check "VERSION changed while [Y/n] waits, then the end of input: exit 1, no commit, VERSION left as it is" \
  '[ $RC = 1 ] && line "error: input ended; $PF restored; VERSION $kept." && [ "$(g rev-parse HEAD)" = "$head" ] &&
    [ "$(cat "$REPO/VERSION")" = 0.2.1 ] && pbxproj 0.1.0 | cmp -s - "$REPO/$PF"'

# a signal while [Y/n] waits: the trap runs inside "IFS= read", where "${files[*]}" would join the names without
# their space
for c in TERM:143 HUP:129 INT:130; do
  sig=${c%:*} want=${c#*:}
  if ! trappable "$sig"; then
    echo "# skipped: $sig while [Y/n] waits (this test started with $sig ignored, and so does every bash it starts)"
    continue
  fi
  new_case "signal-$sig"
  head=$(g rev-parse HEAD)
  mr_bg 0.2.0
  asked && kill -s "$sig" "$PID"
  mr_end
  check "$sig while [Y/n] waits: exit $want, no commit, 'Interrupted: VERSION $PF restored.'" \
    '[ $RC = "$want" ] && line "Interrupted: VERSION $PF restored." && [ "$(g rev-parse HEAD)" = "$head" ] &&
      files_are 0.1.0 && clean'
done
if trappable TERM; then
  new_case signal-changed
  head=$(g rev-parse HEAD)
  mr_bg 0.2.0
  asked && xcode_saves && kill -s TERM "$PID"
  mr_end
  check "TERM while [Y/n] waits, project.pbxproj changed meanwhile: exit 143, VERSION restored, project.pbxproj kept" \
    '[ $RC = 143 ] && line "Interrupted: VERSION restored; $PF $kept." && [ "$(g rev-parse HEAD)" = "$head" ] &&
      [ "$(cat "$REPO/VERSION")" = 0.1.0 ] && cmp -s "$CASE/saved" "$REPO/$PF"'

  # TERM while git commit runs a post-commit hook: bash runs the trap once git commit ends, the commit made
  new_case signal-hook
  # the hook says it runs, then waits until this test lets it end (at most 10 s)
  hook ': >.git/hook-runs; i=0; while [ ! -e .git/hook-ends ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i + 1)); done' \
    post-commit
  head=$(g rev-parse HEAD)
  mr_bg 0.2.0 --yes
  within '[ -e "$REPO/.git/hook-runs" ] || ended' && kill -s TERM "$PID"
  : >"$REPO/.git/hook-ends"
  mr_end
  check "TERM while a post-commit hook runs: exit 143 once git commit ends, the release commit is undone" \
    '[ $RC = 143 ] && line "Interrupted: the release commit is undone, VERSION $PF restored." &&
      [ "$(g rev-parse HEAD)" = "$head" ]'
  check "...VERSION and project.pbxproj restored, nothing staged" 'files_are 0.1.0 && clean'
else
  echo "# skipped: TERM with a file changed meanwhile, TERM in a post-commit hook (this test started with TERM ignored)"
fi

# --- branches
new_case branch
g checkout -q -b feature
head=$(g rev-parse main) out_before=$(refs_out)
want="warning: you are on feature, and releases go out from main: this commit is released once it is merged into main."
mr '' 0.2.0 --yes
check "a branch other than main: a warning, then the commit on that branch" \
  '[ $RC = 0 ] && line "$want" && [ "$(g symbolic-ref --short HEAD)" = feature ] && release_commit 0.1.0 0.2.0 &&
    [ "$(g rev-parse main)" = "$head" ] && [ "$(refs_out)" = "$out_before" ]'
check "...and says to push that branch" 'has "Push it (git push origin feature): release 0.2.0"'
# a repository pushed rather than cloned has no origin/HEAD: origin's main is the default branch then
g update-ref -d refs/remotes/origin/HEAD
mr '' 0.3.0 --yes
check "...the same without origin/HEAD" '[ $RC = 0 ] && line "$want" && release_commit 0.2.0 0.3.0'
new_case detached
g checkout -q --detach
mr '' 0.2.0 --yes
check "a detached HEAD is refused" \
  '[ $RC = 1 ] && files_are 0.1.0 && clean &&
    line "error: HEAD is not on a branch (detached HEAD): switch to one first, for example git switch main."'
new_case behind
git clone -q "$CASE/origin.git" "$CASE/other"
echo other >>"$CASE/other/README"
git -C "$CASE/other" commit -q -am 'Fix other'
git -C "$CASE/other" push -q origin main
g fetch -q origin
head=$(g rev-parse HEAD) out_before=$(refs_out)
mr '' 0.2.0 --yes
check "a branch behind origin: a warning to pull first, the commit is still made locally" \
  '[ $RC = 0 ] && line "warning: main is 1 commit(s) behind origin/main (as of the last fetch): git pull first." &&
    [ "$(g rev-parse HEAD^)" = "$head" ] && release_commit 0.1.0 0.2.0 && [ "$(refs_out)" = "$out_before" ]'

# --- no origin
new_case noorigin
g remote remove origin
before=$(count)
mr '' --yes
check "without origin: the local tags count, no warning, the commit is made" \
  '[ $RC = 0 ] && ! has "warning" && line "Last release tag: v0.1.0" && release_commit 0.1.0 0.2.0 &&
    [ "$(count)" = $((before + 1)) ]'
check "...and it says to add the GitHub repository" \
  'has "Add the GitHub repository (git remote add origin <url>) and push: release 0.2.0 (tag v0.2.0) goes out"'
g branch -q -m main dev
mr '' --yes
check "neither origin nor main or master: a warning, the commit is made" \
  '[ $RC = 0 ] && line "warning: the default branch is unknown; releases go out from main only." &&
    release_commit 0.2.0 0.3.0'

# --- git settings that change what git prints: diff.orderFile reorders the paths of a diff, column.ui=always puts
# the tags git tag -l lists side by side
new_case orderfile
printf '%s\n' VERSION '*' >"$CASE/order"
git config --global diff.orderFile "$CASE/order"
mr '' --yes
check "a global diff.orderFile that lists VERSION first (git diff does): the release is committed" \
  '[ $RC = 0 ] && [ "$(g diff --numstat HEAD^ HEAD | cut -f 3)" = "$(printf "VERSION\n%s" "$PF")" ] &&
    release_commit 0.1.0 0.2.0 && clean'
git config --global --unset diff.orderFile
g config diff.orderFile "$CASE/order"
mr '\n\n'
check "...the repository's diff.orderFile: the same" \
  '[ $RC = 0 ] && [ "$(g diff --numstat HEAD^ HEAD | cut -f 3)" = "$(printf "VERSION\n%s" "$PF")" ] &&
    release_commit 0.2.0 0.3.0 && clean'

new_case columns
g remote remove origin
g tag v0.9.0
g tag v0.10.0
g config column.ui always
mr '\n\n'
check "column.ui=always (git tag -l puts the tags on one line), local tags v0.1.0 v0.9.0 v0.10.0: last tag v0.10.0" \
  '[ "$(COLUMNS=80 git -C "$REPO" tag -l | wc -l | tr -d " ")" = 1 ] && line "Last release tag: v0.10.0" &&
    line "Next: 0.10.1 (patch), 0.11.0 (minor), 1.0.0 (major)." && has "New version [0.11.0]: "'
check "...Enter takes 0.11.0 and commits it" '[ $RC = 0 ] && release_commit 0.1.0 0.11.0 && clean'

# The script reads its diffs with -O/dev/null and shows the release's with --no-ext-diff, so neither setting stops it
# half-way with the version written. A diff.orderFile git cannot read fails git commit itself (any commit): the
# script gets that far and restores the files. A diff.external program that fails breaks only the user's own diffs:
# the release is committed. The settings go before the checks, whose own git diff would trip over them.
new_case badorder
g config diff.orderFile "$CASE/no-such-file"
mr '' 0.2.0 --yes
g config --unset diff.orderFile
check "a diff.orderFile git cannot read: git commit fails on it, and the script restores the files" \
  '[ $RC = 1 ] && has "error: git commit failed; VERSION $PF restored." && files_are 0.1.0 && clean'
new_case extdiff
g config diff.external false
mr '' 0.2.0 --yes
g config --unset diff.external
check "a diff.external program that fails: the release is committed all the same" \
  '[ $RC = 0 ] && release_commit 0.1.0 0.2.0 && clean'

# A git command that fails after the version is written (here a stale index.lock: git commit, then the checkout of
# the files) is reported as it is: the files are NOT restored, and the script says so instead of "restored"
new_case indexlock
: >"$REPO/.git/index.lock"
mr '' 0.2.0 --yes
rm -f "$REPO/.git/index.lock"
check "a stale .git/index.lock: git commit fails, and the files are reported NOT restored, still at 0.2.0" \
  '[ $RC = 1 ] && files_are 0.2.0 && [ "$(g rev-parse HEAD)" = "$(git -C "$CASE/origin.git" rev-parse main)" ] &&
    has "error: git commit failed; VERSION $PF NOT restored: git checkout failed (see above), so undo the version lines by hand."'

# An exported CDPATH with a scripts/ of its own: the script, run as scripts/make-release.sh, finds itself all the same
new_case cdpath
mkdir -p "$CASE/elsewhere/scripts"
export CDPATH="$CASE/elsewhere"
from "$REPO" scripts/make-release.sh 0.2.0 --yes
unset CDPATH
check "an exported CDPATH with a scripts/ of its own: scripts/make-release.sh commits the release" \
  '[ $RC = 0 ] && release_commit 0.1.0 0.2.0 && clean'

# --- the last version with at most 9 digits per number
new_case limit
set_version 0.999999999.0
before=$(count) head=$(g rev-parse HEAD)
mr '\n\n'
check "prompt: only the bumps that are versions are offered, Enter takes the major one" \
  'line "Next: 0.999999999.1 (patch), 1.0.0 (major)." && has "New version [1.0.0]: " && ! has "0.1000000000.0" &&
    [ $RC = 0 ] && release_commit 0.999999999.0 1.0.0'
g reset -q --hard "$head"
mr '0.1000000000.0\nminor\n1.0.0\nn\n'
check "prompt: 0.1000000000.0, typed or as minor, is refused" \
  '[ $RC = 1 ] && [ "$(printf "%s\n" "$OUT" | grep -cF "$(not_version 0.1000000000.0 1.0.0)")" = 2 ] &&
    files_are 0.999999999.0 && clean'
mr '' minor --yes
check "argument minor, 0.1000000000.0, is refused" \
  '[ $RC = 1 ] && has "error: $(not_version 0.1000000000.0 1.0.0)." && files_are 0.999999999.0 && clean'
mr '' --yes
check "--yes takes 1.0.0 then, never 0.1000000000.0" '[ $RC = 0 ] && release_commit 0.999999999.0 1.0.0'
g reset -q --hard "$head"
mr '' patch --yes
check "...while patch, 0.999999999.1, is taken" '[ $RC = 0 ] && release_commit 0.999999999.0 0.999999999.1'
g reset -q --hard "$head"
set_version 999999999.999999999.999999999
before=$(count)
mr '' --yes
check "after 999999999.999999999.999999999 there is no version: refused, nothing changed" \
  '[ $RC = 1 ] &&
    has "error: no version after 999999999.999999999.999999999 fits X.Y.Z with at most 9 digits per number." &&
    files_are 999999999.999999999.999999999 && [ "$(count)" = "$before" ] && clean'
mr '\n\n'
check "...without --yes the same, before any question" \
  '[ $RC = 1 ] && ! has "New version [" &&
    has "error: no version after 999999999.999999999.999999999 fits X.Y.Z with at most 9 digits per number." &&
    files_are 999999999.999999999.999999999 && [ "$(count)" = "$before" ] && clean'

# the minor and major numbers at their limit: the patch bump is the one version left, and Enter and --yes take it
new_case patch-only
g tag -d v0.1.0 >/dev/null
git -C "$CASE/origin.git" tag -d v0.1.0 >/dev/null
set_version 999999999.999999999.5
head=$(g rev-parse HEAD) last=999999999.999999999.6
mr '\n\n'
check "999999999.999999999.5, no tags: the prompt offers only the patch bump, $last" \
  'line "No release tag yet." && line "Next: $last (patch)." && has "New version [$last]: "'
check "...Enter takes it, Enter commits it" '[ $RC = 0 ] && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr 'patch\n\n'
check "...'patch' at the prompt: $last" '[ $RC = 0 ] && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr "$last"'\n\n'
check "...'$last' at the prompt" '[ $RC = 0 ] && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr '' --yes
check "...--yes takes $last, without a question" \
  '[ $RC = 0 ] && line "New version: $last" && ! has "[Y/n]" && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr '' patch --yes
check "...the argument patch: $last" '[ $RC = 0 ] && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr '' "$last" --yes
check "...the argument $last" '[ $RC = 0 ] && release_commit 999999999.999999999.5 "$last" && clean'
g reset -q --hard "$head"
mr '' minor --yes
check "...the argument minor, 999999999.1000000000.0, is refused" \
  '[ $RC = 1 ] && has "error: $(not_version 999999999.1000000000.0 "$last")." && files_are 999999999.999999999.5 &&
    [ "$(g rev-parse HEAD)" = "$head" ] && clean'
mr '' major --yes
check "...the argument major, 1000000000.0.0, is refused" \
  '[ $RC = 1 ] && has "error: $(not_version 1000000000.0.0 "$last")." && files_are 999999999.999999999.5 &&
    [ "$(g rev-parse HEAD)" = "$head" ] && clean'

# --- the current version: above every tag, or no version at all
new_case ahead
set_version 0.3.0
mr ''
check "a version above every tag: says it is not released yet and suggests its next minor version" \
  'line "Current version:  0.3.0 (VERSION)" && line "$(unreleased 0.3.0)" &&
    line "Next: 0.3.1 (patch), 0.4.0 (minor), 1.0.0 (major)." && has "New version [0.4.0]: "'
mr '' Patch --no-commit
check "'Patch' bumps the current version when it is above every tag: 0.3.1" '[ $RC = 0 ] && files_are 0.3.1'
g checkout -q -- VERSION "$PF"
mr '' 0.2.0 --yes
check "a version between the highest tag and the current version is refused" \
  '[ $RC = 1 ] && has "error: version 0.2.0 is not higher than the current version 0.3.0." && files_are 0.3.0 && clean'
for v in x v0.3.0 0.3 01.3.0 1234567890.0.0 '0.3.0 0.4.0'; do
  printf '%s\n' "$v" >"$REPO/VERSION"
  g commit -q -am "VERSION $v"
  before=$(count)
  want="error: VERSION holds '$v', not X.Y.Z (no leading zeros, no 'v', at most 9 digits per number): fix it by hand"
  want="$want and commit it."
  mr '' --yes 0.4.0
  check "VERSION '$v' is refused, nothing changed" \
    '[ $RC = 1 ] && line "$want" && [ "$(cat "$REPO/VERSION")" = "$v" ] && [ "$(count)" = "$before" ] && clean'
done
for v in '' ' \n\n' '0.3.0\n0.3.0'; do
  printf '%b\n' "$v" >"$REPO/VERSION"
  g commit -q -am "VERSION $v"
  before=$(count)
  mr '' --yes 0.4.0
  check "VERSION '$v' (no line, or two) is refused, nothing changed" \
    '[ $RC = 1 ] && line "error: VERSION must hold the version alone, one line X.Y.Z: fix it by hand and commit it." &&
      [ "$(count)" = "$before" ] && clean'
done

# --- project.pbxproj: MARKETING_VERSION lines with another version, or none
new_case mismatch
pbxproj 0.1.0 0.0.9 >"$REPO/$PF"
g commit -q -am 'Release configuration at 0.0.9'
mr '' --yes
check "a MARKETING_VERSION other than VERSION's: a warning" \
  'line "warning: $PF has MARKETING_VERSION 0.1.0 0.0.9, VERSION 0.1.0: both get the new version."'
check "...both files get 0.2.0, in one release commit" \
  '[ $RC = 0 ] && files_are 0.2.0 && [ "$(subject)" = "feat: release - version 0.2.0" ] &&
    [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "2\t2\t%s\n1\t1\tVERSION" "$PF")" ] && clean'
new_case mismatch-all
pbxproj 0.0.9 >"$REPO/$PF"
g commit -q -am 'MARKETING_VERSION 0.0.9'
mr '\n\n'
check "every MARKETING_VERSION line with another version: the warning, both files get 0.2.0" \
  '[ $RC = 0 ] && line "warning: $PF has MARKETING_VERSION 0.0.9, VERSION 0.1.0: both get the new version." &&
    files_are 0.2.0 && [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "2\t2\t%s\n1\t1\tVERSION" "$PF")" ] && clean'
new_case mismatch-new
pbxproj 0.2.0 0.1.0 >"$REPO/$PF"
g commit -q -am 'Debug at 0.2.0'
mr '' 0.2.0 --yes
check "a MARKETING_VERSION line that already reads '= 0.2.0;' stays as it is" \
  '[ $RC = 0 ] && files_are 0.2.0 && [ "$(subject)" = "feat: release - version 0.2.0" ] &&
    [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "1\t1\t%s\n1\t1\tVERSION" "$PF")" ] && clean'
new_case mismatch-done
pbxproj 0.2.0 >"$REPO/$PF"
g commit -q -am 'MARKETING_VERSION 0.2.0'
mr '' 0.2.0 --yes
check "every MARKETING_VERSION line at the new version already: the commit changes VERSION alone" \
  '[ $RC = 0 ] && files_are 0.2.0 && [ "$(subject)" = "feat: release - version 0.2.0" ] &&
    [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "1\t1\tVERSION")" ] && clean'
# a line with the new version that does not read exactly "= X.Y.Z;" (quoted, spaced otherwise, blanks after ";") is
# rewritten all the same, and the release commit has it too
new_case quoted
pbxproj '"0.2.0"' 0.1.0 >"$REPO/$PF"
g commit -q -am 'Debug at "0.2.0"'
mr '\n\n'
check "a MARKETING_VERSION line that holds \"0.2.0\" in quotes: the warning, Enter takes 0.2.0" \
  'line "warning: $PF has MARKETING_VERSION 0.2.0 0.1.0, VERSION 0.1.0: both get the new version." &&
    has "New version [0.2.0]: "'
check "...both lines end as '= 0.2.0;', committed with VERSION" \
  '[ $RC = 0 ] && files_are 0.2.0 && [ "$(subject)" = "feat: release - version 0.2.0" ] &&
    [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "2\t2\t%s\n1\t1\tVERSION" "$PF")" ] && clean'
tab="$(printf '\t')"
for c in "unspaced|MARKETING_VERSION=0.2.0;|no blanks around '='" \
  "blanks|MARKETING_VERSION = 0.2.0; $tab|a blank and a tab after ';'"; do
  name=${c%%|*} text=${c#*|} what=${c##*|}
  text=${text%|*}
  new_case "line-$name"
  p="$(pbxproj 0.2.0 0.1.0)"
  printf '%s\n' "${p/MARKETING_VERSION = 0.2.0;/$text}" >"$REPO/$PF"
  g commit -q -am "Debug at 0.2.0, $what"
  mr '' 0.2.0 --yes
  check "a MARKETING_VERSION line at 0.2.0 with $what: rewritten too, both lines end as '= 0.2.0;'" \
    '[ $RC = 0 ] && [ "$(cat "$REPO/VERSION")" = 0.2.0 ] && [ "$(grep -c "= 0\.2\.0;\$" "$REPO/$PF")" = 2 ] &&
      [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "2\t2\t%s\n1\t1\tVERSION" "$PF")" ] && clean'
done

new_case nomarketing
pbxproj 0.1.0 | grep -v 'MARKETING_VERSION = ' >"$REPO/$PF"
g commit -q -am 'No MARKETING_VERSION'
cp "$REPO/$PF" "$CASE/project.before"
before=$(count)
mr '\n' --no-commit
check "project.pbxproj without MARKETING_VERSION lines: a warning" \
  '[ $RC = 0 ] && line "warning: $PF has no MARKETING_VERSION line: only VERSION gets the new version."'
check "...--no-commit writes VERSION alone and names it alone" \
  '[ "$(cat "$REPO/VERSION")" = 0.2.0 ] && cmp -s "$REPO/$PF" "$CASE/project.before" &&
    line "VERSION: version 0.2.0. No commit (--no-commit). Commit only these files:" &&
    line "  git commit -m '\''feat: release - version 0.2.0'\'' -- VERSION"'
g checkout -q -- VERSION
mr '\n\n'
check "...the question names VERSION alone" 'has "Commit VERSION as \"feat: release - version 0.2.0\"? [Y/n] "'
check "...only VERSION is committed, project.pbxproj untouched" \
  '[ $RC = 0 ] && [ "$(cat "$REPO/VERSION")" = 0.2.0 ] && cmp -s "$REPO/$PF" "$CASE/project.before" &&
    [ "$(subject)" = "feat: release - version 0.2.0" ] && [ "$(g diff --numstat HEAD^ HEAD)" = "$(printf "1\t1\tVERSION")" ] &&
    [ "$(count)" = $((before + 1)) ] && clean'

# --- the script run from another directory, by a relative path
new_case relative
mkdir -p "$CASE/elsewhere"
from "$CASE/elsewhere" ../repo/scripts/make-release.sh --yes
check "run from another directory by a relative path" '[ $RC = 0 ] && release_commit 0.1.0 0.2.0 && clean'
from "$REPO/scripts" make-release.sh --yes
check "...from scripts/ by its bare name" '[ $RC = 0 ] && release_commit 0.2.0 0.3.0 && clean'
from "$REPO" scripts/make-release.sh --yes
check "...from the repository root as scripts/make-release.sh (make release)" \
  '[ $RC = 0 ] && release_commit 0.3.0 0.4.0 && clean'
ln -s "$REPO" "$CASE/link"
from "$CASE" link/scripts/make-release.sh --yes
check "...through a symbolic link to the repository" '[ $RC = 0 ] && release_commit 0.4.0 0.5.0 && clean'

# --- outside a git repository, without commits, version files not in git, a script not in the repository root
REPO="$WORK/plain"
mkdir -p "$REPO/scripts/lib" "$REPO/Overbright.xcodeproj"
cp "$TREE/scripts/make-release.sh" "$REPO/scripts/"
cp "$TREE/scripts/lib/version.sh" "$REPO/scripts/lib/"
echo 0.1.0 >"$REPO/VERSION"
pbxproj 0.1.0 >"$REPO/$PF"
mr '' 0.2.0 --yes
check "outside a git repository it is refused" \
  '[ $RC = 1 ] && has "error: $REPO is not a git repository." && files_are 0.1.0'
mr '' --help
check "...--help works there too" '[ $RC = 0 ] && line "$usage_line"'
git -c init.defaultBranch=main init -q "$REPO"
mr '' 0.2.0 --yes
check "a repository without commits is refused" \
  '[ $RC = 1 ] && line "error: the repository has no commit yet: commit the project first." && files_are 0.1.0'
g add scripts
g commit -q -m scripts
mr '' 0.2.0 --yes
check "a VERSION that is not in git is refused" \
  '[ $RC = 1 ] && line "error: VERSION is not in git: commit it first." && files_are 0.1.0 && [ "$(count)" = 1 ]'
g add VERSION
g commit -q -m VERSION
mr '' 0.2.0 --yes
check "a project.pbxproj that is not in git is refused" \
  '[ $RC = 1 ] && line "error: $PF is not in git: commit it first." && files_are 0.1.0 && [ "$(count)" = 2 ]'
g add -A
g commit -q -m project
mr '' --yes
check "...then, without origin and tags, 0.2.0 is committed" \
  '[ $RC = 0 ] && line "No release tag yet." && release_commit 0.1.0 0.2.0 && clean && [ "$(count)" = 4 ]'

REPO="$WORK/outer/sub"
mkdir -p "$REPO/scripts/lib" "$REPO/Overbright.xcodeproj"
cp "$TREE/scripts/make-release.sh" "$REPO/scripts/"
cp "$TREE/scripts/lib/version.sh" "$REPO/scripts/lib/"
echo 0.1.0 >"$REPO/VERSION"
pbxproj 0.1.0 >"$REPO/$PF"
git -c init.defaultBranch=main init -q "$WORK/outer"
git -C "$WORK/outer" add -A
git -C "$WORK/outer" commit -q -m init
mr '' 0.2.0 --yes
check "a script in a subdirectory of a repository is refused" \
  '[ $RC = 1 ] && line "error: $REPO is not the root of its git repository (the root is $WORK/outer)." &&
    files_are 0.1.0 && [ "$(git -C "$WORK/outer" rev-list --count HEAD)" = 1 ] &&
    [ -z "$(git -C "$WORK/outer" status --porcelain)" ]'

OUT="$(ls -A "$TMPDIR")" RC=0
check "no temp file of the script is left in TMPDIR" '[ -z "$OUT" ]'

echo "# $pass passed, $fail failed"
[ "$fail" = 0 ]
