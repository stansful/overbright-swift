#!/usr/bin/env bash
# Static checks that the release pieces agree: scripts/build-release.sh builds the files release_assets
# (scripts/lib/version.sh) lists, named as scripts/lib/dist.sh writes them, and release.yml checks and publishes
# exactly those; the release is tagged release_tag's vX.Y.Z everywhere, titled "Overbright X.Y.Z" and made the latest
# one (the update check reads /releases/latest); the tag's commit is read one way (tag_commit over every tag); the
# draft is handled by the id the API returns; a re-run once main has moved on publishes nothing and passes with a
# warning; dry runs and runs of other refs never share the concurrency group of the releases from main; the sparse
# checkouts of the gate and the publish job hold every file their steps read; the build job signs with Developer ID
# only when all four signing secrets are set (the .p12's password optional), hands the signing to build-release.sh
# and dist.sh through GITHUB_ENV and always removes the signing material; ci.yml checks the shipped languages in a step
# of its own before its --allow-pending build; both workflows build and test the way the docs say, on runner labels
# actionlint knows, with every action pinned to a commit; and the Makefile's release targets run these scripts.
#
#   scripts/tests/workflows_test.sh          KEEP=1 keeps the temp dir
#
# Reads the workflows, .github/actionlint.yaml, .github/scripts/*.sh, scripts/make-release.sh,
# scripts/build-release.sh, scripts/lib/version.sh, scripts/lib/dist.sh and the Makefile: no git, no build, no
# network. version.sh's functions run in a fresh $TEST_BASH (default: bash from PATH); the jobs and steps cut out of
# the workflows go to a temp dir (TMPDIR).
# Prints 'ok <name>' / 'not ok <name>: <why>' and exits non-zero on a failure.
# The patterns match the workflows' and scripts' own text, $VERSION and the like included.
# shellcheck disable=SC2016
set -u
# SIGPIPE ignored, as on the GitHub runner (every step inherits that from its Node.js), for these tests and the
# scripts they run: a reader that stops early makes its writer fail with "Broken pipe" there instead of dying quietly
trap "" PIPE

HERE="$(cd "$(dirname "$0")" && pwd -P)"
TREE="$(cd "$HERE/../.." && pwd -P)"
BASH_BIN="${TEST_BASH:-bash}"
RELEASE="$TREE/.github/workflows/release.yml"
CI="$TREE/.github/workflows/ci.yml"
ACTIONLINT="$TREE/.github/actionlint.yaml"
STATE="$TREE/.github/scripts/release-state.sh"
NOTES="$TREE/.github/scripts/release-notes.sh"
MAKE_RELEASE="$TREE/scripts/make-release.sh"
BUILD="$TREE/scripts/build-release.sh"
LIB="$TREE/scripts/lib/version.sh"
DIST="$TREE/scripts/lib/dist.sh"
MAKEFILE="$TREE/Makefile"
# no temp dir stops here: an empty WORK would make the current directory (the checkout) the work dir, and the
# EXIT trap would delete it
if ! WORK="$(mktemp -d "${TMPDIR:-/tmp}/workflows-test.XXXXXX")" || ! WORK="$(cd "$WORK" && pwd -P)"; then
  echo "not ok no temp dir in ${TMPDIR:-/tmp}"
  exit 1
fi
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$WORK"' EXIT; else echo "# work dir: $WORK"; fi

# Nothing here runs git; HOME and git's configuration are isolated all the same, as in the other suites
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
# git never finds a repository above the temp dir (a TMPDIR inside some checkout)
GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
export GIT_CEILING_DIRECTORIES
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
mkdir -p "$HOME" "$WORK/jobs/release.yml" "$WORK/jobs/ci.yml"

pass=0 fail=0 WHY=''
ok() {
  echo "ok $1"
  pass=$((pass + 1))
}
nok() {
  echo "not ok $1: $2"
  fail=$((fail + 1))
}
# check <name> <why> <command...>: ok when the command succeeds; else not ok with the why, and with the WHY the
# helpers below leave when they fail
check() {
  local name="$1" why="$2"
  shift 2
  WHY=''
  if "$@"; then ok "$name"; else nok "$name" "$why${WHY:+ ($WHY)}"; fi
}

# --- helpers: each leaves WHY when it fails, so the conditions of the if blocks below report what they missed

