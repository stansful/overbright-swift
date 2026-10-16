#!/usr/bin/env bash
# Debug build (host arch) + launch. ARCHITECTURE.md §8.5, §8.7, D24.
#
#   scripts/run.sh                      # build, quit the old dev instance, open the new one with the safe defaults
#   scripts/run.sh --no-build           # just relaunch
#   scripts/run.sh -- --qa-panel …      # pass these arguments instead of the safe defaults
#   XOJIT=1 scripts/run.sh              # keep Xcode-style Debug (XOJIT previews => hardened runtime OFF)
#   DEV_SIGN_IDENTITY="Overbright Dev" scripts/run.sh   # a stable code identity (login-item approval survives rebuilds)
#   CONTROLS=1 scripts/run.sh           # keep the dormant Control Center extension in the dev build
#
# Without arguments the app starts with `--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite
# app.overbright.Overbright.dev`: the master switch is off, every display port and EDR surface is a fake, and the
# user's own preferences are untouched, so a plain `make run` never changes the display state (D24). Agents always
# use --qa-simulate; only the owner's hardware session runs without it
# (`scripts/run.sh -- --qa-defaults-suite app.overbright.Overbright.hw`, with the installed copy quit).
#
# Launches through LaunchServices (`open`): Overbright asks for no TCC permission, but activation, the single-instance
# check and attribution behave as for a user launch only then.
source "$(dirname "$0")/lib.sh"

build=1
app_args=(--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite app.overbright.Overbright.dev)
while (($#)); do
  case "$1" in
    --no-build) build=0 ;;
    --) shift; app_args=("$@"); break ;;
    *) die "unknown option $1" ;;
  esac
  shift
done

APP="$DERIVED_DIR/Build/Products/Debug/$APP_NAME.app"
if (( build )); then
  ensure_xcode
  overrides=()
  # With ad-hoc signing, Xcode prints "Disabling hardened runtime with ad-hoc codesigning"
  # for Debug builds while ENABLE_XOJIT_PREVIEWS=YES (the Debug default). Turn it off for CLI
  # runs so the dev build behaves like Release (library validation, hardened runtime).
  [[ "${XOJIT:-0}" == 1 ]] || overrides+=(ENABLE_XOJIT_PREVIEWS=NO)
  # A stable code identity keeps the login-item approval across rebuilds:
  #   DEV_SIGN_IDENTITY="Overbright Dev" scripts/run.sh   (a self-signed Code Signing certificate in your login keychain)
  [[ -z "${DEV_SIGN_IDENTITY:-}" ]] || overrides+=(CODE_SIGN_IDENTITY="$DEV_SIGN_IDENTITY")
  log "Building Debug"
  mkdir -p "$BUILD_DIR/logs"
  set +e
  xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED_DIR" \
    ${overrides[@]+"${overrides[@]}"} 2>&1 | tee "$BUILD_DIR/logs/build-Debug.log" | xcpretty_filter
  status=${PIPESTATUS[0]}
  set -e
  (( status == 0 )) || die "xcodebuild failed; see $BUILD_DIR/logs/build-Debug.log"
  # The dev copy must not offer its control to Control Center unless asked to (F1 risk 5).
  controls_enabled || SIGN_IDENTITY="${DEV_SIGN_IDENTITY:-}" drop_controls_extension "$APP"
fi
[[ -d "$APP" ]] || die "$APP not found; run without --no-build first"

# Quit only *this* build's instance (other Overbright copies, e.g. in /Applications, are left alone).
if pgrep -f "$APP/Contents/MacOS/$APP_NAME" >/dev/null; then
  log "Quitting running dev instance"
  pkill -f "$APP/Contents/MacOS/$APP_NAME" || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "$APP/Contents/MacOS/$APP_NAME" >/dev/null || break; sleep 0.3; done
fi

log "Launching $APP ${app_args[*]+"${app_args[*]}"}"
open -n "$APP" --args ${app_args[@]+"${app_args[@]}"}
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if pid="$(pgrep -f "$APP/Contents/MacOS/$APP_NAME" | head -1)" && [[ -n "$pid" ]]; then
    log "Running (pid $pid). Logs: /usr/bin/log stream --level info --predicate 'subsystem == \"app.overbright.Overbright\"'"
    exit 0
  fi
  sleep 0.5
done
die "$APP_NAME did not start; check ~/Library/Logs/DiagnosticReports/$APP_NAME-*.ips"
