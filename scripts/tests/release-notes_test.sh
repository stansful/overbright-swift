#!/usr/bin/env bash
# Tests of .github/scripts/release-notes.sh: throwaway repositories in a temp dir (TMPDIR) with release tags (vX.Y.Z
# and X.Y.Z, lightweight and annotated), a merged topic branch, an unmerged side branch and the release commits of
# scripts/make-release.sh, their commits a minute apart. Runs the script under $TEST_BASH (default: bash from PATH).
# The notes are the body of the GitHub release: one "- <commit subject>" line per change, or one line that names the
# first release.
#
#   scripts/tests/release-notes_test.sh          KEEP=1 keeps the temp dir
#
# Prints 'ok <name>' / 'not ok <name>: <why>' and exits non-zero on a failure.
# The conditions of check() are eval'd when it runs: single quotes on purpose, and the variables they read are
# set outside them.
# shellcheck disable=SC2016,SC2034
set -u
# SIGPIPE ignored, as on the GitHub runner (every step inherits that from its Node.js), for these tests and the
# scripts they run: a reader that stops early makes its writer fail with "Broken pipe" there instead of dying quietly
trap "" PIPE
# cd prints the directory it found through an exported CDPATH, which would end up in HERE and WORK
unset CDPATH
# say <line>: a line of the report. A reader that stopped early ends the test: the write fails, and bash 3.2 would keep
# the line and add it to the next file a builtin writes, a fixture or a captured output
say() { printf '%s\n' "$1" || exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd -P)"
TREE="$(cd "$HERE/../.." && pwd -P)"
BASH_BIN="${TEST_BASH:-bash}"
# no temp dir stops here: an empty WORK would make the current directory (the checkout) the work dir, and the
# EXIT trap would delete it
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/release-notes-test.XXXXXX")" || [ -z "$WORK" ] ||
  ! WORK="$(cd "$WORK" && pwd -P)" || [ -z "$WORK" ]; then
  say "not ok no temp dir in ${TMPDIR:-/tmp}"
  exit 1
fi
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$WORK"' EXIT; else say "# work dir: $WORK"; fi

export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
export GIT_CEILING_DIRECTORIES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR \
  GIT_NAMESPACE GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
# what the script reads: a GitHub runner sets GITHUB_SHA for these tests too
unset GITHUB_SHA VERSION
mkdir -p "$HOME"

pass=0 fail=0
ok() {
  say "ok $1"
  pass=$((pass + 1))
}
nok() {
  say "not ok $1: $2"
  fail=$((fail + 1))
}
check() {
  if eval "$2"; then ok "$1"; else nok "$1" "rc=$RC; condition: $2; stdout:
$OUT
stderr: $ERR"; fi
}
# broken <what>: the fixture could not be built, so no check would mean anything: stop here
broken() {
  nok "the test fixture could not be built" "$1"
  say "# $pass passed, $fail failed"
  exit 1
}
has_err() { case $ERR in *"$1"*) return 0 ;; esac; return 1; }
# notes <line...>: the script succeeded, silently, and printed exactly these lines, each ended by a newline
notes() {
  printf '%s\n' "$@" >"$WORK/expected"
  [ "$RC" = 0 ] && [ -z "$ERR" ] && cmp -s "$WORK/expected" "$WORK/out"
}
FIRST="- The first release of Overbright"

say "# .github/scripts/release-notes.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"'), $(git --version)"

