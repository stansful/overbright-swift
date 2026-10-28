#!/usr/bin/env bash
# Tests of .github/scripts/release-state.sh: a throwaway clone of a local bare "origin" with release tags (vX.Y.Z and
# X.Y.Z, lightweight and annotated) in a temp dir (TMPDIR), and a curl stub (first on PATH) in place of the GitHub
# API: it answers with the HTTP status a case sets and logs the URL and the headers it was called with. No network.
# Runs the script under $TEST_BASH (default: bash from PATH).
#
#   scripts/tests/release-state_test.sh          KEEP=1 keeps the temp dir
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
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/release-state-test.XXXXXX")" || [ -z "$WORK" ] ||
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
# what the script reads: a GitHub runner sets GITHUB_API_URL, GITHUB_REPOSITORY and GITHUB_SHA for these tests too
unset GH_TOKEN GITHUB_API_URL GITHUB_REPOSITORY GITHUB_SHA VERSION STUB_STATUS
mkdir -p "$HOME"
# release-state.sh's temp file lands here, an absolute path whatever the caller's TMPDIR (the script runs in REPO):
# the test checks that none is left behind
mkdir -p "$WORK/tmp"
export TMPDIR="$WORK/tmp"

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
  if eval "$2"; then ok "$1"; else nok "$1" "rc=$RC; condition: $2; stdout: $OUT; stderr: $ERR"; fi
}
# broken <what>: the fixture could not be built, so no check would mean anything: stop here
broken() {
  nok "the test fixture could not be built" "$1"
  say "# $pass passed, $fail failed"
  exit 1
}
has_err() { case $ERR in *"$1"*) return 0 ;; esac; return 1; }
# The annotations of a refused version: bad_version <version>, not_higher <version> <tag>, api_error <HTTP status>
# (for release v0.3.0)
bad_version() {
  local want="::error file=VERSION::Version \"$1\" must be X.Y.Z (no leading zeros, no \"v\","
  has_err "$want at most 9 digits per number): it names the release and its tag. Set it with scripts/make-release.sh."
}
not_higher() {
  local want="::error file=VERSION::Version $1 is not higher than the existing tag $2."
  has_err "$want Bump it with scripts/make-release.sh."
}
api_error() { has_err "::error::The GitHub API answered HTTP $1 for release v0.3.0."; }
NO_VERSION="::error file=VERSION::VERSION must hold the version alone, one line X.Y.Z."
# logged <line>: the curl stub logged this line: "url <URL>", "header <header>" or "out <file>"
logged() { grep -qxF -- "$1" "$WORK/curl.log" 2>/dev/null; }
# no_call: curl was not run
no_call() { [ ! -e "$WORK/curl.log" ]; }
# has_auth: curl was given an Authorization header
has_auth() { grep -qi '^header Authorization:' "$WORK/curl.log" 2>/dev/null; }
# body_in_tmp: curl wrote the answer into a file in TMPDIR, and that file is gone, like everything else there
body_in_tmp() {
  local out
  out="$(sed -n 's/^out //p' "$WORK/curl.log")"
  case $out in "$WORK/tmp/"?*) ;; *) return 1 ;; esac
  [ ! -e "$out" ] && [ -z "$(ls -A "$WORK/tmp")" ]
}
API=https://api.github.com/repos/owner/repo/releases/tags

say "# .github/scripts/release-state.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"'), $(git --version)"

# The GitHub API
mkdir -p "$WORK/bin"
cat >"$WORK/bin/curl" <<'EOF'
#!/bin/sh
# curl stub: takes the options release-state.sh passes (-sS, --retry N, --max-time N, -o FILE, -w FORMAT, -H HEADER)
# and the URL, and logs "header <HEADER>" for each header, "url <URL>" and "out <FILE>" to $STUB_LOG. It answers with
# the HTTP status $STUB_STATUS: a body into FILE (stdout without -o), then FORMAT with every %{http_code} replaced by
# the status, as curl prints it. STUB_STATUS=000 is a refused connection (no body, "000", exit 7), STUB_STATUS=none a
# curl that fails before it prints a status (exit 23, as curl 8.5 does when it cannot truncate its output to retry).
url='' out='' format=''
while [ $# -gt 0 ]; do
  case $1 in
  -o | -w | -H | --retry | --max-time)
    if [ $# -lt 2 ]; then
      echo "curl stub: $1 needs a value" >&2
      exit 2
    fi
    case $1 in
    -o) out=$2 ;;
    -w) format=$2 ;;
    -H) printf 'header %s\n' "$2" >>"$STUB_LOG" ;;
    esac
    shift 2
    ;;
  -*) shift ;;
  *)
    url=$1
    shift
    ;;
  esac
