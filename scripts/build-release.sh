#!/usr/bin/env bash
# Builds the release files of the version in VERSION exactly as the release workflow does (.github/workflows/release.yml
# runs this script, and so does the CI's build job): the universal Release build of Overbright.app
# (scripts/lib/build.sh), its launch smoke test (scripts/lib/smoke.sh), and the zip, the disk image and their SHA-256
# sums in dist/ (scripts/lib/dist.sh, which notarizes and staples when NOTARY_PROFILE is set). The list is
# release_assets in scripts/lib/version.sh:
#   Overbright-X.Y.Z.zip  Overbright-X.Y.Z.dmg  Overbright-X.Y.Z.sha256
# First every shipped language must be complete with nothing pending translation, as a release requires
# (scripts/lib/l10n/validate.py --shipped --release). Fails unless the app is version X.Y.Z, holds arm64 and x86_64
# and passes codesign's strict check with the hardened runtime (with Developer ID: signed for TEAM_ID; notarized: the
# tickets stapled and Gatekeeper accepting it), and dist/ holds the three files with matching sums. Prints the
# version, the signing, the files with their sizes and the sums.
#
#   scripts/build-release.sh [--test] [--allow-pending] [--out DIR]
#
#   --test           first make lint and make test (the unit tests)
#   --allow-pending  build even when strings are pending translation (the CI's build does; release.yml never does);
#                    the shipped languages must still be complete and valid (validate.py --shipped)
#   --out DIR        also copy the release files to DIR (they are always in dist/)
#
# Env: SIGN_IDENTITY, TEAM_ID         Developer ID signing, both or neither (neither: ad-hoc signed, and users allow
#                                     the app once with "Open Anyway")
#      NOTARY_PROFILE                 notarize and staple (xcrun notarytool's keychain profile, in NOTARY_KEYCHAIN
#                                     when that is set); needs SIGN_IDENTITY
#      BUILD_NUMBER                   CFBundleVersion (release.yml: its run number; default: the project's)
#      OVERBRIGHT_GITHUB_REPOSITORY   the update check's repository, owner/repo (release.yml: its own; default: none,
#                                     no update check)
#      CONTROLS=1                     keep the Control Center extension (default: 1 with TEAM_ID)
#      SIMULATE=1                     the smoke test never launches on the real display ports (agents; smoke.sh)
# bash 3.2. Needs Xcode 27+ (scripts/lib/lib.sh ensure_xcode).
# cd would print the directory it finds through an exported CDPATH, and that would end up in lib.sh's ROOT
unset CDPATH
# shellcheck source=scripts/lib/lib.sh
source "$(dirname "$0")/lib/lib.sh"
# shellcheck source=scripts/lib/version.sh
source "$ROOT/scripts/lib/version.sh"

usage() {
  cat <<'EOF'
Builds the release files of the version in VERSION the way GitHub Actions does (release.yml runs this script): the
universal Release build of Overbright.app, its launch smoke test, and Overbright-X.Y.Z.zip, .dmg and .sha256 in dist/.

  scripts/build-release.sh [--test] [--allow-pending] [--out DIR]

  --test           first make lint and make test (the unit tests)
  --allow-pending  build even when strings are pending translation (the CI does; a release never does); the
                   shipped languages must still be complete and valid
  --out DIR        also copy the release files to DIR (they are always in dist/)
  -h, --help       this help

Signing: Developer ID with SIGN_IDENTITY and TEAM_ID (both), notarized and stapled with NOTARY_PROFILE (a keychain
profile of xcrun notarytool); without them the app is ad-hoc signed and users allow it once with "Open Anyway".
BUILD_NUMBER sets CFBundleVersion; OVERBRIGHT_GITHUB_REPOSITORY (owner/repo) turns the update check on (release.yml
sets its own repository); CONTROLS=1 keeps the Control Center extension (the default with TEAM_ID); SIMULATE=1 keeps
the smoke test off the real display ports.
EOF
}
usage_error() {
  printf 'error: %s\n\n' "$*" >&2
  usage >&2
  exit 2
}
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
  else
    shasum -a 256 "$@"
  fi
}

