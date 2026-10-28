# shellcheck shell=bash
# Release versions and release files, shared by scripts/make-release.sh, scripts/build-release.sh, .github/scripts/*.sh
# and .github/workflows/release.yml (sourced, not run).
#
# A version is X.Y.Z: three decimal numbers without leading zeros (0 itself is fine), each at most 9 digits, so every
# number fits a 32-bit integer. It lives in VERSION, which holds the version alone and which scripts/lib/build.sh
# hands to Xcode as MARKETING_VERSION (CFBundleShortVersionString), and in the MARKETING_VERSION lines of
# Overbright.xcodeproj/project.pbxproj, which the builds that bypass build.sh use (scripts/lib/run.sh, Xcode itself);
# scripts/make-release.sh sets both. Release X.Y.Z is tagged vX.Y.Z (the update check reads the tag as a
# SemanticVersion) and publishes the files of scripts/lib/dist.sh, release_assets below. Tags X.Y.Z count as version
# X.Y.Z too.
# bash 3.2 (macOS) and 5 (Linux), BSD or GNU tools; no sort -V, which BSD sort lacks.

VERSION_RE='^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$'

# The files with the version, relative to the repository root
APP_VERSION_FILE=VERSION
PROJECT_FILE=Overbright.xcodeproj/project.pbxproj
# A version line of the project, an awk regex (no character classes: mawk, Ubuntu's awk, may lack them)
PROJECT_VERSION_LINE_RE='^[ \t]*MARKETING_VERSION[ \t]*=[^;]*;[ \t]*$'

# version_valid <s>: whether s is X.Y.Z
version_valid() {
  [[ $1 =~ $VERSION_RE ]]
}

# version_cmp <a> <b>: prints -1, 0 or 1 for a < b, a = b, a > b (both valid). Without leading zeros the longer number
# is the larger one, and numbers of one length compare as strings.
version_cmp() {
  local a="$1." b="$2." x y
  while [ -n "$a" ]; do
    x=${a%%.*} y=${b%%.*}
    a=${a#*.} b=${b#*.}
    [ "$x" = "$y" ] && continue
    if [ ${#x} -gt ${#y} ] || { [ ${#x} -eq ${#y} ] && [[ $x > $y ]]; }; then
      echo 1
    else
      echo -1
    fi
    return 0
  done
  echo 0
}

# version_gt <a> <b>: whether a > b
version_gt() {
  [ "$(version_cmp "$1" "$2")" = 1 ]
}

# version_bump <X.Y.Z> <patch|minor|major>: prints X.Y.(Z+1), X.(Y+1).0 or (X+1).0.0, which is not valid when the
# number grows to 10 digits
version_bump() {
  local x y z
  x=${1%%.*} z=${1##*.} y=${1#*.}
  y=${y%.*}
  case $2 in
  patch) echo "$x.$y.$((z + 1))" ;;
  minor) echo "$x.$((y + 1)).0" ;;
  major) echo "$((x + 1)).0.0" ;;
  *) return 1 ;;
  esac
}

# app_version_parse: reads VERSION on stdin and prints its one non-blank line without the blanks around it (spaces,
# tabs, carriage returns); fails, printing nothing, unless there is exactly one. The value is not checked: see
# version_valid.
app_version_parse() {
  awk '
    { sub(/^[ \t\r]+/, ""); sub(/[ \t\r]+$/, "") }
    $0 != "" { n++; v = $0 }
    END { if (n != 1) exit 1; print v }'
}

# app_version_get <root>: app_version_parse of <root>/VERSION
app_version_get() {
  app_version_parse <"$1/$APP_VERSION_FILE"
}

