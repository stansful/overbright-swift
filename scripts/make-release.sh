#!/usr/bin/env bash
# Prepares a release: shows the current version (VERSION) and the last release tag, asks for the new version (Enter
# takes the next patch version, or the minor or major one at the 9-digit limit), checks that it is higher than the
# current version and every release tag (local ones and origin's), writes it into VERSION and into the MARKETING_VERSION lines of Overbright.xcodeproj/project.pbxproj
# (the builds that bypass scripts/lib/build.sh read those), and commits only these files as
# "feat: release - version X.Y.Z". It never pushes: the release starts when that commit reaches main on GitHub
# (.github/workflows/release.yml: the CI checks, scripts/build-release.sh and release X.Y.Z). No tags here: GitHub
# creates the tag vX.Y.Z when the workflow publishes the release.
#
#   scripts/make-release.sh [X.Y.Z|patch|minor|major] [--yes] [--no-commit]
#
# Runs from any directory; bash 3.2 (macOS) or 5 (Linux), BSD or GNU tools.
set -euo pipefail
# cd would print the directory it finds through an exported CDPATH, and that would end up in HERE and ROOT_DIR
unset CDPATH

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd "$HERE/.." && pwd -P)"
# shellcheck source=scripts/lib/version.sh
. "$HERE/lib/version.sh"

usage() {
  cat <<'EOF'
Prepares an Overbright release: the new version goes into VERSION and the MARKETING_VERSION lines of
Overbright.xcodeproj/project.pbxproj, committed as "feat: release - version X.Y.Z". Release X.Y.Z (tag vX.Y.Z) goes out
when that commit is on main on GitHub (.github/workflows/release.yml).

  scripts/make-release.sh [X.Y.Z|patch|minor|major] [--yes] [--no-commit]

  X.Y.Z          the new version; without it the script shows the current one and asks (Enter: the next patch
                 version, or the minor or major one when the patch number is at its 9-digit limit)
  patch, minor, major
                 the next patch, minor or major version
  -y, --yes      no questions: the version Enter would take (unless one is given), and the commit without asking
  --no-commit    only write the version, no commit
  -h, --help     this help

A version is X.Y.Z without leading zeros and without "v" (at most 9 digits per number), higher than the current
version and every release tag (local ones and origin's). No tag is made here: GitHub creates vX.Y.Z when it
publishes the release.
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
usage_error() {
  printf 'error: %s\n\n' "$*" >&2
  usage >&2
  exit 2
}
yes_answer() {
  case $1 in
  y | Y | yes | Yes | YES) return 0 ;;
  *) return 1 ;;
  esac
}
trim() {
  local s="$1"
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}
# bump_kind <word>: prints patch, minor or major for a bump word; fails for anything else
bump_kind() {
  case $1 in
  patch | Patch | PATCH) echo patch ;;
  minor | Minor | MINOR) echo minor ;;
  major | Major | MAJOR) echo major ;;
  *) return 1 ;;
  esac
}

new='' have_new='' yes='' commit=1
while [ $# -gt 0 ]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  -y | --yes) yes=1 ;;
  --no-commit) commit= ;;
  -*) usage_error "unknown option $1" ;;
  *)
    [ -z "$have_new" ] || usage_error "the version is given twice: $new and $1"
    new=$1 have_new=1
    ;;
  esac
  shift
done

# --- the repository
command -v git >/dev/null 2>&1 || die "git is required."
top="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null)" ||
  die "$ROOT_DIR is not a git repository. Start with git init, a first commit and git remote add origin <url>."
[ "$(cd "$top" && pwd -P)" = "$ROOT_DIR" ] || die "$ROOT_DIR is not the root of its git repository (the root is $top)."
cd "$ROOT_DIR"
git rev-parse -q --verify HEAD >/dev/null || die "the repository has no commit yet: commit the project first."
branch="$(git symbolic-ref -q --short HEAD)" ||
  die "HEAD is not on a branch (detached HEAD): switch to one first, for example git switch main."
for f in "$APP_VERSION_FILE" "$PROJECT_FILE"; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || die "$f is not in git: commit it first."
done

dirty="$(git status --porcelain --untracked-files=no)"
if [ -n "$dirty" ]; then
  printf 'error: there are uncommitted changes (working tree or index):\n%s\n' "$dirty" >&2
  printf 'Commit or stash them (git stash) and run this again: the release commit holds the version and nothing else.\n' >&2
  exit 1
fi
untracked="$(git ls-files --others --exclude-standard)"
if [ -n "$untracked" ]; then
  warn "these files are not in git, so the release does not have them:"
  printf '%s\n' "$untracked" | sed -n '1,10s/^/  /p' >&2
  [ "$(printf '%s\n' "$untracked" | wc -l | tr -d ' ')" -le 10 ] || printf '  …\n' >&2