# where <file>: the file as the messages name it: its path in the repository, <workflow>/<job>, or
# <workflow>/<job>.<step> for a step cut out of a job
where() {
  case $1 in
  "$WORK"/jobs/*) printf '%s' "${1#"$WORK/jobs/"}" ;;
  "$TREE"/*) printf '%s' "${1#"$TREE/"}" ;;
  *) printf '%s' "$1" ;;
  esac
}
# has_all <file> <text...>: the file holds every text
has_all() {
  local file="$1" text
  shift
  for text; do
    grep -qF -- "$text" "$file" && continue
    WHY="$(where "$file") lacks: $text"
    return 1
  done
}
# has_line <file> <line>: a line of the file is exactly this one
has_line() {
  grep -qxF -- "$2" "$1" && return 0
  WHY="$(where "$1") has no line: $2"
  return 1
}
# follows <file> <text> <next>: a line holding the text is followed by a line holding next
follows() {
  FIRST="$2" NEXT="$3" awk 'p && index($0, ENVIRON["NEXT"]) { found = 1 } { p = index($0, ENVIRON["FIRST"]) > 0 }
    END { exit !found }' "$1" && return 0
  WHY="$(where "$1") lacks a line with: $2, followed by one with: $3"
  return 1
}
# before <file> <text> <later>: lines hold each, and every line that holds the text comes before every one that
# holds later
before() {
  local rc
  FIRST="$2" LATER="$3" awk 'index($0, ENVIRON["FIRST"]) { a = NR } !b && index($0, ENVIRON["LATER"]) { b = NR }
    END { exit (!a) ? 2 : ((!b) ? 3 : (a >= b)) }' "$1"
  rc=$?
  case $rc in
  0) return 0 ;;
  2) WHY="$(where "$1") has no line with: $2" ;;
  3) WHY="$(where "$1") has no line with: $3" ;;
  *) WHY="$(where "$1") has a line with: $2, after one with: $3" ;;
  esac
  return 1
}
# after <file> <text> <n>: the n lines after the first line that holds the text, without their indentation
after() {
  TEXT="$2" awk -v n="$3" 'left { sub(/^[ \t]*/, ""); print; left--; if (!left) exit; next }
    index($0, ENVIRON["TEXT"]) { left = n }' "$1"
}
# once <file> <text>: exactly one line of the file holds the text
once() {
  local n
  n="$(grep -cF -- "$2" "$1")"
  [ "$n" = 1 ] && return 0
  WHY="$(where "$1") has $n lines with: $2"
  return 1
}
# none <ERE> <file...>: no line of the files matches
none() {
  local re="$1" hit
  shift
  hit="$(grep -HnE -- "$re" "$@")"
  [ -z "$hit" ] && return 0
  hit=${hit%%$'\n'*}
  WHY="$(where "${hit%%:*}"):${hit#*:}"
  return 1
}
# words <text> <word...>: every word is one of the text's words (blanks and ; separate them)
words() {
  local text="$1" padded w
  padded=" $(printf '%s' "$text" | tr '\t\n;' '   ') "
  shift
  for w; do
    case $padded in
    *" $w "*) ;;
    *)
      WHY="no word $w in: $(printf '%s' "${text:-nothing}" | tr '\n' ' ')"
      return 1
      ;;
    esac
  done
}
# that <why> <test args...>: test, with the why as WHY when it fails
that() {
  local why="$1"
  shift
  test "$@" && return 0
  WHY=$why
  return 1
}

# job <workflow> <id>: the lines of job <id>, from "  <id>:" under jobs: to the next job
job() {
  awk -v id="  $2:" '
    /^jobs:/ { jobs = 1; next }
    jobs && $0 == id { on = 1; print; next }
    /^  [^ #]/ || /^[^ #]/ { on = 0 }
    on { print }' "$1"
}
# block <file> <line>: the lines indented under the first line that is <line> once its indentation is stripped,
# stripped too, without blank lines and comments: the entries of a YAML mapping or list
block() {
  LINE="$2" awk '
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    { match($0, /^ */); indent = RLENGTH; text = substr($0, indent + 1) }
    on && indent <= top { exit }
    on { print text; next }
    text == ENVIRON["LINE"] { on = 1; top = indent }' "$1"
}
# is_block <file> <line> <entry...>: the entries under the line are exactly these
is_block() {
  local file="$1" line="$2" got want
  shift 2
  got="$(block "$file" "$line")"
  want="$(printf '%s\n' "$@")"
  [ "$got" = "$want" ] && return 0
  WHY="$(where "$file") has under '$line': $(printf '%s' "${got:-nothing}" | tr '\n' '|')"
  return 1
}
# in_block <file> <line> <entry...>: every entry is one of those under the line
in_block() {
  local file="$1" line="$2" got entry
  shift 2
  got="$(block "$file" "$line")"
  for entry; do
    grep -qxF -- "$entry" <<<"$got" && continue
    WHY="$(where "$file") has no '$entry' under '$line'"
    return 1
  done
}
# step <job file> <name>: the lines of the job's step named <name>: its "- name: <name>" line and those under it, up
# to the next step or the comment above that
step() {
  NAME="- name: $2" awk '
    /^ *$/ { if (on) print; next }
    { match($0, /^ */); indent = RLENGTH; text = substr($0, indent + 1) }
    on && indent <= top { exit }
    on { print; next }
    text == ENVIRON["NAME"] { on = 1; top = indent; print }' "$1"
}
# github_env <file>: the names its run: lines write to GITHUB_ENV, one per line: echo "<NAME>=..." >> "$GITHUB_ENV",
# or such echo lines in a group { ... } >> "$GITHUB_ENV"
github_env() {
  awk '
    function name(line) {
      return match(line, /echo "[A-Za-z_][A-Za-z0-9_]*=/) ? substr(line, RSTART + 6, RLENGTH - 7) : ""
    }
    { text = $0; sub(/^[ \t]*/, "", text) }
    text == "{" { group = 1; names = ""; next }
    group && text == "} >> \"$GITHUB_ENV\"" { printf "%s", names; group = 0; next }
    group && substr(text, 1, 1) == "}" { group = 0; next }
    group { if (name(text) != "") names = names name(text) "\n"; next }
    index(text, ">> \"$GITHUB_ENV\"") && name(text) != "" { print name(text) }' "$1"
}

# recipe <target>: the recipe lines of the Makefile's target
recipe() {
  TARGET="$1:" awk 'index($0, ENVIRON["TARGET"]) == 1 { on = 1; next } on && /^\t/ { print; next } { on = 0 }' \
    "$MAKEFILE"
}
# runs <target> <command>: a line of the target's recipe is the command, with its @ or without
runs() {
  local lines
  lines="$(recipe "$1")"
  grep -qxF -e $'\t'"@$2" -e $'\t'"$2" <<<"$lines" && return 0
  lines=${lines//$'\t'/}
  WHY="make $1 runs $(printf '%s' "${lines:-nothing}" | tr '\n' '|'), not $2"
  return 1
}

# lib <function> [args...]: the function of scripts/lib/version.sh in a fresh BASH_BIN that sourced it under
# set -euo pipefail, as the scripts that source it run; sets OUT (stdout and stderr) and RC
lib() {
  OUT="$("$BASH_BIN" -c 'set -euo pipefail; . "$0"; "$@"' "$LIB" "$@" 2>&1)"
  RC=$?
}
APP_VERSION_FILE="$("$BASH_BIN" -c '. "$0"; printf "%s" "$APP_VERSION_FILE"' "$LIB")"
PROJECT_FILE="$("$BASH_BIN" -c '. "$0"; printf "%s" "$PROJECT_FILE"' "$LIB")"

# reads <job file>: the repository files the job's steps read, once each: the scripts its run: lines source
# (. <file>) or run (bash <file>), what those scripts source or name under "$ROOT_DIR/", VERSION when the steps or
# those scripts call version.sh's app_version_* functions and the project file for its project_version* ones
# (version.sh itself only defines them)
reads() {
  local scripts s text
  scripts="$(sed -n 's#^ *\. \([^ ;&|)]*\)$#\1#p' "$1"; sed -n 's#.*bash \([A-Za-z0-9_./-]*\.sh\).*#\1#p' "$1")"
  text="$(cat "$1")"
  {
    for s in $scripts; do
      echo "$s"
      [ -f "$TREE/$s" ] || continue
      grep -o '"\$ROOT_DIR/[^"$]*"' "$TREE/$s" | sed 's#^"\$ROOT_DIR/##; s#"$##'
      [ "$TREE/$s" = "$LIB" ] && continue
      text="$text
$(cat "$TREE/$s")"
    done
    case $text in *app_version_* | *APP_VERSION_FILE*) echo "$APP_VERSION_FILE" ;; esac
    case $text in *project_version* | *PROJECT_FILE*) echo "$PROJECT_FILE" ;; esac
  } | LC_ALL=C sort -u
}
# covered <path> <patterns>: whether a sparse checkout (no cone mode) with these patterns, one per line, holds the
# file: /<path> itself, or a /<dir>/ above it
covered() {
  local p
  while IFS= read -r p; do
    case $p in
    */) case "/$1" in "$p"*) return 0 ;; esac ;;
    *) [ "/$1" = "$p" ] && return 0 ;;
    esac
  done <<<"$2"
  return 1
}
# sparse_reads <job file>: the job's sparse checkout holds every file reads lists (READS), and the repository has them
sparse_reads() {
  local patterns f uncovered='' absent=''
  patterns="$(block "$1" 'sparse-checkout: |')"
  READS="$(reads "$1")"
  for f in $READS; do
    [ -e "$TREE/$f" ] || absent="$absent $f"
    covered "$f" "$patterns" || uncovered="$uncovered $f"
  done
  [ -z "$uncovered$absent" ] && return 0
  WHY="$(where "$1"):${uncovered:+ not in the sparse checkout:$uncovered}${absent:+ not in the repository:$absent}"
  return 1
}