# g <git arguments...>: git in REPO; a failure stops the test
g() { git -C "$REPO" "$@" || broken "git -C $REPO $*"; }
# The date of the last commit: each commit is a minute later than the one before, so "newest first" is the reverse of
# the order they are made in
T=1767225600
# c <subject> [body]: a commit of what is staged, often nothing
c() {
  local m=(-m "$1")
  [ $# -lt 2 ] || m+=(-m "$2")
  T=$((T + 60))
  GIT_AUTHOR_DATE="$T +0000" GIT_COMMITTER_DATE="$T +0000" git -C "$REPO" commit -q --allow-empty "${m[@]}" ||
    broken "commit '$1' in $REPO"
}
# merge <branch>: a merge commit of the branch into the current one
merge() {
  T=$((T + 60))
  GIT_AUTHOR_DATE="$T +0000" GIT_COMMITTER_DATE="$T +0000" \
    git -C "$REPO" merge -q --no-ff --no-edit -m "Merge branch '$1'" "$1" || broken "merge $1 in $REPO"
}
# new_repo <dir> <version>: REPO, a repository with release-notes.sh, scripts/lib/version.sh and VERSION <version>,
# its first commit 'Start the project'
new_repo() {
  REPO="$1"
  mkdir -p "$REPO/scripts/lib" "$REPO/.github/scripts"
  cp "$TREE/scripts/lib/version.sh" "$REPO/scripts/lib/" || broken "no scripts/lib/version.sh in $TREE"
  cp "$TREE/.github/scripts/release-notes.sh" "$REPO/.github/scripts/" || broken "no .github/scripts/release-notes.sh"
  echo "$2" >"$REPO/VERSION"
  g -c init.defaultBranch=main init -q
  g symbolic-ref HEAD refs/heads/main
  g add -A
  c 'Start the project'
}
# rn [VAR=value...]: release-notes.sh of REPO, run from WORK; sets OUT (stdout, also in $WORK/out), ERR (stderr), RC
rn() {
  (cd "$WORK" && env "$@" "$BASH_BIN" "$REPO/.github/scripts/release-notes.sh") >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

# main, VERSION 0.11.0: 'Start the project' (annotated tag v0.9.0) - 'Fix the panel' (tag 0.10.0) - 'Add a switch'
# (tag v0.2.0: a lower version on a newer commit) [- side: 'Side work' (tag v0.20.0), never merged] -
# 'feat: release - versioning notes' - 'feat: release - version 0.11.0' - [topic: 'Topic one' - 'Topic two'] merged -
# a last commit with a body
new_repo "$WORK/main" 0.11.0
g tag -a v0.9.0 -m 'Overbright 0.9.0'
c 'Fix the panel'
g tag 0.10.0
c 'Add a switch'
g tag v0.2.0
g checkout -q -b side
c 'Side work'
g tag v0.20.0
g checkout -q main
c 'feat: release - versioning notes'
c 'feat: release - version 0.11.0'
g checkout -q -b topic
c 'Topic one'
c 'Topic two'
g checkout -q main
merge topic
c 'Keep 100% and \n in display names as typed' 'A body line, not a subject.'
SIDE="$(git -C "$REPO" rev-parse side)" || broken "no branch side"
SWITCH="$(git -C "$REPO" rev-parse 'v0.2.0^{commit}')" || broken "no tag v0.2.0"
NOTES=('- Keep 100% and \n in display names as typed' '- Topic two' '- Topic one' '- feat: release - versioning notes'
  '- Add a switch')

rn
check "the subjects since the highest earlier release tag by version, 0.10.0, newest first, as written" \
  'notes "${NOTES[@]}"'
check "...not since the tag of the newest commit (v0.2.0), nor since the highest tag as a string (v0.9.0)" \
  '! grep -qxF -- "- Fix the panel" "$WORK/out" && grep -qxF -- "- Add a switch" "$WORK/out"'
check "...no merge commits, no 'feat: release - version X.Y.Z' commits ('feat: release - versioning notes' is none), no bodies" \
  '! grep -q -e "Merge branch" -e "feat: release - version 0.11.0" -e "body line" "$WORK/out" &&
    grep -qxF -- "- feat: release - versioning notes" "$WORK/out"'
g tag v0.11.0
rn
check "the release's own tag v0.11.0 (a retry: GitHub tagged HEAD) is skipped" 'notes "${NOTES[@]}"'
echo 0.12.0 >"$REPO/VERSION"
rn
check "the version comes from VERSION: for 0.12.0, v0.11.0 on HEAD is the previous release, and nothing is left" \
  'notes "- Release 0.12.0"'
rn VERSION=0.11.0
check "the VERSION variable overrides the file" 'notes "${NOTES[@]}"'
g checkout -q -- VERSION
g tag -d v0.11.0 >/dev/null
rn GITHUB_SHA="$SIDE" VERSION=0.20.0
check "GITHUB_SHA picks the commit: the unmerged side branch, since 0.10.0 there (its own tag v0.20.0 skipped)" \
  'notes "- Side work" "- Add a switch"'
rn GITHUB_SHA="$SWITCH" VERSION=0.10.1
check "...an older commit: no commit after it, and no tag outside its history (v0.20.0 on a later commit)" \
  'notes "- Add a switch"'

# first, VERSION 0.1.0: 'Start the project' - 'Add the panel' [- side: 'Side work' (tag v0.0.5), never merged]
new_repo "$WORK/first" 0.1.0
c 'Add the panel'
rn
check "no release tag at all: '$FIRST'" 'notes "$FIRST"'
for t in not-a-release v1.0 0.1.0-rc1 v01.0.0 1234567890.0.0; do g tag "$t"; done
rn
check "tags that are not vX.Y.Z or X.Y.Z (not-a-release, v1.0, 0.1.0-rc1, v01.0.0, 1234567890.0.0) do not count" \
  'notes "$FIRST"'
g tag v0.1.0
rn
check "the release's own tag v0.1.0 on HEAD (a retry) is no earlier release" 'notes "$FIRST"'
g checkout -q -b side
c 'Side work'
g tag v0.0.5
g checkout -q main
rn
check "a release tag outside the history (v0.0.5 on an unmerged branch) is no earlier release" 'notes "$FIRST"'
rn VERSION=
check "...an empty VERSION variable reads the file" 'notes "$FIRST"'
rn VERSION=0.2.0
check "the VERSION variable overrides the file: for 0.2.0, v0.1.0 on HEAD is the previous release, nothing is left" \
  'notes "- Release 0.2.0"'
echo 0.2.0 >"$REPO/VERSION"
g add VERSION
c 'feat: release - version 0.2.0'
rn
check "only the release commit 'feat: release - version 0.2.0' since v0.1.0: '- Release 0.2.0'" 'notes "- Release 0.2.0"'
rn VERSION=0.2.1
check "...named by the VERSION variable: '- Release 0.2.1'" 'notes "- Release 0.2.1"'

for v in v0.2.0 0.2 0.2.0-rc1 00.2.0 0.2.1234567890 " 0.2.0"; do
  rn VERSION="$v"
  want="release-notes: '$v' is not X.Y.Z"
  check "a VERSION variable '$v' (not X.Y.Z) exits 1" '[ $RC = 1 ] && [ -z "$OUT" ] && [ "$ERR" = "$want" ]'
done
printf '0.2.0\n0.2.0\n' >"$REPO/VERSION"
rn
want="release-notes: '' is not X.Y.Z"
check "a VERSION file with two lines exits 1" '[ $RC = 1 ] && [ -z "$OUT" ] && [ "$ERR" = "$want" ]'
rn VERSION=0.2.0
check "...unless the VERSION variable is given" 'notes "- Release 0.2.0"'
printf 'v0.2.0\n' >"$REPO/VERSION"
rn
want="release-notes: 'v0.2.0' is not X.Y.Z"
check "a VERSION file with v0.2.0 exits 1" '[ $RC = 1 ] && [ -z "$OUT" ] && [ "$ERR" = "$want" ]'
rm -f "$REPO/VERSION"
rn
want="release-notes: '' is not X.Y.Z"
check "no VERSION file exits 1" '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "$want"'

# merges, VERSION 0.2.0: 'Start the project' - [topic: 'Topic work' (tag 0.1.0)] merged -
# 'feat: release - version 0.2.0'
new_repo "$WORK/merges" 0.2.0
g checkout -q -b topic
c 'Topic work'
g tag 0.1.0
g checkout -q main
merge topic
c 'feat: release - version 0.2.0'
rn
check "only a merge commit and a release commit since 0.1.0 (on the merged branch): '- Release 0.2.0'" \
  'notes "- Release 0.2.0"'

say "# $pass passed, $fail failed"
[ "$fail" = 0 ]