fi

has_origin=
git remote get-url origin >/dev/null 2>&1 && has_origin=1

# The default branch: origin's HEAD, else main or master (origin's or local)
default=
if ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
  default=${ref#origin/}
else
  for b in main master; do
    if git show-ref -q --verify "refs/remotes/origin/$b" || git show-ref -q --verify "refs/heads/$b"; then
      default=$b
      break
    fi
  done
fi
if [ -z "$default" ]; then
  warn "the default branch is unknown; releases go out from main only."
elif [ "$branch" != "$default" ]; then
  warn "you are on $branch, and releases go out from $default: this commit is released once it is merged into $default."
fi
if [ -n "$has_origin" ] && git show-ref -q --verify "refs/remotes/origin/$branch"; then
  behind="$(git rev-list --count "HEAD..refs/remotes/origin/$branch")"
  [ "$behind" = 0 ] ||
    warn "$branch is $behind commit(s) behind origin/$branch (as of the last fetch): git pull first."
fi

# --- versions
current="$(app_version_get "$ROOT_DIR")" ||
  die "$APP_VERSION_FILE must hold the version alone, one line X.Y.Z: fix it by hand and commit it."
version_valid "$current" ||
  die "$APP_VERSION_FILE holds '$current', not X.Y.Z (no leading zeros, no 'v', at most 9 digits per number): fix it by hand and commit it."

# The project's MARKETING_VERSION lines follow VERSION; a project without them leaves VERSION alone in the commit
files=("$APP_VERSION_FILE")
project="$(project_versions <"$PROJECT_FILE" | tr '\n' ' ')"
project=${project% }
if [ -z "$project" ]; then
  warn "$PROJECT_FILE has no MARKETING_VERSION line: only $APP_VERSION_FILE gets the new version."
else
  files=("$APP_VERSION_FILE" "$PROJECT_FILE")
  [ "$project" = "$current" ] ||
    warn "$PROJECT_FILE has MARKETING_VERSION $project, $APP_VERSION_FILE $current: both get the new version."
fi
# The file names for messages, joined here: inside "IFS= read" (and a trap that fires there) ${files[*]} has no space
names="${files[*]}"

# Releases are tagged on GitHub, so a clone often has no tags of its own: origin's count. tags_known is empty when
# origin has them but they could not be read.
tags="$(git tag -l --no-column)" tags_known=1
if [ -n "$has_origin" ]; then
  if remote="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags origin)"; then
    tags="$tags
$remote"
  else
    tags_known=
    warn "could not read origin's tags ($(git remote get-url origin)): comparing with the local tags only."
  fi
fi
highest="$(printf '%s\n' "$tags" | highest_tag)"
highest_version=${highest%% *}
last_tag=${highest#* }

say "Current version ($APP_VERSION_FILE): $current"
if [ -n "$highest" ]; then
  if [ -n "$tags_known" ]; then
    say "Last release tag:          $last_tag"
  else
    say "Last release tag:          $last_tag (of the local tags)"
  fi
elif [ -n "$tags_known" ]; then
  say "No release tag yet."
else
  say "Release tags unknown: no local ones, and origin's could not be read."
fi
if [ -n "$tags_known" ] && { [ -z "$highest" ] || version_gt "$current" "$highest_version"; }; then
  say "No tag $(release_tag "$current") yet: once a commit with version $current is on main on GitHub, release $current goes out without a new version too."
fi
base=$current
[ -z "$highest" ] || ! version_gt "$highest_version" "$base" || base=$highest_version
# What Enter and --yes take: the next patch version of the base, or the minor one when the patch number is at its
# limit, or the major one when both are (a bump of the base is above the current version and every tag)
suggested=''
for kind in patch minor major; do
  v="$(version_bump "$base" "$kind")"
  if version_valid "$v"; then
    suggested=$v
    break
  fi
done
[ -n "$suggested" ] || die "no version after $base fits X.Y.Z with at most 9 digits per number."

# check_version <v>: prints why v cannot be the new version, and fails
check_version() {
  local v="$1" t
  if [ -z "$v" ]; then
    echo "no version given"
    return 1
  fi
  if ! version_valid "$v"; then
    case $v in
    v[0-9]* | V[0-9]*) echo "'$v': give the version without 'v', like ${v#?}" ;;
    *) echo "'$v' is not a version X.Y.Z (three numbers without leading zeros, at most 9 digits each, like $suggested)" ;;
    esac
    return 1
  fi
  t="$(printf '%s\n' "$tags" | tag_of_version "$v")"
  if [ -n "$t" ]; then
    echo "tag $t exists: version $v was released already"
    return 1
  fi
  if ! version_gt "$v" "$current"; then
    echo "version $v is not higher than the current version $current"
    return 1
  fi
  if [ -n "$highest" ] && ! version_gt "$v" "$highest_version"; then
    echo "version $v is not higher than the last release tag $last_tag"
    return 1
  fi
}
# resolve <answer>: prints the version an answer names: a bump word becomes that bump of the base version
resolve() {
  local kind
  if kind="$(bump_kind "$1")"; then
    version_bump "$base" "$kind"
  else
    printf '%s' "$1"
  fi
}