echo "# the release pieces, scripts/lib/version.sh under $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"')"

for id in gate quality build publish; do job "$RELEASE" "$id" >"$WORK/jobs/release.yml/$id"; done
for id in scripts build; do job "$CI" "$id" >"$WORK/jobs/ci.yml/$id"; done
GATE="$WORK/jobs/release.yml/gate" QUALITY="$WORK/jobs/release.yml/quality"
BUILD_JOB="$WORK/jobs/release.yml/build" PUBLISH="$WORK/jobs/release.yml/publish"
CI_SCRIPTS="$WORK/jobs/ci.yml/scripts" CI_BUILD="$WORK/jobs/ci.yml/build"
missing=''
for f in "$GATE" "$QUALITY" "$BUILD_JOB" "$PUBLISH" "$CI_SCRIPTS" "$CI_BUILD"; do
  [ -s "$f" ] || missing="$missing $(where "$f")"
done
check "release.yml has the jobs gate, quality, build and publish; ci.yml the jobs scripts and build" \
  "not found:$missing" test -z "$missing"

# --- the release files: release_assets, which build-release.sh builds, dist.sh names and release.yml publishes

lib release_assets 1.2.3
ASSETS=$OUT
check "release_assets X.Y.Z: Overbright-X.Y.Z.zip, .dmg and .sha256, in upload order" \
  "release_assets 1.2.3: rc=$RC, $(printf '%s' "$OUT" | tr '\n' '|')" \
  test "$RC:$OUT" = "0:$(printf '%s\n' Overbright-1.2.3.zip Overbright-1.2.3.dmg Overbright-1.2.3.sha256)"
if has_all "$DIST" 'NAME="Overbright-$VERSION"' 'ditto -c -k --norsrc --keepParent "$APP" "$DIST/$NAME.zip"' \
  '"$DIST/$NAME.dmg")' 'shasum -a 256 "$NAME.zip" "$NAME.dmg" > "$NAME.sha256"'; then
  ok "...the files scripts/lib/dist.sh writes: Overbright-<version>.zip, .dmg, and .sha256 with the sums of both"
else
  nok "...the files scripts/lib/dist.sh writes: Overbright-<version>.zip, .dmg, and .sha256 with the sums of both" \
    "$WHY"
fi
# dist.sh takes the version from the app it packages: the build build-release.sh has just made from VERSION and
# checked (REBUILD=0: dist.sh does not build it again)
if has_all "$DIST" 'VERSION="$(plist_value "$APP" CFBundleShortVersionString)"' &&
  has_all "$BUILD" 'MARKETING_VERSION="$version" "$ROOT/scripts/lib/build.sh"' \
    'built="$(info CFBundleShortVersionString)"' '[[ "$built" == "$version" ]] || die' \
    'REBUILD=0 "$ROOT/scripts/lib/dist.sh"'; then
  ok "dist.sh names them by the app's version, which build-release.sh builds from VERSION and checks first"