# _rewrite <file> <awk program> [awk args…]: replaces the file's text with the program's output, in place (the file
# keeps its inode and mode); fails, changing nothing, when awk fails
_rewrite() {
  local file="$1" program="$2" tmp
  shift 2
  tmp="$(mktemp "${TMPDIR:-/tmp}/version.XXXXXX")" || return 1
  if awk "$@" "$program" "$file" >"$tmp" && cat "$tmp" >"$file"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# app_version_set <root> <X.Y.Z>: writes the version into the non-blank line of <root>/VERSION; fails, changing
# nothing, unless the file has exactly one
app_version_set() {
  version_valid "$2" || return 1
  app_version_parse <"$1/$APP_VERSION_FILE" >/dev/null || return 1
  # shellcheck disable=SC2016 # an awk program
  _rewrite "$1/$APP_VERSION_FILE" '
    { line = $0; gsub(/[ \t\r]/, "", line) }
    line != "" { $0 = v }
    { print }' -v v="$2"
}

# project_versions: reads project.pbxproj on stdin and prints every value its MARKETING_VERSION lines hold, once
# each, in the order they first appear (quotes removed); nothing when there is no such line
project_versions() {
  awk -v re="$PROJECT_VERSION_LINE_RE" '
    $0 ~ re {
      v = $0
      sub(/^[^=]*=[ \t]*/, "", v)
      sub(/[ \t]*;[ \t]*$/, "", v)
      gsub(/"/, "", v)
      if (!(v in seen)) { seen[v] = 1; print v }
    }'
}

# project_version_lines <X.Y.Z>: reads project.pbxproj on stdin and prints how many lines project_version_set changes
# when it writes X.Y.Z: the MARKETING_VERSION lines that are not already exactly what it writes (a line holding
# "X.Y.Z" in quotes, or spaced otherwise, is rewritten too)
project_version_lines() {
  awk -v re="$PROJECT_VERSION_LINE_RE" -v v="$1" '
    $0 ~ re { line = $0; sub(/=.*$/, "= " v ";", line); if (line != $0) n++ }
    END { print n + 0 }'
}

# project_version_set <root> <X.Y.Z>: writes the version into every MARKETING_VERSION line of
# <root>/Overbright.xcodeproj/project.pbxproj, keeping what precedes the "="; fails, changing nothing, unless the file
# has such a line
project_version_set() {
  version_valid "$2" || return 1
  [ -n "$(project_versions <"$1/$PROJECT_FILE")" ] || return 1
  # shellcheck disable=SC2016 # an awk program
  _rewrite "$1/$PROJECT_FILE" '
    $0 ~ re { sub(/=.*$/, "= " v ";") }
    { print }' -v re="$PROJECT_VERSION_LINE_RE" -v v="$2"
}

# release_tag <X.Y.Z>: prints the tag of release X.Y.Z
release_tag() {
  echo "v$1"
}

# release_assets <X.Y.Z>: prints the names of the files release X.Y.Z publishes, one per line, in upload order: the
# zip and the disk image of Overbright.app, then their SHA-256 sums (scripts/lib/dist.sh writes all three to dist/)
release_assets() {
  echo "Overbright-$1.zip"
  echo "Overbright-$1.dmg"
  echo "Overbright-$1.sha256"
}

# release_tags: reads tag names, or the lines of `git ls-remote --tags` (refs/tags/<tag>, <tag>^{}), on stdin and
# prints "<X.Y.Z> <tag>" for every release tag (vX.Y.Z or X.Y.Z), once per tag
release_tags() {
  local line ref v seen=' '
  while IFS= read -r line || [ -n "$line" ]; do
    ref=${line##*[[:space:]]}
    ref=${ref#refs/tags/}
    ref=${ref%'^{}'}
    v=${ref#v}
    version_valid "$v" || continue
    case $seen in *" $ref "*) continue ;; esac
    seen="$seen$ref "
    echo "$v $ref"
  done
}

# highest_tag [skip]: reads what release_tags reads and prints "<X.Y.Z> <tag>" of the highest release tag other than
# the tag named skip; nothing when there is none
highest_tag() {
  local skip="${1:-}" v t best='' best_tag=''
  while read -r v t; do
    [ "$t" = "$skip" ] && continue
    if [ -z "$best" ] || version_gt "$v" "$best"; then
      best=$v best_tag=$t
    fi
  done < <(release_tags)
  [ -z "$best" ] || echo "$best $best_tag"
}

# tag_of_version <X.Y.Z>: reads what release_tags reads and prints the first tag of that version (vX.Y.Z or X.Y.Z);
# nothing when there is none. It reads release_tags to the end: a reader that stops early leaves release_tags writing
# into a closed pipe, which is "echo: write error: Broken pipe" where SIGPIPE is ignored (the GitHub runner)
tag_of_version() {
  local v t found=''
  while read -r v t; do
    if [ -z "$found" ] && [ "$v" = "$1" ]; then
      found=$t
    fi
  done < <(release_tags)
  [ -z "$found" ] || echo "$found"
}

# tag_commit <tag>: reads the lines of `git ls-remote --tags <remote>` (every tag: given a pattern, ls-remote leaves
# out an annotated tag's peeled line) on stdin and prints the commit refs/tags/<tag> is on: the peeled "<tag>^{}"
# line of an annotated tag, else the tag's own line; nothing when there is no such tag
tag_commit() {
  awk -v ref="refs/tags/$1" '
    $2 == ref { sha = $1 }
    $2 == ref "^{}" { peeled = $1 }
    END { if (peeled != "") print peeled; else if (sha != "") print sha }'
}
