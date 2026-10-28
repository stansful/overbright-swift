#!/usr/bin/env bash
# Prints the notes of release $VERSION: the commit subjects since the previous release tag (the highest vX.Y.Z or
# X.Y.Z tag in the history of $GITHUB_SHA other than the release's own), newest first, one "- " line each, without
# merges and without the release commits of scripts/make-release.sh. With no earlier release in the history every
# commit would be a change: the first release says so instead.
#
# Env: GITHUB_SHA (default HEAD), VERSION (default: VERSION).
# Reads the tags and the history of this checkout (release.yml fetches them all).
set -euo pipefail
# cd would print the directory it finds through an exported CDPATH, and that would end up in HERE and ROOT_DIR
unset CDPATH

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd "$HERE/../.." && pwd -P)"
# shellcheck source=scripts/lib/version.sh
. "$ROOT_DIR/scripts/lib/version.sh"

sha="${GITHUB_SHA:-HEAD}"
VERSION="${VERSION:-$(app_version_get "$ROOT_DIR" || true)}"
version_valid "$VERSION" || {
  echo "release-notes: '$VERSION' is not X.Y.Z" >&2
  exit 1
}

prev="$(git -C "$ROOT_DIR" tag --no-column --merged "$sha" | highest_tag "$(release_tag "$VERSION")")"
if [ -z "$prev" ]; then
  echo "- The first release of Overbright"
  exit 0
fi
prev=${prev#* }
changes="$(git -C "$ROOT_DIR" log --no-merges --max-count=200 --pretty=format:'- %s' "$prev..$sha" |
  { grep -v '^- feat: release - version [0-9]' || true; })"

printf '%s\n' "${changes:-- Release $VERSION}"