else
  nok "dist.sh names them by the app's version, which build-release.sh builds from VERSION and checks first" "$WHY"
fi
if has_all "$BUILD" 'assets="$(release_assets "$version" |' 'sums="Overbright-$version.sha256"' \
  '[[ -s "$DIST/$f" ]] || missing="$missing $f"' 'wanted="$(release_assets "$version" | grep -vxF "$sums"' &&
  follows "$BUILD" 'for f in $assets; do' 'cp "$DIST/$f" "$out/$f"'; then
  ok "build-release.sh builds, checks and copies to --out the files release_assets lists"
else
  nok "build-release.sh builds, checks and copies to --out the files release_assets lists" "$WHY"
fi

check 'release.yml builds the release with scripts/build-release.sh --out "$RUNNER_TEMP/out"' \
  "the build job builds another way" \
  has_line "$BUILD_JOB" '        run: scripts/build-release.sh --out "$RUNNER_TEMP/out"'
# --allow-pending still has every shipped language complete and valid; what it lets through are strings pending
# translation, which build-release.sh refuses without it
if none '--allow-pending' "$RELEASE" &&
  has_all "$BUILD" '"$ROOT/scripts/lib/l10n/validate.py" --shipped --release --quiet ||'; then
  ok "...never with --allow-pending: a release refuses strings pending translation (validate.py --shipped --release)"
else
  nok "...never with --allow-pending: a release refuses strings pending translation (validate.py --shipped --release)" \
    "$WHY"
fi
if has_all "$BUILD_JOB" 'expected="$(release_assets "$VERSION" | LC_ALL=C sort)"' \
  'actual="$(find "$RUNNER_TEMP/out" -mindepth 1 -maxdepth 1 -exec basename {} \; | LC_ALL=C sort)"' \
  'if [[ "$expected" != "$actual" ]]; then' 'shasum -a 256 -c "Overbright-$VERSION.sha256"'; then
  ok "release.yml checks that the build's --out directory holds exactly the release_assets files, the sums matching"
else
  nok "release.yml checks that the build's --out directory holds exactly the release_assets files, the sums matching" \
    "$WHY"
fi
if has_all "$BUILD_JOB" 'VERSION: ${{ needs.gate.outputs.version }}' &&
  has_all "$PUBLISH" 'VERSION: ${{ needs.gate.outputs.version }}'; then
  ok "the build and publish jobs take VERSION from the gate"
else
  nok "the build and publish jobs take VERSION from the gate" "$WHY"
fi
if has_all "$BUILD_JOB" 'name: release-${{ env.VERSION }}' 'path: ${{ runner.temp }}/out/' &&
  has_all "$PUBLISH" 'name: release-${{ env.VERSION }}' 'path: ${{ runner.temp }}/release-assets' \
    'assets+=("$RUNNER_TEMP/release-assets/$name")'; then
  ok "the publish job uploads from the artifact of the build job's checked --out directory"
else
  nok "the publish job uploads from the artifact of the build job's checked --out directory" "$WHY"
fi
if has_all "$PUBLISH" 'done < <(release_assets "$VERSION")' \
  '"https://uploads.github.com/repos/$GH_REPO/releases/$id/assets?name=$(basename "$f")"' \
  '[[ "$(wc -l < "$uploaded")" -ne "${#assets[@]}" ]]' &&
  follows "$PUBLISH" 'for f in "${assets[@]}"; do' 'curl -fsS --max-time 300 -X POST' &&
  once "$RELEASE" 'uploads.github.com'; then
  ok "release.yml uploads exactly the release_assets files, and checks that the draft holds that many"
else
  nok "release.yml uploads exactly the release_assets files, and checks that the draft holds that many" "$WHY"
fi

check "ci.yml's build job makes the release build with scripts/build-release.sh --allow-pending" \
  "ci.yml builds another way" has_line "$CI_BUILD" '        run: scripts/build-release.sh --allow-pending'
missing=''
[ -n "$ASSETS" ] || missing=' (release_assets lists nothing)'
for name in $ASSETS; do
  has_line "$CI_BUILD" "            dist/*.${name##*.}" || missing="$missing dist/*.${name##*.}"
done
check "...and uploads every kind of file release_assets lists from dist/" \
  "ci.yml's build job does not upload:$missing" test -z "$missing"
# build-release.sh --allow-pending checks the shipped languages too (validate.py --shipped); ci.yml checks them first,
# in a step of their own, which fails under its own name before the long build starts
validate='        run: /usr/bin/python3 -I scripts/lib/l10n/validate.py --shipped'
if has_line "$CI_BUILD" "$validate" && follows "$CI_BUILD" '      - name: ' "$validate" &&
  before "$CI_BUILD" "$validate" '        run: scripts/build-release.sh --allow-pending'; then
  ok "...after a step of its own that checks the shipped languages: validate.py --shipped (strings may be pending)"
else
  nok "...after a step of its own that checks the shipped languages: validate.py --shipped (strings may be pending)" \
    "$WHY"
fi

# --- the tag, the title, the notes

lib release_tag 1.2.3
check "release_tag X.Y.Z is vX.Y.Z" "release_tag 1.2.3: rc=$RC, '$OUT'" test "$RC:$OUT" = "0:v1.2.3"
if has_all "$GATE" 'tag="$(release_tag "$version")"' 'is already released (${tag})' \
  '::notice::Tag ${tag} is already on this commit'; then
  ok "the gate's notices name the release's tag as release_tag makes it"
