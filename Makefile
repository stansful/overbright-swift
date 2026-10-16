# Thin wrapper around scripts/ (ARCHITECTURE.md §8.7). All targets work when xcode-select points at the Command Line
# Tools: the scripts locate /Applications/Xcode*.app themselves (scripts/lib.sh ensure_xcode). Run each command on its
# own: on some shells `a && b` chains abort silently (docs/CONTRIBUTING.md).
SHELL := /bin/bash

.PHONY: help build debug run smoke qa-matrix soak dist check test tsan lint strings strings-check copy-check l10n-check l10n-pending probe probe-check icon list clean distclean

help:            ## Show this help
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-14s %s\n", $$1, $$2}'

build:           ## Release build, universal -> build/Overbright.app (+ dSYM); CONTROLS=1 keeps the Controls extension
	@scripts/build.sh

debug:           ## Debug build (host arch) -> build/Overbright.app
	@CONFIGURATION=Debug ARCHS="$$(uname -m)" scripts/build.sh

run:             ## Debug build + launch with --off --qa-simulate (never boosts); scripts/run.sh -- <args> overrides
	@scripts/run.sh

smoke:           ## Run build/Overbright.app --diagnostics: bundles, Edit menu, privacy none, intents, nothing written
	@scripts/smoke.sh

qa-matrix:       ## Debug app under --qa-simulate: every fixture's scenario, symbol/banner/chips checked (after make debug)
	@scripts/qa-matrix.sh

soak:            ## Debug app under --qa-simulate for MINUTES (30): footprint, idle wake-ups while off vs a control (after make debug)
	@scripts/soak.sh

dist: build      ## zip + dmg + sha256 (+ notarization with SIGN_IDENTITY/TEAM_ID/NOTARY_PROFILE) -> dist/
	@scripts/dist.sh

check:           ## Build every OverbrightKit target on its own, zero warnings (JOBS=4 parallel; TEST=1 adds swift test)
	@scripts/check-modules.sh

test:            ## swift test for OverbrightKit (FILTER=<Suite or Target> narrows it)
	@. scripts/lib.sh && ensure_xcode && cd "$$PACKAGE_DIR" && \
	  swift test "$${SWIFTPM_FLAGS[@]}" --scratch-path .build-test $(if $(FILTER),--filter '$(FILTER)')

tsan:            ## swift test under the Thread Sanitizer (FILTER=HangWatchdogTests; CI runs it)
	@. scripts/lib.sh && ensure_xcode && cd "$$PACKAGE_DIR" && \
	  swift test "$${SWIFTPM_FLAGS[@]}" --sanitize=thread --scratch-path .build-tsan $(if $(FILTER),--filter '$(FILTER)')

lint:            ## Copy rules, competitor denylist (catalogs + sources) and no Metal shader sources (D22)
	@/usr/bin/python3 -I scripts/lint-copy.py
	@shaders="$$(find Packages App Controls Shared -name '*.metal' -not -path '*/.build*' 2>/dev/null)"; \
	  if [[ -n "$$shaders" ]]; then echo "error: Metal shader sources are not allowed (ARCHITECTURE.md D22):"; echo "$$shaders"; exit 1; fi; \
	  echo "No Metal shader sources"

strings:         ## Sync the package's String Catalogs with the keys used in code
	@scripts/sync-strings.sh

strings-check:   ## Fail if String Catalogs are out of date, break the copy rules or miss a shipped language (CI)
	@CHECK=1 scripts/sync-strings.sh
	@/usr/bin/python3 -I scripts/lint-copy.py
	@/usr/bin/python3 -I scripts/l10n/validate.py --shipped

copy-check:      ## Copy rules of every String Catalog, per language, and the source scan (no build; part of lint)
	@/usr/bin/python3 -I scripts/lint-copy.py

l10n-check:      ## Shipped languages complete + valid: scripts/l10n/validate.py --shipped (no build; part of strings-check)
	@/usr/bin/python3 -I scripts/l10n/validate.py --shipped

l10n-pending:    ## Mark new English strings pending translation in every shipped language (scripts/l10n/README.md)
	@/usr/bin/python3 -I scripts/l10n/pending.py

probe:           ## Regenerate the SDK name-collision probes after adding public Core or Policy types
	@scripts/name-probe.sh

probe-check:     ## Fail if an SDK name-collision probe is out of date (CI)
	@CHECK=1 scripts/name-probe.sh

icon:            ## Re-render the App/AppIcon.icon layers (scripts/render-icon.swift)
	@. scripts/lib.sh && ensure_xcode && xcrun swift scripts/render-icon.swift App/AppIcon.icon/Assets

list:            ## xcodebuild -list
	@. scripts/lib.sh && ensure_xcode && xcodebuild -list -project Overbright.xcodeproj

clean:           ## Remove build outputs (after unregistering them from LaunchServices and PlugInKit)
	@. scripts/lib.sh && unregister_app build/Overbright.app build/DerivedData/Build/Products/*/Overbright.app
	rm -rf build dist

distclean: clean ## Also remove every SwiftPM scratch dir (.build-*; a worktree can hold several GB)
	rm -rf Packages/OverbrightKit/.build Packages/OverbrightKit/.build-* Packages/OverbrightKit/.swiftpm
