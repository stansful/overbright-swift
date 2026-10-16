#!/usr/bin/env bash
# Update every OverbrightKit String Catalog with the keys the compiler extracted from code (what Xcode's editor does
# after a build, but scriptable and CI-friendly). ARCHITECTURE.md §8.7, §8.8.
#
#   scripts/sync-strings.sh                       # build targets that have a catalog, then sync
#   scripts/sync-strings.sh OverbrightBoost       # just these targets (parallel work on one module)
#   CHECK=1 scripts/sync-strings.sh [Target…]     # fail if a catalog would change (for CI)
#
# A target may hold several tables (Sources/<T>/Resources/*.xcstrings: Localizable plus a co-tenant's own table such
# as Boost's Safety or AppShell's StatusMenu and Calibration, §8.8). They are synced together, so each key lands in the
# table its `String(localized:table:)` names. Uses the compiler-produced .stringsdata (exact keys such as
# "%lld minutes left"). `xcstringstool extract` exists too, but its lightweight parser turns interpolations into
# "%arg" keys, so we do not use it. The app target's catalogs (App/*.xcstrings) are maintained by their owners.
source "$(dirname "$0")/lib.sh"
ensure_xcode
cd "$PACKAGE_DIR"

scratch="$PACKAGE_DIR/.build-strings"
changed=0
targets=()
if (($#)); then
  for t in "$@"; do
    compgen -G "Sources/$t/Resources/*.xcstrings" >/dev/null || die "no String Catalog for target $t"
    targets+=("$t")
  done
else
  for dir in Sources/*/Resources; do
    compgen -G "$dir/*.xcstrings" >/dev/null || continue
    targets+=("$(basename "$(dirname "$dir")")")
  done
fi
for target in "${targets[@]}"; do
  log "$target"
  # The .stringsdata paths below are the swift-build backend's layout: request it explicitly
  # (default on SwiftPM 6.4; Xcode 26's SwiftPM 6.2 defaults to the native backend).
  swift build "${SWIFTPM_FLAGS[@]}" --build-system swiftbuild --target "$target" --scratch-path "$scratch" >/dev/null 2>&1 \
    || die "build of $target failed (run scripts/check-modules.sh $target)"
  stringsdata=()
  while IFS= read -r f; do stringsdata+=("$f"); done < <(
    find "$scratch/out/Intermediates.noindex" -path "*/$target-t.build/*" -name '*.stringsdata' 2>/dev/null)
  (( ${#stringsdata[@]} )) || die "no .stringsdata for $target (is SwiftPM using the swiftbuild backend?)"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/overbright-strings.XXXXXX")"
  cp "Sources/$target/Resources/"*.xcstrings "$tmp/"
  xcrun xcstringstool sync "$tmp/"*.xcstrings --stringsdata "${stringsdata[@]}"
  for catalog in "Sources/$target/Resources/"*.xcstrings; do
    synced="$tmp/$(basename "$catalog")"
    if ! cmp -s "$catalog" "$synced"; then
      changed=1
      if [[ "${CHECK:-0}" == 1 ]]; then
        warn "$catalog is out of date"
      else
        cp "$synced" "$catalog"
        log "  updated $catalog"
      fi
    fi
  done
  rm -rf "$tmp"
done
if [[ "${CHECK:-0}" == 1 && $changed == 1 ]]; then
  die "String Catalogs are out of date; run scripts/sync-strings.sh (make strings) and commit the result"
fi
log "String Catalogs are in sync"