else
  nok "the gate's notices name the release's tag as release_tag makes it" "$WHY"
fi
if has_all "$PUBLISH" 'TAG="$(release_tag "$VERSION")"' 'export TAG' '-f tag_name="$TAG"' '.tag_name == env.TAG' \
  '[[ "$latest" == "$TAG" ]]'; then
  ok "publish uses release_tag's vX.Y.Z: the draft's tag, the stale drafts' lookup, the /releases/latest check"
else
  nok "publish uses release_tag's vX.Y.Z: the draft's tag, the stale drafts' lookup, the /releases/latest check" "$WHY"
fi
if has_all "$STATE" 'TAG="$(release_tag "$VERSION")"' '/releases/tags/$TAG"' 'tag_commit "$TAG"' 'highest_tag "$TAG"' &&
  has_all "$NOTES" 'highest_tag "$(release_tag "$VERSION")"'; then
  ok "release-state.sh and release-notes.sh know the release's tag as release_tag makes it"
else
  nok "release-state.sh and release-notes.sh know the release's tag as release_tag makes it" "$WHY"
fi
# the plain version where a tag goes, or a "v" put before it by hand
plain='tag_name="\$\{?VERSION|tag_name == env\.VERSION|tag_commit "\$\{?VERSION|releases/tags?/\$\{?VERSION'
plain="$plain"'|highest_tag "\$\{?VERSION|[^A-Za-z]v\$\{?(VERSION|version)'
check "no tag is the plain version (tag_name=\"\$VERSION\" and the like), nor a vX.Y.Z made without release_tag" \
  "a tag is made another way" none "$plain" "$RELEASE" "$STATE" "$NOTES"
check 'the release is titled "Overbright X.Y.Z"' "the draft gets another name" \
  has_all "$PUBLISH" '-f name="Overbright $VERSION"'
if has_all "$PUBLISH" '-F draft=true --jq .id)"' '-F draft=false -f make_latest=true' \
  'latest="$(gh api "repos/$GH_REPO/releases/latest" --jq .tag_name || true)"'; then
  ok "the draft is published as the latest release (draft=false, make_latest=true), which the update check reads"
else
  nok "the draft is published as the latest release (draft=false, make_latest=true), which the update check reads" \
    "$WHY"
fi
if has_all "$PUBLISH" 'bash .github/scripts/release-notes.sh > "$RUNNER_TEMP/release-notes.md"' \
  '-F body=@"$RUNNER_TEMP/release-notes.md"'; then
  ok "the release notes come from release-notes.sh"
else
  nok "the release notes come from release-notes.sh" "$WHY"
fi
if has_all "$MAKE_RELEASE" 'message="feat: release - version $new"' &&
  has_all "$NOTES" "grep -v '^- feat: release - version [0-9]'" && has_all "$GATE" 'feat: release - version X.Y.Z'; then
  ok 'make-release.sh commits "feat: release - version X.Y.Z", the subject the gate names and release-notes.sh leaves out'
else
  nok 'make-release.sh commits "feat: release - version X.Y.Z", the subject the gate names and release-notes.sh leaves out' \
    "$WHY"
fi

# `git ls-remote` given a pattern leaves out an annotated tag's peeled line, so it reads the tag object, not the
# commit: an annotated tag release-state.sh accepts as retry would fail the publish job after publishing
if has_all "$PUBLISH" '[[ "$(git ls-remote --tags origin | tag_commit "$TAG")" == "$GITHUB_SHA" ]]' \
  'tag_sha="$(git ls-remote --tags origin | tag_commit "$TAG")"' &&
  has_all "$STATE" 'refs="$(git -C "$ROOT_DIR" ls-remote --tags origin)"' 'tag_sha="$(tag_commit "$TAG" <<<"$refs")"' &&
  none 'ls-remote[^|]*refs/tags|ls-remote --tags origin [^|]' "$RELEASE" "$STATE"; then
  ok "release.yml reads a tag's commit as release-state.sh does: tag_commit over every git ls-remote --tags line"
else
  nok "release.yml reads a tag's commit as release-state.sh does: tag_commit over every git ls-remote --tags line" \
    "$WHY"
fi

# The release list lags behind a draft created a moment ago: the publish step takes the draft's id from the create
# call and never looks the draft up by its tag
if has_all "$PUBLISH" 'id="$(gh api --method POST "repos/$GH_REPO/releases"' '-F draft=true --jq .id)"' \
  'releases/$id/assets?name=' 'gh api --method PATCH "repos/$GH_REPO/releases/$id"' &&
  none 'gh release (create|upload|edit)' "$RELEASE"; then
  ok "publish works with the id the API returns for the new draft (no gh release create, upload or edit)"
else
  nok "publish works with the id the API returns for the new draft (no gh release create, upload or edit)" "$WHY"
fi

# --- the workflows: triggers, jobs, sparse checkouts

if has_line "$QUALITY" '    uses: ./.github/workflows/ci.yml' && is_block "$QUALITY" 'with:' 'release: true' &&
  in_block "$CI" 'workflow_call:' 'inputs:' 'release:' 'type: boolean'; then
  ok "release.yml runs the whole CI: ci.yml through workflow_call, with release: true"
else
  nok "release.yml runs the whole CI: ci.yml through workflow_call, with release: true" "$WHY"
fi
if has_line "$BUILD_JOB" '    needs: [gate, quality]' && has_line "$PUBLISH" '    needs: [gate, quality, build]'; then
  ok "the build job needs the gate and the CI (quality), the publish job those and the build"