done
printf 'url %s\nout %s\n' "$url" "$out" >>"$STUB_LOG"
status=${STUB_STATUS:?}
case $status in
none)
  echo "curl: (23) Failure writing output to destination" >&2
  exit 23
  ;;
000) ;;
200) body="{\"tag_name\":\"${url##*/}\",\"draft\":false}" ;;
404) body='{"message":"Not Found","status":"404"}' ;;
*) body="{\"message\":\"HTTP $status\",\"status\":\"$status\"}" ;;
esac
if [ "$status" != 000 ]; then
  if [ -n "$out" ]; then printf '%s\n' "$body" >"$out"; else printf '%s\n' "$body"; fi
fi
while :; do
  case $format in
  *'%{http_code}'*) format="${format%%"%{http_code}"*}$status${format#*"%{http_code}"}" ;;
  *) break ;;
  esac
done
printf '%s' "$format"
if [ "$status" = 000 ]; then
  echo "curl: (7) Failed to connect to the GitHub API: Connection refused" >&2
  exit 7
fi
EOF
chmod +x "$WORK/bin/curl"
export STUB_LOG="$WORK/curl.log"

# origin: A 'Start the project' (tag 0.1.0) - B 'Add the panel' (annotated tag v0.2.0) - C 'Fix the switch' (tag
# not-a-release), VERSION 0.3.0. REPO is its clone, and GITHUB_SHA is C.
SEED="$WORK/seed" REPO="$WORK/repo"
mkdir -p "$SEED/scripts/lib" "$SEED/.github/scripts"
cp "$TREE/scripts/lib/version.sh" "$SEED/scripts/lib/" || broken "no scripts/lib/version.sh in $TREE"
cp "$TREE/.github/scripts/release-state.sh" "$SEED/.github/scripts/" || broken "no .github/scripts/release-state.sh"
echo 0.3.0 >"$SEED/VERSION"
# g <dir> <git arguments...>: git in that directory; a failure stops the test
g() {
  local dir="$1"
  shift
  git -C "$dir" "$@" || broken "git -C $dir $*"
}
g "$SEED" -c init.defaultBranch=main init -q
g "$SEED" symbolic-ref HEAD refs/heads/main
g "$SEED" add -A
g "$SEED" commit -q -m 'Start the project'
g "$SEED" tag 0.1.0
g "$SEED" commit -q --allow-empty -m 'Add the panel'
g "$SEED" tag -a v0.2.0 -m 'Overbright 0.2.0'
g "$SEED" commit -q --allow-empty -m 'Fix the switch'
g "$SEED" tag not-a-release
git -c init.defaultBranch=main init -q --bare "$WORK/origin.git" || broken "git init --bare origin.git"
g "$WORK/origin.git" symbolic-ref HEAD refs/heads/main
g "$SEED" push -q "$WORK/origin.git" main --tags
git clone -q "$WORK/origin.git" "$REPO" || broken "git clone origin.git"
A="$(git -C "$REPO" rev-parse '0.1.0^{commit}')" || broken "no tag 0.1.0"
B="$(git -C "$REPO" rev-parse 'v0.2.0^{commit}')" || broken "no tag v0.2.0"
C="$(git -C "$REPO" rev-parse HEAD)" || broken "no HEAD"

# rs [env arguments...]: release-state.sh, run in REPO as release.yml runs it, with GITHUB_REPOSITORY=owner/repo,
# GITHUB_SHA=C and an API that answers 404 (no release) unless the arguments say otherwise: VAR=value or -u VAR, as env
# takes them; sets OUT, ERR, RC
rs() {
  rm -f "$WORK/curl.log"
  OUT="$(cd "$REPO" && env PATH="$WORK/bin:$PATH" GITHUB_REPOSITORY=owner/repo GITHUB_SHA="$C" STUB_STATUS=404 \
    env "$@" "$BASH_BIN" .github/scripts/release-state.sh 2>"$WORK/err")"
  RC=$?
  ERR="$(cat "$WORK/err")"
}
# tag_origin <tag> <commit> [annotated]: puts the tag on origin only (the clone does not fetch it)
tag_origin() {
  if [ -n "${3:-}" ]; then
    git -C "$WORK/origin.git" tag -f -a "$1" -m "Overbright $1" "$2" >/dev/null || broken "annotated tag $1 on origin"
  else
    git -C "$WORK/origin.git" tag -f "$1" "$2" >/dev/null || broken "tag $1 on origin"
  fi
}
untag_origin() { git -C "$WORK/origin.git" tag -d "$@" >/dev/null || broken "git tag -d $* on origin"; }

