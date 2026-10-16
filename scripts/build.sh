#!/usr/bin/env bash
# Release build of Overbright.app (universal arm64 + x86_64) -> build/Overbright.app (+ .dSYM). ARCHITECTURE.md §8.7.
#
#   scripts/build.sh                 # ad-hoc signed ("Sign to Run Locally"), no Apple account needed
#   ARCHS=arm64 scripts/build.sh     # single-arch (faster)
#   CONFIGURATION=Debug scripts/build.sh
#   CONTROLS=1 scripts/build.sh      # keep the dormant Control Center extension (D18; default 1 when TEAM_ID is set)
#   SIGN_IDENTITY="Developer ID Application: Jane Doe (TEAMID1234)" TEAM_ID=TEAMID1234 scripts/build.sh
#
# The OverbrightControls extension target is always built (so it stays compile-checked) and embedded by Xcode; unless
# CONTROLS=1, the copy in build/ drops it and is re-signed (scripts/lib.sh drop_controls_extension).
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

log "Building $SCHEME ($CONFIGURATION, $ARCHS) with $(xcodebuild -version | head -1)"
run_xcodebuild
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
log "  $(codesign -dv "$APP" 2>&1 | grep -E '^(Signature|TeamIdentifier|CodeDirectory)' | tr '\n' ' ')"