run_tests='' allow_pending='' out=''
while (($#)); do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --test) run_tests=1 ;;
  --allow-pending) allow_pending=1 ;;
  --out)
    [[ $# -ge 2 && -n "$2" ]] || usage_error "--out needs a directory"
    out=$2
    shift
    ;;
  --out=?*) out=${1#--out=} ;;
  *) usage_error "unknown option $1" ;;
  esac
  shift
done

# The output directory exists and is writable before anything is built (or notarized)
if [[ -n "$out" ]]; then
  dir=''
  mkdir -p "$out" 2>/dev/null && dir="$(cd "$out" 2>/dev/null && pwd)" && [[ -w "$dir" ]] ||
    die "--out $out is not a directory this script can write to."
  out=$dir
fi

version="$(app_version_get "$ROOT")" || die "$APP_VERSION_FILE must hold the version alone, one line X.Y.Z."
version_valid "$version" ||
  die "$APP_VERSION_FILE holds '$version', not X.Y.Z (no leading zeros, no 'v', at most 9 digits per number)."
project="$(project_versions <"$ROOT/$PROJECT_FILE" | tr '\n' ' ')"
project=${project% }
[[ -z "$project" || "$project" == "$version" ]] ||
  warn "$PROJECT_FILE has MARKETING_VERSION $project; the release is $version ($APP_VERSION_FILE), and scripts/make-release.sh sets both."
assets="$(release_assets "$version" | tr '\n' ' ')"
sums="Overbright-$version.sha256"

# --- signing: Developer ID from the environment, or ad-hoc
if [[ -n "${SIGN_IDENTITY:-}" && -z "${TEAM_ID:-}" ]] || [[ -z "${SIGN_IDENTITY:-}" && -n "${TEAM_ID:-}" ]]; then
  die "set both SIGN_IDENTITY and TEAM_ID for Developer ID signing, or neither for an ad-hoc signed build."
fi
if [[ -n "${NOTARY_PROFILE:-}" && -z "${SIGN_IDENTITY:-}" ]]; then
  die "NOTARY_PROFILE needs SIGN_IDENTITY and TEAM_ID: Apple notarizes Developer ID builds only."
fi
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  signing="ad-hoc"
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
  signing="Developer ID ($SIGN_IDENTITY), notarized"
else
  signing="Developer ID ($SIGN_IDENTITY), not notarized (no NOTARY_PROFILE)"
fi
ensure_xcode

if [[ -n "$run_tests" ]]; then
  log "Checks: make lint"
  (cd "$ROOT" && make lint) || die "make lint failed."
  log "Unit tests: make test"
  # FILTER= : a FILTER in the environment would narrow the run to one suite
  (cd "$ROOT" && make test FILTER=) || die "the unit tests failed."
fi
if [[ -z "$allow_pending" ]]; then
  log "Translations: every shipped language complete, nothing pending (scripts/lib/l10n/validate.py --shipped --release)"
  /usr/bin/python3 -I "$ROOT/scripts/lib/l10n/validate.py" --shipped --release --quiet ||
    die "a shipped language lacks translations or has strings pending translation (scripts/lib/l10n/README.md). --allow-pending builds with pending strings; a release never does."
else
  log "Translations: every shipped language complete, pending strings allowed (scripts/lib/l10n/validate.py --shipped)"
  /usr/bin/python3 -I "$ROOT/scripts/lib/l10n/validate.py" --shipped --quiet ||
    die "a shipped language lacks translations or has invalid ones (scripts/lib/l10n/README.md)."
fi

# --- the build: no file of an earlier build of this version stays in dist/ to pass for a new one
APP="$BUILD_DIR/$APP_NAME.app"
DIST="$ROOT/dist"
for f in $assets notarize-upload.zip; do
  rm -f "$DIST/$f"
done

log "Release $version: scripts/lib/build.sh (Release, arm64 x86_64), signing: $signing"
CONFIGURATION=Release ARCHS="arm64 x86_64" MARKETING_VERSION="$version" "$ROOT/scripts/lib/build.sh"

info() { plutil -extract "$1" raw -o - "$APP/Contents/Info.plist"; }
built="$(info CFBundleShortVersionString)" || die "cannot read the version of $APP."
[[ "$built" == "$version" ]] || die "$APP is version $built, not $version."
build_number="$(info CFBundleVersion)" || die "cannot read the build number of $APP."
archs="$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")" || die "cannot read the architectures of $APP."
[[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]] || die "$APP is built for $archs, not arm64 and x86_64."
codesign --verify --deep --strict "$APP" || die "the code signature of $APP does not verify."
details="$(codesign -dv --verbose=2 "$APP" 2>&1)" || die "codesign cannot read the signature of $APP."
team="$(sed -n 's/^TeamIdentifier=//p' <<<"$details")"
runtime=''
if grep -Eq '^CodeDirectory .*flags=0x[0-9a-f]+\([^)]*runtime' <<<"$details"; then
  runtime=1
