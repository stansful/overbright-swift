#!/usr/bin/env bash
# Release build of Overbright.app (universal arm64 + x86_64) -> build/Overbright.app (+ .dSYM). ARCHITECTURE.md §8.7.
#
#   scripts/lib/build.sh                 # ad-hoc signed ("Sign to Run Locally"), no Apple account needed
#   ARCHS=arm64 scripts/lib/build.sh     # single-arch (faster)
#   CONFIGURATION=Debug scripts/lib/build.sh
#   CONTROLS=1 scripts/lib/build.sh      # keep the dormant Control Center extension (D18; default 1 when TEAM_ID is
#                                        # set)
#   SIGN_IDENTITY="Developer ID Application: Jane Doe (TEAMID1234)" TEAM_ID=TEAMID1234 scripts/lib/build.sh
#   OVERBRIGHT_GITHUB_REPOSITORY=owner/repo scripts/lib/build.sh   # the update check's repository (release.yml sets it;
#                                                                  # empty, the default, = no update check, no network)
#
# The OverbrightControls extension target is always built (so it stays compile-checked) and embedded by Xcode; unless
# CONTROLS=1, the copy in build/ drops it and is re-signed (scripts/lib/lib.sh drop_controls_extension).
source "$(dirname "$0")/lib.sh"
ensure_xcode

CONFIGURATION="${CONFIGURATION:-Release}"
ARCHS="${ARCHS:-arm64 x86_64}"
LOG="$BUILD_DIR/logs/build-$CONFIGURATION.log"
mkdir -p "$BUILD_DIR/logs"

overrides=(ARCHS="$ARCHS" ONLY_ACTIVE_ARCH=NO)
if [[ "$CONFIGURATION" == Release ]]; then
  # Strip like an archive does: no local symbols or debug-map stabs (they hold the builder's absolute
  # paths) in the shipped binaries; the dSYMs next to the app keep everything for symbolication.
  # Xcode strips before signing.
  overrides+=(DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES)
fi
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # Distribution signing (maintainers only). Secure timestamp is required for notarization.
  overrides+=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY" DEVELOPMENT_TEAM="${TEAM_ID:?TEAM_ID is required with SIGN_IDENTITY}"
              OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi
MARKETING_VERSION="${MARKETING_VERSION:-$(tr -d "[:space:]" < "$ROOT/VERSION")}"
overrides+=(MARKETING_VERSION="$MARKETING_VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && overrides+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
# The GitHub repository of the update check (Info.plist OverbrightGitHubRepository, D2): "owner/repo", or empty.
if [[ -n "${OVERBRIGHT_GITHUB_REPOSITORY:-}" ]]; then
  [[ "$OVERBRIGHT_GITHUB_REPOSITORY" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] \
    || die "OVERBRIGHT_GITHUB_REPOSITORY must be owner/repo, got '$OVERBRIGHT_GITHUB_REPOSITORY'"
  overrides+=(OVERBRIGHT_GITHUB_REPOSITORY="$OVERBRIGHT_GITHUB_REPOSITORY")
fi

PRODUCT="$DERIVED_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"

run_xcodebuild() {
  # 'generic/platform=macOS' (= "Any Mac") is what makes xcodebuild honour ARCHS; with the
  # implicit "My Mac" run destination it silently builds only the host architecture.
  set +e
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DIR" \
    "${overrides[@]}" 2>&1 | tee "$LOG" | xcpretty_filter
  local status=${PIPESTATUS[0]}
  set -e
  (( status == 0 )) || die "xcodebuild failed ($status); full log: $LOG"
}

# String Catalogs (§8.8): an incremental build never clears what an earlier one compiled, so a language removed from a
# catalog keeps its <lang>.lproj, and a bundle can miss a table it should have. When any catalog differs from the last
# build of this configuration, the package's resource bundles, their intermediates and the app are built from scratch.
CATALOG_STAMP="$DERIVED_DIR/catalogs-$CONFIGURATION.sha256"
catalog_digest() {
  local file
  find "$PACKAGE_DIR/Sources" "$ROOT/App" "$ROOT/Controls" -name '*.xcstrings' -type f | LC_ALL=C sort |
    while IFS= read -r file; do
      printf '%s  %s\n' "$(shasum -a 256 < "$file" | awk '{print $1}')" "${file#"$ROOT"/}"
    done | shasum -a 256 | awk '{print $1}'
}
catalogs_now="$(catalog_digest)"
if [[ "$(cat "$CATALOG_STAMP" 2>/dev/null || true)" != "$catalogs_now" ]]; then
  products="$DERIVED_DIR/Build/Products/$CONFIGURATION"
  intermediates="$DERIVED_DIR/Build/Intermediates.noindex/OverbrightKit.build/$CONFIGURATION"
  if [[ -d "$products" ]]; then
    log "String Catalogs changed since the last $CONFIGURATION build; rebuilding the resource bundles"
  fi
  rm -rf "$products"/OverbrightKit_*.bundle "$intermediates"/OverbrightKit_*-b.build "$PRODUCT"
fi

log "Building $SCHEME ($CONFIGURATION, $ARCHS) with $(xcodebuild -version | head -1)"
run_xcodebuild
mkdir -p "$DERIVED_DIR"
printf '%s\n' "$catalogs_now" > "$CATALOG_STAMP"
# An incremental build that only changed package resources (String Catalogs) can copy new
# .lproj files into the app without re-signing it ("a sealed resource is missing or invalid").
# Rebuild the app product once from scratch in that case.
if ! codesign --verify --deep --strict "$PRODUCT" 2>/dev/null; then
  log "Stale signature on the incremental product; rebuilding $APP_NAME.app"
  rm -rf "$PRODUCT"
  run_xcodebuild
fi

APP="$BUILD_DIR/$APP_NAME.app"
unregister_app "$APP"
rm -rf "$APP" "$APP.dSYM" "$BUILD_DIR/$CONTROLS_APPEX.dSYM"
ditto "$PRODUCT" "$APP"
[[ -d "$PRODUCT.dSYM" ]] && ditto "$PRODUCT.dSYM" "$APP.dSYM"
# The intents and the Focus filter exist for the system only through the extracted metadata (§7.7). Its extraction
# reads the link's dependency file; a Debug build that splits the binary into a debug dylib and a preview dylib links
# twice into the same file and can skip it ("no AppIntents.framework dependency found"). The project turns the split
# off (ENABLE_DEBUG_DYLIB = NO); this catches any build that still comes out without it.
/usr/bin/python3 -I - "$APP/Contents/Resources/Metadata.appintents/extract.actionsdata" <<'PY' \
  || die "App Intents metadata missing; run make clean"
import json, sys
try:
    actions = json.load(open(sys.argv[1], encoding="utf-8")).get("actions")
except (OSError, ValueError):
    actions = None
sys.exit(0 if actions else 1)
PY

codesign --verify --deep --strict "$APP" || die "code signature verification failed"
[[ -d "$APP/Contents/PlugIns/$CONTROLS_APPEX" ]] || die "$CONTROLS_APPEX is missing from the build (Overbright.xcodeproj)"
if controls_enabled; then
  controls="kept"
  extension_dsym="$DERIVED_DIR/Build/Products/$CONFIGURATION/$CONTROLS_APPEX.dSYM"
  [[ -d "$extension_dsym" ]] && ditto "$extension_dsym" "$BUILD_DIR/$CONTROLS_APPEX.dSYM"
else
  drop_controls_extension "$APP"
  # Xcode registers every built extension with PlugInKit; forget the DerivedData copy too, so a dev control never
  # shows up in the Control Center gallery (F1 risk 5).
  pluginkit -r "$PRODUCT/Contents/PlugIns/$CONTROLS_APPEX" >/dev/null 2>&1 || true
  controls="removed (CONTROLS=1 keeps it)"
fi
# Every translation the catalogs hold is compiled into the bundle that uses it (a bundle without its table shows
# English while the locale's formats follow the app), and no stale .lproj is left.
/usr/bin/python3 -I "$ROOT/scripts/lib/check-lproj.py" "$APP" \
  || die "the app lacks compiled translations (see above); run make clean and build again"
if [[ "$CONFIGURATION" == Release ]]; then
  # Shipped binaries must not carry debug-map stabs (absolute paths of the build machine). An incremental
  # build over products made before stripping was enabled can keep an old copy: start clean then.
  for binary in "$APP/Contents/MacOS/$APP_NAME" "$APP"/Contents/PlugIns/*.appex/Contents/MacOS/*; do
    [[ -f "$binary" ]] || continue
    stabs="$(nm -ap "$binary" 2>/dev/null | grep -cE ' (SO|OSO) ' || true)"
    [[ "$stabs" == 0 ]] || die "$binary is not stripped (stale build products?); run \`make clean\` and build again"
  done
fi
log "Built $APP"
log "  version $(plist_value "$APP" CFBundleShortVersionString) ($(plist_value "$APP" CFBundleVersion))"
log "  $(lipo -archs "$APP/Contents/MacOS/$APP_NAME" | sed 's/^/archs: /')"
log "  Controls extension: $controls"
log "  update check: $(plist_value "$APP" OverbrightGitHubRepository | sed 's/^$/off (no repository)/')"
log "  $(codesign -dv "$APP" 2>&1 | grep -E '^(Signature|TeamIdentifier|CodeDirectory)' | tr '\n' ' ')"