else
  nok "the build job needs the gate and the CI (quality), the publish job those and the build" "$WHY"
fi
# A push to main starts release.yml only (which calls ci.yml): no second CI run for the same push
if is_block "$RELEASE" 'push:' 'branches:' '- main' && is_block "$CI" 'push:' 'branches-ignore: [main]' &&
  in_block "$CI" 'on:' 'pull_request:'; then
  ok "a push to main runs release.yml, ci.yml runs for the other branches and pull requests"
else
  nok "a push to main runs release.yml, ci.yml runs for the other branches and pull requests" "$WHY"
fi
# A concurrency group runs one run and keeps one waiting: a newer run replaces the waiting one. The runs from main
# share the group "release" and none is cancelled half-way; a dry run, or a manual run of another ref (which the gate
# refuses), gets a group of its own run id, so it never replaces a release waiting for its turn
group="group: \${{ (inputs.dry_run || github.ref != 'refs/heads/main')"
group="$group && format('release-dry-run-{0}', github.run_id) || 'release' }}"
if has_line "$RELEASE" 'concurrency:' && is_block "$RELEASE" 'concurrency:' "$group" 'cancel-in-progress: false'; then
  ok "release.yml's concurrency: one group for main's runs, never cancelled; one per dry run or run of another ref"
else
  nok "release.yml's concurrency: one group for main's runs, never cancelled; one per dry run or run of another ref" \
    "$WHY"
fi
if has_all "$GATE" '[[ "$GITHUB_REF" != "refs/heads/main" ]]' &&
  has_all "$PUBLISH" 'tip="$(git ls-remote origin refs/heads/main | cut -f 1)"' &&
  none '(^|[^A-Za-z0-9_])master([^A-Za-z0-9_]|$)' "$RELEASE" "$CI" "$STATE" "$NOTES"; then
  ok "releases go out from main only (the gate refuses other refs, publish checks main's tip); no master left"
else
  nok "releases go out from main only (the gate refuses other refs, publish checks main's tip); no master left" "$WHY"
fi
# A re-run of an old run once main has moved on publishes nothing and passes: the run of main's tip releases the
# version. A ::warning, not a notice: when that run was cancelled, nothing releases the version until it is re-run
moved="$(after "$PUBLISH" 'if [[ "$tip" != "$GITHUB_SHA" ]]; then' 3)"
warning=${moved%%$'\n'*}
rest=${moved#*$'\n'}
rest="$(printf '%s' "$rest" | tr '\n' '|')"
case $warning in
'echo "::warning '*'main moved to ${tip}'*'Re-run it if it was cancelled."') warns=1 ;;
*) warns='' ;;
esac
if follows "$PUBLISH" 'tip="$(git ls-remote origin refs/heads/main | cut -f 1)"' \
  'if [[ "$tip" != "$GITHUB_SHA" ]]; then' &&
  that "when main moved, publish runs: $(printf '%s' "${moved:-nothing}" | tr '\n' '|')" -n "$warns" &&
  that "after the ::warning: ${rest:-nothing}, not exit 0|fi" "$rest" = 'exit 0|fi'; then
  ok "...a re-run after main moved on publishes nothing and passes (exit 0) with a ::warning: main's run releases it"
else
  nok "...a re-run after main moved on publishes nothing and passes (exit 0) with a ::warning: main's run releases it" \
    "$WHY"
fi
check "ci.yml runs these tests (scripts/tests/run.sh)" "ci.yml's scripts job does not run scripts/tests/run.sh" \
  has_line "$CI_SCRIPTS" '        run: scripts/tests/run.sh'
shellcheck_cmd="$(grep -A 1 -F -- '--entrypoint shellcheck' "$CI_SCRIPTS")"
check "ci.yml shellchecks scripts/*.sh, scripts/lib/version.sh, scripts/tests/*.sh and .github/scripts/*.sh" \
  "ci.yml's shellcheck leaves some out" \
  words "$shellcheck_cmd" 'scripts/*.sh' scripts/lib/version.sh 'scripts/tests/*.sh' '.github/scripts/*.sh'

# The gate and the publish job check out only a few files: whatever their steps run, source or read must be there
for id in gate publish; do
  j="$WORK/jobs/release.yml/$id"
  if in_block "$j" 'sparse-checkout: |' /VERSION /scripts/lib/version.sh /.github/scripts/ &&
    has_all "$j" 'sparse-checkout-cone-mode: false'; then
    ok "the $id job's sparse checkout holds /VERSION, /scripts/lib/version.sh and /.github/scripts/ (no cone mode)"
  else
    nok "the $id job's sparse checkout holds /VERSION, /scripts/lib/version.sh and /.github/scripts/ (no cone mode)" \
      "$WHY"
  fi
  if sparse_reads "$j" && that "found no file the $id job reads" -n "$READS"; then
    ok "...and every file the $id job's steps run or source and those read"
  else
    nok "...and every file the $id job's steps run or source and those read" "$WHY"
  fi
  echo "# the $id job reads: $(printf '%s' "$READS" | tr '\n' ' ')"
done

# --- signing: Developer ID from the repository secrets, or ad-hoc

SIGNING="$WORK/jobs/release.yml/build.signing" CLEANUP="$WORK/jobs/release.yml/build.cleanup"
step "$BUILD_JOB" 'Signing (Developer ID from the secrets, or ad-hoc)' >"$SIGNING"
step "$BUILD_JOB" 'Remove the signing material' >"$CLEANUP"
if that "the build job has no step 'Signing (Developer ID from the secrets, or ad-hoc)'" -s "$SIGNING" &&
  that "the build job has no step 'Remove the signing material'" -s "$CLEANUP" &&
  before "$BUILD_JOB" '      - name: Signing (Developer ID from the secrets, or ad-hoc)' \
    '        run: scripts/build-release.sh --out' &&
  before "$BUILD_JOB" '        run: scripts/build-release.sh --out' '      - name: Remove the signing material'; then
  ok "release.yml's build job sets the signing up before scripts/build-release.sh runs, and removes it after"