fi
# The project's Release builds always carry the hardened runtime, ad-hoc ones too; notarization requires it
[[ -n "$runtime" ]] || die "$APP is signed without the hardened runtime."
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  [[ "$team" == "$TEAM_ID" ]] || die "$APP is signed for team ${team:-none}, not $TEAM_ID."
else
  grep -q '^Signature=adhoc$' <<<"$details" || die "$APP is not ad-hoc signed, although SIGN_IDENTITY is not set."
fi

log "Smoke test: scripts/lib/smoke.sh"
APP="$APP" "$ROOT/scripts/lib/smoke.sh"

log "Packaging: scripts/lib/dist.sh"
REBUILD=0 "$ROOT/scripts/lib/dist.sh"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  for f in "$APP" "$DIST/Overbright-$version.dmg"; do
    xcrun stapler validate "$f" >/dev/null || die "$f has no valid stapled notarization ticket."
  done
  spctl --assess --type execute "$APP" 2>/dev/null || die "Gatekeeper does not accept $APP (spctl --assess)."
fi

# Exactly the release files, with the sums of the zip and the disk image
missing=''
for f in $assets; do
  [[ -s "$DIST/$f" ]] || missing="$missing $f"
done
[[ -z "$missing" ]] || die "dist/ lacks:$missing."
listed="$(awk '{ name = $2; sub(/^\*/, "", name); print name }' "$DIST/$sums" | LC_ALL=C sort | tr '\n' ' ')"
wanted="$(release_assets "$version" | grep -vxF "$sums" | LC_ALL=C sort | tr '\n' ' ')"
[[ "$listed" == "$wanted" ]] || die "$sums lists ${listed:-nothing }instead of ${wanted% }."
(cd "$DIST" && sha256 -c "$sums" >/dev/null) || die "the files in dist/ do not match $sums."

dest=$DIST
if [[ -n "$out" ]]; then
  if [[ "$(cd "$out" && pwd -P)" != "$(cd "$DIST" && pwd -P)" ]]; then
    for f in $assets; do
      cp "$DIST/$f" "$out/$f"
    done
    (cd "$out" && sha256 -c "$sums" >/dev/null) || die "the files in $out do not match $sums."
    dest=$out
  fi
fi

repository="$(info OverbrightGitHubRepository 2>/dev/null || true)"
echo
echo "Release $version (build $build_number): $dest"
for f in $assets; do
  printf '  %10s  %s\n' "$(wc -c <"$dest/$f" | tr -d ' ')" "$f"
done
echo
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  echo "Signing: ad-hoc; users allow the app once with \"Open Anyway\" (SIGN_IDENTITY, TEAM_ID and NOTARY_PROFILE notarize it)"
else
  echo "Signing: $(awk '/^Authority=/ { sub(/^Authority=/, ""); print; exit }' <<<"$details") (team $team)"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "  notarized, the ticket stapled to the app and the disk image"
  else
    echo "  not notarized (no NOTARY_PROFILE): Gatekeeper asks users to allow the app"
  fi
fi
echo "Update check: ${repository:-off (OVERBRIGHT_GITHUB_REPOSITORY not set; release.yml sets its repository)}"
if [[ -d "$APP/Contents/PlugIns/$CONTROLS_APPEX" ]]; then
  echo "Control Center extension: kept"
else
  echo "Control Center extension: removed (CONTROLS=1 keeps it)"
fi
[[ -z "$allow_pending" ]] || echo "Translations: strings pending translation allowed (--allow-pending); a release refuses them"
echo
echo "SHA-256 ($sums):"
sed 's/^/  /' "$dest/$sums"
other=''
for path in "$dest"/* "$dest"/.[!.]*; do
  [[ -e "$path" ]] || continue
  case " $assets " in *" ${path##*/} "*) continue ;; esac
  other="$other ${path##*/}"
done
[[ -z "$other" ]] || echo "Also in $dest, not part of the release:$other"