# --- the request
rs
check "new: no release and no tag v0.3.0 of VERSION's 0.3.0" '[ $RC = 0 ] && [ "$OUT" = new ] && [ -z "$ERR" ]'
check "...asks the API for the published release v0.3.0 of GITHUB_REPOSITORY, as JSON, without a token" \
  'logged "url $API/v0.3.0" && logged "header Accept: application/vnd.github+json" && ! has_auth'
check "...the answer goes to a temp file in TMPDIR, not /dev/null (curl 8.5 cannot retry into it), then removed" \
  'body_in_tmp'
rs GH_TOKEN=secret-token
check "GH_TOKEN goes as a bearer token" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && logged "header Authorization: Bearer secret-token" && logged "url $API/v0.3.0"'
rs GH_TOKEN=
check "...an empty GH_TOKEN sends no Authorization header" '[ "$OUT" = new ] && logged "url $API/v0.3.0" && ! has_auth'
rs GITHUB_API_URL=https://ghe.example.invalid/api/v3 GITHUB_REPOSITORY=someone/fork
check "GITHUB_API_URL replaces https://api.github.com, and the repository is GITHUB_REPOSITORY" \
  '[ "$OUT" = new ] && logged "url https://ghe.example.invalid/api/v3/repos/someone/fork/releases/tags/v0.3.0"'
rs VERSION=0.4.0
check "the VERSION variable overrides the file VERSION" '[ $RC = 0 ] && [ "$OUT" = new ] && logged "url $API/v0.4.0"'
rs VERSION=
check "...an empty one reads the file" '[ $RC = 0 ] && [ "$OUT" = new ] && logged "url $API/v0.3.0"'
rm -f "$WORK/curl.log"
OUT="$(cd "$WORK" && env PATH="$WORK/bin:$PATH" GITHUB_REPOSITORY=owner/repo GITHUB_SHA="$C" STUB_STATUS=404 \
  "$BASH_BIN" "$REPO/.github/scripts/release-state.sh" 2>"$WORK/err")"
RC=$? ERR="$(cat "$WORK/err")"
check "...run from another directory it reads the VERSION and the origin of its own checkout" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && [ -z "$ERR" ] && logged "url $API/v0.3.0"'

# --- the tag of the release
tag_origin v1.0 "$A"
tag_origin 9.9.9-rc1 "$A"
tag_origin v01.0.0 "$A"
tag_origin v1234567890.0.0 "$A"
tag_origin release-9.9.9 "$A"
rs
check "tags that are not vX.Y.Z or X.Y.Z (v1.0, 9.9.9-rc1, v01.0.0, v1234567890.0.0, release-9.9.9) do not count" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && [ -z "$ERR" ]'
untag_origin v1.0 9.9.9-rc1 v01.0.0 v1234567890.0.0 release-9.9.9
g "$REPO" tag v9.0.0 "$A"
rs
check "a tag of the checkout that origin does not have does not count" '[ $RC = 0 ] && [ "$OUT" = new ]'
g "$REPO" tag -d v9.0.0 >/dev/null

tag_origin v0.3.0 "$C"
rs
check "retry: the tag v0.3.0 is on GITHUB_SHA, no release" '[ $RC = 0 ] && [ "$OUT" = retry ] && [ -z "$ERR" ]'
tag_origin v0.3.0 "$C" annotated
rs
check "retry: an annotated tag v0.3.0 is followed to its commit, GITHUB_SHA" \
  '[ $RC = 0 ] && [ "$OUT" = retry ] && [ -z "$ERR" ] && [ "$(git -C "$WORK/origin.git" rev-parse v0.3.0)" != "$C" ]'
tag_origin v0.3.0 "$A"
rs
check "a tag v0.3.0 on another commit without a release is refused" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "::error::Tag v0.3.0 points at $A, not $C, and has no release."'
tag_origin v0.3.0 "$B" annotated
rs
check "...an annotated one too, named by its commit" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "::error::Tag v0.3.0 points at $B, not $C, and has no release."'
rs STUB_STATUS=200
check "released: a published release v0.3.0 (HTTP 200), wherever its tag is" \
  '[ $RC = 0 ] && [ "$OUT" = released ] && [ -z "$ERR" ] && logged "url $API/v0.3.0"'
untag_origin v0.3.0
g "$REPO" remote set-url origin "$WORK/missing.git"
rs STUB_STATUS=200
check "released: origin is not even read" '[ $RC = 0 ] && [ "$OUT" = released ] && [ -z "$ERR" ]'
rs
check "unreadable tags of origin are refused" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "::error::Cannot read the tags of origin (git ls-remote)."'
g "$REPO" remote set-url origin "$WORK/origin.git"
rs VERSION=0.1.0 STUB_STATUS=200
check "released: an old version with a published release is released, not refused" \
  '[ $RC = 0 ] && [ "$OUT" = released ] && logged "url $API/v0.1.0"'

