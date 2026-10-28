#!/usr/bin/env bash
# Runs the tests of the release scripts (scripts/tests/*_test.sh): scripts/lib/version.sh, scripts/make-release.sh,
# scripts/build-release.sh (in a fake tree with stubs: nothing is built), .github/scripts/release-state.sh and
# release-notes.sh, in throwaway directories in TMPDIR, and the static checks that these scripts, the workflows and
# the Makefile agree (workflows_test.sh). Never builds or launches the app, never writes into this repository.
# Needs bash 3.2+ and git; TEST_BASH=<bash> runs the tests and the scripts under that bash (macOS: /bin/bash is 3.2),
# KEEP=1 keeps the temp dirs.
#
#   scripts/tests/run.sh          (make release-test)
#
# Prints '# <test file>' before the results of each and, when one fails, '# failed: <test files>' last; exits
# non-zero then.
set -u
# SIGPIPE ignored, as on the GitHub runner (every step inherits that from its Node.js), for these tests and the
# scripts they run: a reader that stops early makes its writer fail with "Broken pipe" there instead of dying quietly
trap "" PIPE

HERE="$(cd "$(dirname "$0")" && pwd -P)"
failed=''
for t in "$HERE"/*_test.sh; do
  # without a match the pattern stays as it is: no tests is a failure, not a pass
  if [ ! -f "$t" ]; then
    echo "not ok no tests in $HERE"
    exit 1
  fi
  echo "# ${t##*/}"
  "${TEST_BASH:-bash}" "$t" || failed="$failed ${t##*/}"
done
if [ -n "$failed" ]; then
  echo "# failed:$failed"
  exit 1
fi