else
  nok "release.yml's build job sets the signing up before scripts/build-release.sh runs, and removes it after" "$WHY"
fi

# All four secrets: Developer ID signing and notarization; none: ad-hoc; some: an error, so a missing secret never
# turns a signed release into an ad-hoc one unnoticed. The .p12's password is not counted: a .p12 may have none, and
# a wrong or missing one fails the import; the password alone is a half configuration too, not ad-hoc
counted="$(sed -n 's/^ *for name in \(.*\); do$/\1/p' "$SIGNING")"
n="$(printf '%s' "$counted" | wc -w | tr -d ' ')"
if words "$counted" P12_BASE64 NOTARY_KEY_P8_BASE64 NOTARY_KEY_ID NOTARY_ISSUER_ID &&
  that "it counts $n: $counted" "$n" = 4 &&
  has_all "$SIGNING" '[[ -z "${!name}" ]] || count=$((count + 1))' 'if [[ $count -eq 0 && -z "$P12_PASSWORD" ]]; then' \
    'if [[ $count -ne 4 ]]; then'; then
  ok "the signing step counts P12_BASE64, NOTARY_KEY_P8_BASE64, NOTARY_KEY_ID and NOTARY_ISSUER_ID: all four or none"
else
  nok "the signing step counts P12_BASE64, NOTARY_KEY_P8_BASE64, NOTARY_KEY_ID and NOTARY_ISSUER_ID: all four or none" \
    "$WHY"
fi
case " $counted " in *" P12_PASSWORD "*) password_counted=1 ;; *) password_counted='' ;; esac
if that "it counts P12_PASSWORD: $counted" -z "$password_counted" &&
  in_block "$SIGNING" 'env:' 'P12_PASSWORD: ${{ secrets.DEVELOPER_ID_P12_PASSWORD }}' &&
  has_all "$SIGNING" 'security import "$RUNNER_TEMP/developer-id.p12" -P "$P12_PASSWORD" '; then
  ok "...not P12_PASSWORD, the .p12's password: optional, still passed to security import -P \"\$P12_PASSWORD\""
else
  nok "...not P12_PASSWORD, the .p12's password: optional, still passed to security import -P \"\$P12_PASSWORD\"" \
    "$WHY"
fi
# the repository secrets behind the counted variables, as the step's env: maps them
secrets='' unmapped=''
for name in $counted; do
  secret="$(sed -n 's/^ *'"$name"': \${{ secrets\.\([A-Za-z0-9_]*\) }}$/\1/p' "$SIGNING")"
  if [ -n "$secret" ]; then secrets="$secrets $secret"; else unmapped="$unmapped $name"; fi
done
error="$(after "$SIGNING" "if [[ \$count -ne $n ]]; then" 2)"
error_line=${error%%$'\n'*}
rest=${error#*$'\n'}
unnamed=''
for secret in $secrets; do
  grep -qwF -- "$secret" <<<"$error_line" || unnamed="$unnamed $secret"
done
case $error_line in 'echo "::error '*'Set all four secrets '*) stops=1 ;; *) stops='' ;; esac
if that "the step's env: maps no secret to:$unmapped" -z "$unmapped" && that "it counts no secret" -n "$secrets" &&
  that "with some of them set, the step runs: $(printf '%s' "${error:-nothing}" | tr '\n' '|')" -n "$stops" &&
  that "after the ::error: ${rest:-nothing}, not exit 1" "$rest" = 'exit 1' &&
  that "the ::error does not name:$unnamed" -z "$unnamed"; then
  ok "...some but not all of them set: the step fails with an ::error that names the four repository secrets"
else
  nok "...some but not all of them set: the step fails with an ::error that names the four repository secrets" "$WHY"
fi

# The signing reaches scripts/build-release.sh, and the scripts/lib/dist.sh it runs, as the environment of the steps
# after the one that writes it to GITHUB_ENV
exported="$(github_env "$BUILD_JOB" | LC_ALL=C sort | tr '\n' ' ')"
want='NOTARY_KEYCHAIN NOTARY_PROFILE SIGN_IDENTITY TEAM_ID '
check "the build job exports SIGN_IDENTITY, TEAM_ID, NOTARY_PROFILE and NOTARY_KEYCHAIN through GITHUB_ENV" \
  "it exports ${exported:-nothing}" test "$exported" = "$want"
# the code of both scripts, without comment lines; a here-string, so grep -q never stops a writer half-way
code="$(sed '/^[[:space:]]*#/d' "$BUILD" "$DIST")"
unread=''
for name in $exported; do
  grep -qE '\$\{?'"$name"'([^A-Za-z0-9_]|$)' <<<"$code" || unread="$unread $name"
done
if that "build-release.sh and dist.sh never read:$unread" -z "$unread" &&
  before "$BUILD_JOB" '>> "$GITHUB_ENV"' '        run: scripts/build-release.sh --out'; then
  ok "...before scripts/build-release.sh runs: each is read by it or by the scripts/lib/dist.sh it runs"
else
  nok "...before scripts/build-release.sh runs: each is read by it or by the scripts/lib/dist.sh it runs" "$WHY"