# --- higher than every other release tag
rs VERSION=0.1.5
check "a version below a tag vX.Y.Z is refused (0.1.5 below v0.2.0)" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && not_higher 0.1.5 v0.2.0'
tag_origin 0.9.0 "$A"
rs
check "a version below a tag X.Y.Z is refused (0.3.0 below 0.9.0, a tag only on origin)" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && not_higher 0.3.0 0.9.0'
untag_origin 0.9.0
tag_origin 0.3.0 "$C"
rs
check "a version equal to a tag X.Y.Z is refused, even on GITHUB_SHA: the release's tag is v0.3.0" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && not_higher 0.3.0 0.3.0'
untag_origin 0.3.0
tag_origin v0.10.0 "$A" annotated
rs VERSION=0.9.0
check "versions compare as numbers (0.9.0 below v0.10.0)" '[ $RC = 1 ] && [ -z "$OUT" ] && not_higher 0.9.0 v0.10.0'
rs VERSION=0.11.0
check "a higher version is new (0.11.0 above v0.10.0)" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && [ -z "$ERR" ] && logged "url $API/v0.11.0"'
untag_origin v0.10.0

# --- the version
F="$REPO/VERSION"
for v in v0.3.0 0.3 00.3.0 0.03.0 0.3.0-rc1 "0.3.0 0.4.0" 1234567890.0.0 0.3.1234567890; do
  printf '%s\n' "$v" >"$F"
  rs
  check "VERSION '$v' (not X.Y.Z, or a number of more than 9 digits) is refused before any API call" \
    '[ $RC = 1 ] && [ -z "$OUT" ] && bad_version "$v" && no_call'
done
printf '999999999.999999999.999999999\n' >"$F"
rs
check "VERSION with 9 digits per number is fine" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && logged "url $API/v999999999.999999999.999999999"'
printf '\n  0.3.0\t\r\n\n' >"$F"
rs
check "VERSION's blank lines and the blanks around the version (CRLF too) are fine" \
  '[ $RC = 0 ] && [ "$OUT" = new ] && logged "url $API/v0.3.0"'
printf '0.3.0\n0.4.0\n' >"$F"
rs
check "a VERSION file with two versions is refused before any API call" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "$NO_VERSION" && no_call'
: >"$F"
rs
check "an empty VERSION file is refused" '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "$NO_VERSION" && no_call'
rm -f "$F"
rs
check "no VERSION file is refused" '[ $RC = 1 ] && [ -z "$OUT" ] && has_err "$NO_VERSION" && no_call'
rs VERSION=0.4.0
check "...unless the VERSION variable is given" '[ $RC = 0 ] && [ "$OUT" = new ] && logged "url $API/v0.4.0"'
g "$REPO" checkout -q -- VERSION
rs VERSION=v0.4.0
check "the VERSION variable is checked the same way" '[ $RC = 1 ] && [ -z "$OUT" ] && bad_version v0.4.0 && no_call'

# --- what the API answers
for s in 500 429 403; do
  rs STUB_STATUS=$s
  check "HTTP $s from the API is refused, not taken for 'no release'" \
    '[ $RC = 1 ] && [ -z "$OUT" ] && api_error "$s" && body_in_tmp'
done
rs STUB_STATUS=000
check "no answer from the API (000, a refused connection) is refused" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && api_error 000 && body_in_tmp'
rs STUB_STATUS=none
check "...and no status at all (curl failed before it printed one) as HTTP 000" \
  '[ $RC = 1 ] && [ -z "$OUT" ] && api_error 000 && body_in_tmp'

# --- what the workflow sets
rs -u GITHUB_REPOSITORY
check "GITHUB_REPOSITORY is required" '[ $RC != 0 ] && [ -z "$OUT" ] && has_err GITHUB_REPOSITORY && no_call'
rs GITHUB_REPOSITORY=
check "...an empty GITHUB_REPOSITORY too" '[ $RC != 0 ] && [ -z "$OUT" ] && has_err GITHUB_REPOSITORY && no_call'
rs -u GITHUB_SHA
check "GITHUB_SHA is required" '[ $RC != 0 ] && [ -z "$OUT" ] && has_err GITHUB_SHA && no_call'
rs GITHUB_SHA=
check "...an empty GITHUB_SHA too" '[ $RC != 0 ] && [ -z "$OUT" ] && has_err GITHUB_SHA && no_call'

say "# $pass passed, $fail failed"
[ "$fail" = 0 ]
