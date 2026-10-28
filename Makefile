# Thin wrapper around scripts/ (ARCHITECTURE.md §8.7). All targets work when xcode-select points at the Command Line
# Tools: the scripts locate /Applications/Xcode*.app themselves (scripts/lib/lib.sh ensure_xcode). Run each command on
# its own: on some shells `a && b` chains abort silently (docs/CONTRIBUTING.md).
SHELL := /bin/bash

.PHONY: help build debug run smoke qa-matrix soak perf perf-compare dist release release-build release-test check test tsan lint strings strings-check copy-check l10n-check l10n-pending probe probe-check icon list clean distclean

help:            ## Show this help
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-14s %s\n", $$1, $$2}'

build:           ## Release build, universal -> build/Overbright.app (+ dSYM); CONTROLS=1 keeps the Controls extension
	@scripts/lib/build.sh

debug:           ## Debug build (host arch) -> build/Overbright.app
	@CONFIGURATION=Debug ARCHS="$$(uname -m)" scripts/lib/build.sh

run:             ## Debug build + launch with --off --qa-simulate (never boosts); scripts/lib/run.sh -- <args> overrides
	@scripts/lib/run.sh

smoke:           ## Run build/Overbright.app --diagnostics: bundles + translations, Edit menu, privacy none, intents, nothing written
	@scripts/lib/smoke.sh

qa-matrix:       ## Debug app under --qa-simulate: every fixture's scenario, symbol/banner/chips checked; Welcome writes nothing (after make debug)
	@scripts/lib/qa-matrix.sh

soak:            ## Debug app under --qa-simulate for MINUTES (30, at least 17): footprint growth per cycle and after the panel; own interrupt wake-ups neither periodic nor above 0.05/s while off; the app's domain unchanged (after make debug)
	@scripts/lib/soak.sh

perf:            ## Energy phases of a Debug app under --qa-simulate -> build/logs/perf/<variant>/ (RUNS="ui events", APP=, VARIANT=; after make debug)
	@APP="$(APP)" VARIANT="$(VARIANT)" scripts/lib/perf.sh $(RUNS)

perf-compare:    ## Per phase: own CPU, own wake-ups, footprint, busy split and §17 verdicts of two perf folders (A=<dir> B=<dir>)
	@if [[ -z "$(A)" || -z "$(B)" ]]; then echo "usage: make perf-compare A=build/logs/perf/<a> B=build/logs/perf/<b>"; exit 2; fi
	@scripts/lib/perf.sh compare "$(A)" "$(B)"

dist: build      ## zip + dmg + sha256 (+ notarization with SIGN_IDENTITY/TEAM_ID/NOTARY_PROFILE) -> dist/
	@scripts/lib/dist.sh

release:         ## Next version (asks; V=X.Y.Z|patch|minor|major skips that) into VERSION and the project, committed; never pushes
	@scripts/make-release.sh $(V)

release-build:   ## The release files as release.yml builds them -> dist/ (scripts/build-release.sh; ARGS="--test --out DIR")
	@scripts/build-release.sh $(ARGS)

release-test:    ## Tests of the release scripts (scripts/tests/run.sh; throwaway repositories, no build)
	@scripts/tests/run.sh

check:           ## Build every OverbrightKit target on its own, zero warnings (JOBS=4 parallel; TEST=1 adds swift test)
	@scripts/lib/check-modules.sh

test:            ## swift test for OverbrightKit (FILTER=<Suite or Target> narrows it)
	@. scripts/lib/lib.sh && ensure_xcode && cd "$$PACKAGE_DIR" && \
	  swift test "$${SWIFTPM_FLAGS[@]}" --scratch-path .build-test $(if $(FILTER),--filter '$(FILTER)')

tsan:            ## swift test under the Thread Sanitizer (CI: FILTER='HangWatchdog|OffMain|GammaWriteGate|StatusSymbolTests')
	@. scripts/lib/lib.sh && ensure_xcode && cd "$$PACKAGE_DIR" && \
	  swift test "$${SWIFTPM_FLAGS[@]}" --sanitize=thread --scratch-path .build-tsan $(if $(FILTER),--filter '$(FILTER)')

lint:            ## Copy rules, competitor denylist (catalogs + every repository file), no Metal shader sources (D22), script syntax and self-tests
	@/usr/bin/python3 -I scripts/lib/lint-copy.py
	@shaders="$$(find Packages App Controls Shared -name '*.metal' -not -path '*/.build*' 2>/dev/null)"; \
	  if [[ -n "$$shaders" ]]; then echo "error: Metal shader sources are not allowed (ARCHITECTURE.md D22):"; echo "$$shaders"; exit 1; fi; \
	  echo "No Metal shader sources"
	@/usr/bin/python3 -I scripts/lib/check-lproj.py --self-test
	@/usr/bin/python3 -I scripts/lib/l10n/validate.py --self-test
	@/usr/bin/python3 -I scripts/lib/soak_judge.py --self-test
	@for script in scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh .github/scripts/*.sh; do \
	  /bin/bash -n "$$script" || exit 1; done; echo "Shell scripts parse (bash -n)"

strings:         ## Sync the package's String Catalogs with the keys used in code
	@scripts/lib/sync-strings.sh

strings-check:   ## Fail if String Catalogs are out of date, break the copy rules or miss a shipped language (CI)
	@CHECK=1 scripts/lib/sync-strings.sh
	@/usr/bin/python3 -I scripts/lib/lint-copy.py
	@/usr/bin/python3 -I scripts/lib/l10n/validate.py --shipped

copy-check:      ## Copy rules of every String Catalog, per language, and the source scan (no build; part of lint)
	@/usr/bin/python3 -I scripts/lib/lint-copy.py

l10n-check:      ## Shipped languages complete + valid: scripts/lib/l10n/validate.py --shipped (no build; part of strings-check)
	@/usr/bin/python3 -I scripts/lib/l10n/validate.py --shipped

l10n-pending:    ## Mark new English strings pending translation in every shipped language (scripts/lib/l10n/README.md)
	@/usr/bin/python3 -I scripts/lib/l10n/pending.py

probe:           ## Regenerate the SDK name-collision probes after adding public Core or Policy types
	@scripts/lib/name-probe.sh

probe-check:     ## Fail if an SDK name-collision probe is out of date (CI)
	@CHECK=1 scripts/lib/name-probe.sh

icon:            ## Re-render the App/AppIcon.icon layers (scripts/lib/render-icon.swift)
	@. scripts/lib/lib.sh && ensure_xcode && xcrun swift scripts/lib/render-icon.swift App/AppIcon.icon/Assets

list:            ## xcodebuild -list
	@. scripts/lib/lib.sh && ensure_xcode && xcodebuild -list -project Overbright.xcodeproj

clean:           ## Remove build outputs (after unregistering them from LaunchServices and PlugInKit)
	@. scripts/lib/lib.sh && unregister_app build/Overbright.app build/DerivedData/Build/Products/*/Overbright.app
	rm -rf build dist

distclean: clean ## Also remove every SwiftPM scratch dir (.build-*; a worktree can hold several GB)
	rm -rf Packages/OverbrightKit/.build Packages/OverbrightKit/.build-* Packages/OverbrightKit/.swiftpm