if [ -n "$have_new" ]; then
  new="$(resolve "$new")"
  reason="$(check_version "$new")" || die "$reason."
  say "New version: $new"
elif [ -n "$yes" ]; then
  new=$suggested
  reason="$(check_version "$new")" || die "$reason."
  say "New version: $new"
else
  while :; do
    printf 'New version [%s]: ' "$suggested"
    if ! IFS= read -r answer; then
      echo
      die "input ended, nothing changed."
    fi
    answer="$(trim "$answer")"
    [ -n "$answer" ] || answer=$suggested
    answer="$(resolve "$answer")"
    if reason="$(check_version "$answer")"; then
      new=$answer
      break
    fi
    printf '  %s. Enter another version.\n' "$reason" >&2
  done
fi

# --- the version files and the commit
message="feat: release - version $new"
# What the commit changes: the version line of VERSION and the project's MARKETING_VERSION lines that do not already
# read as project_version_set writes them, one line out and one in each, in git's path order (-O/dev/null: a
# diff.orderFile setting must not reorder the paths)
numstat="$(
  if [ ${#files[@]} -gt 1 ]; then
    n="$(project_version_lines "$new" <"$PROJECT_FILE")"
    [ "$n" = 0 ] || printf '%s\t%s\t%s\n' "$n" "$n" "$PROJECT_FILE"
  fi
  printf '1\t1\t%s\n' "$APP_VERSION_FILE"
)"
changed_files="$(printf '%s\n' "$numstat" | cut -f 3)"
# committed_versions_are <X.Y.Z>: whether every version file of HEAD holds the version
committed_versions_are() {
  [ "$(git show "HEAD:$APP_VERSION_FILE" 2>/dev/null | app_version_parse)" = "$1" ] || return 1
  [ ${#files[@]} -eq 1 ] || [ "$(git show "HEAD:$PROJECT_FILE" 2>/dev/null | project_versions)" = "$1" ]
}
# write_versions: writes the new version into the version files; fails unless exactly the version lines changed, to
# exactly the new version
write_versions() {
  app_version_set "$ROOT_DIR" "$new" || return 1
  [ ${#files[@]} -eq 1 ] || project_version_set "$ROOT_DIR" "$new" || return 1
  [ "$(app_version_get "$ROOT_DIR")" = "$new" ] || return 1
  [ ${#files[@]} -eq 1 ] || [ "$(project_versions <"$PROJECT_FILE")" = "$new" ] || return 1
  [ "$(git diff -O/dev/null --numstat -- "${files[@]}")" = "$numstat" ]
}
# The git object ids of the version files as write_versions wrote them, one per file in the order of files. A file
# that changes after that, as project.pbxproj does whenever Xcode saves a setting, is neither committed nor overwritten.
written=()
# changed_since_written: prints the version files that no longer hold what write_versions wrote, one per line
changed_since_written() {
  local i
  for i in "${!files[@]}"; do
    [ "$(git hash-object -- "${files[$i]}" 2>/dev/null)" = "${written[$i]}" ] || echo "${files[$i]}"
  done
}
# restore [force]: checks the version files out of HEAD, except (without force) those that changed after
# write_versions wrote them, and sets restored to what happened, for the messages. It never stops the script: a failed
# checkout is reported, not hidden.
restore() {
  # a signal that arrives inside "IFS= read" runs this with that IFS: ${back[*]} needs its space
  local IFS=' ' f kept='' back=() left=''
  if [ "${1:-}" != force ] && [ ${#written[@]} -gt 0 ]; then
    kept="$(changed_since_written)"
  fi
  for f in "${files[@]}"; do
    case "
$kept
" in
    *"
$f
"*) left="$left${left:+ }$f" ;;
    *) back+=("$f") ;;
    esac
  done
  restored=''
  if [ ${#back[@]} -gt 0 ]; then
    if git checkout -q HEAD -- "${back[@]}"; then
      restored="${back[*]} restored"
    else
      restored="${back[*]} NOT restored: git checkout failed (see above), so undo the version lines by hand"
    fi
  fi
  [ -z "$left" ] ||
    restored="$restored${restored:+; }$left left as it is: it changed after the version was written (git diff)"
}
# quiet_signals: from here on the script only cleans up and exits: no signal may cut that short. git inherits the
# ignored signals, so a terminal closing or a second Ctrl-C cannot stop a checkout half-way either.
quiet_signals() { trap '' INT TERM HUP; }
parent=''
# interrupted <status>: undoes a release commit a signal cut short, restores the files and exits
interrupted() {
  quiet_signals
  local undone=''
  if [ -n "$parent" ] && [ "$(git rev-parse -q --verify HEAD)" != "$parent" ]; then
    if ! { git reset -q --soft "$parent" && git reset -q -- "${files[@]}"; }; then
      printf '\nInterrupted after the release commit, which could not be undone (see above): git reset --soft %s\n' \
        "$parent" >&2 || true
      exit "$1"
    fi
    undone='the release commit is undone, '
  fi
  restore
  printf '\nInterrupted: %s%s.\n' "$undone" "$restored" >&2 || true
  exit "$1"
}
trap 'interrupted 130' INT
trap 'interrupted 143' TERM
trap 'interrupted 129' HUP
if ! write_versions; then
  quiet_signals
  restore
  die "could not write version $new into $names; $restored."
fi
for f in "${files[@]}"; do
  written+=("$(git hash-object -- "$f")")
done
# Shown only, so neither a diff.orderFile nor a diff.external program of the user's may fail the release here
git --no-pager diff --no-ext-diff -O/dev/null -- "${files[@]}" || true

if [ -z "$commit" ]; then
  trap - INT TERM HUP
  say "$names: version $new. No commit (--no-commit). Commit only these files:"
  say "  git commit -m '$message' -- $names"
  exit 0
fi
if [ -z "$yes" ]; then
  printf 'Commit %s as "%s"? [Y/n] ' "$names" "$message"
  if ! IFS= read -r answer; then
    quiet_signals
    echo || true
    restore
    die "input ended; $restored."
  fi
  answer="$(trim "$answer")"
  if [ -n "$answer" ] && ! yes_answer "$answer"; then
    quiet_signals
    restore
    say "Cancelled: $restored, no commit."
    exit 1
  fi
fi
moved="$(changed_since_written | tr '\n' ' ')"
moved=${moved% }
if [ -n "$moved" ]; then
  quiet_signals
  restore
  die "$moved changed while the script waited, so nothing is committed: $restored. Undo the new version lines there (git checkout -p -- $moved) or commit the other change first, then run the script again."
fi
parent="$(git rev-parse HEAD)"
if ! git commit -q -m "$message" -- "${files[@]}"; then
  quiet_signals
  restore
  die "git commit failed; $restored."
fi
# git hooks (pre-commit and the like) run on the commit's own index: whatever one stages lands in the commit. The
# release commit is the version lines with the new version and nothing else, or it is undone.
changed="$(git diff-tree -r --name-only "$parent" HEAD)"
if [ "$changed" != "$changed_files" ] || [ "$(git diff -O/dev/null --numstat "$parent" HEAD)" != "$numstat" ] ||
  ! committed_versions_are "$new"; then
  quiet_signals
  if ! { git reset -q --soft "$parent" && git reset -q -- "${files[@]}"; }; then
    die "a git hook changed the release commit, and undoing it failed (see above): git reset --soft $parent"
  fi
  # the hook's rewrite of the version files goes with the commit
  restore force
  {
    printf 'error: a git hook (pre-commit or another) changed the release commit, which must hold the version lines of %s with version %s and nothing else. The commit had:\n' "$names" "$new"
    printf '%s\n' "$changed" | sed 's/^/  /'
    printf 'The commit is undone and %s; what the hook changed in other files is still there (git status).\n' "$restored"
    printf 'Fix the hook, or commit without hooks: scripts/make-release.sh %s --no-commit, then\n' "$new"
    printf "  git commit --no-verify -m '%s' -- %s\n" "$message" "$names"
  } >&2
  exit 1
fi
trap - INT TERM HUP
say "Commit $(git rev-parse --short HEAD): $message"
if [ -n "$has_origin" ]; then
  say "Push it (git push origin $branch): release $new (tag $(release_tag "$new")) goes out once this commit is on main on GitHub (.github/workflows/release.yml)."
else
  say "Add the GitHub repository (git remote add origin <url>) and push: release $new (tag $(release_tag "$new")) goes out once this commit is on main on GitHub (.github/workflows/release.yml)."
fi