fi
profile="$(sed -n 's/^ *echo "NOTARY_PROFILE=\([^"$]*\)"$/\1/p' "$SIGNING")"
if that "the signing step writes no NOTARY_PROFILE=<profile name>" -n "$profile" &&
  has_all "$SIGNING" "xcrun notarytool store-credentials $profile " '--keychain "$KEYCHAIN"' \
    'echo "NOTARY_KEYCHAIN=$KEYCHAIN"' &&
  has_all "$DIST" '--keychain-profile "$NOTARY_PROFILE" ${NOTARY_KEYCHAIN:+--keychain "$NOTARY_KEYCHAIN"}'; then
  ok "...NOTARY_PROFILE: the profile the step stores in the keychain NOTARY_KEYCHAIN, which dist.sh submits with"
else
  nok "...NOTARY_PROFILE: the profile the step stores in the keychain NOTARY_KEYCHAIN, which dist.sh submits with" \
    "$WHY"
fi

# The keychain and the decoded .p12 and .p8 go whatever happened before: a failed or cancelled build too
keychain="$(awk '/^ *KEYCHAIN=/ { sub(/^ */, ""); print; exit }' "$SIGNING")"
decoded="$(sed -n 's/.*base64 --decode > \("[^"]*"\).*/\1/p' "$SIGNING")"
removed="$(grep '^ *rm -f ' "$CLEANUP")"
kept=''
for f in $decoded; do
  case $removed in *" $f"*) ;; *) kept="$kept $f" ;; esac
done
if has_line "$CLEANUP" '        if: always()' && that "the signing step sets no KEYCHAIN" -n "$keychain" &&
  has_all "$CLEANUP" "$keychain" 'security delete-keychain "$KEYCHAIN"' &&
  that "the signing step decodes no file" -n "$decoded" && that "it does not remove:$kept" -z "$kept"; then
  ok "the step 'Remove the signing material' runs always(): it deletes the keychain and the decoded .p12 and .p8"
else
  nok "the step 'Remove the signing material' runs always(): it deletes the keychain and the decoded .p12 and .p8" \
    "$WHY"
fi

# --- runners and actions

# actionlint 1.7.12 knows GitHub's ubuntu labels, not xcode-27 (GitHub's Xcode 27 image, newer)
runners="$(sed -n 's/^ *runs-on: *//p' "$RELEASE" "$CI" | LC_ALL=C sort -u)"
odd=''
for r in $runners; do
  case $r in ubuntu-* | xcode-27) ;; *) odd="$odd $r" ;; esac
done
if that "no runs-on in the workflows" -n "$runners" && that "runs-on:$odd" -z "$odd" &&
  has_line "$BUILD_JOB" '    runs-on: xcode-27' && has_line "$CI_BUILD" '    runs-on: xcode-27'; then
  ok "every job runs on ubuntu or xcode-27, the image of both builds"
else
  nok "every job runs on ubuntu or xcode-27, the image of both builds" "$WHY"
fi
undeclared=''
for r in $runners; do
  case $r in ubuntu-*) continue ;; esac
  in_block "$ACTIONLINT" 'labels:' "- $r" || undeclared="$undeclared $r"
done
if in_block "$ACTIONLINT" 'self-hosted-runner:' 'labels:' && that "not declared:$undeclared" -z "$undeclared"; then
  ok ".github/actionlint.yaml declares every runner label actionlint does not know (xcode-27)"
else
  nok ".github/actionlint.yaml declares every runner label actionlint does not know (xcode-27)" "$WHY"
fi

uses="$(sed -n -E 's/^ *(- )?uses: //p' "$RELEASE" "$CI")"
external="$(grep -v '^\./' <<<"$uses")"
unpinned="$(grep -vE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' <<<"$external")"
pins="$(LC_ALL=C sort -u <<<"$external" | sed 's/@.*//' | uniq -d)"
if that "no external action in the workflows" -n "$external" &&
  that "not pinned so: $(printf '%s' "$unpinned" | tr '\n' '|')" -z "$unpinned" &&
  that "pinned to two commits or versions: $(printf '%s' "$pins" | tr '\n' ' ')" -z "$pins"; then
  ok "every external action is pinned to a commit with its version as a comment (@<40 hex> # vX.Y.Z), one pin each"
else
  nok "every external action is pinned to a commit with its version as a comment (@<40 hex> # vX.Y.Z), one pin each" \
    "$WHY"
fi

# --- the Makefile

if runs release 'scripts/make-release.sh $(V)' && runs release-build 'scripts/build-release.sh $(ARGS)' &&
  runs release-test scripts/tests/run.sh &&
  words "$(grep '^\.PHONY:' "$MAKEFILE")" release release-build release-test; then
  ok "make release, release-build and release-test run make-release.sh, build-release.sh and scripts/tests/run.sh"
else
  nok "make release, release-build and release-test run make-release.sh, build-release.sh and scripts/tests/run.sh" \
    "$WHY"
fi
missing=''
for f in scripts/make-release.sh scripts/build-release.sh scripts/tests/run.sh; do
  [ -f "$TREE/$f" ] && [ -x "$TREE/$f" ] || missing="$missing $f"
done
check "...which are executable files: make and the workflows run them directly" "missing or not executable:$missing" \
  test -z "$missing"
lint_loop="$(recipe lint | grep -F 'for script in ')"
if words "$lint_loop" 'scripts/tests/*.sh' '.github/scripts/*.sh' &&
  follows "$MAKEFILE" 'for script in ' '/bin/bash -n "$$script" || exit 1'; then
  ok "make lint's bash -n covers scripts/tests/*.sh and .github/scripts/*.sh"
else
  nok "make lint's bash -n covers scripts/tests/*.sh and .github/scripts/*.sh" "$WHY"
fi

echo "# $pass passed, $fail failed"
[ "$fail" = 0 ]
