#!/bin/sh
# Run JavaScript unit tests for traceability_diagrams.js
# Gracefully skips if Node.js is unavailable (e.g., MSYS2, Git for Windows)

# Resolve script directory
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi

# Source test helper for consistent header/result formatting
TEST_ROOT=$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)
SHTRACER_ROOT_DIR=$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

# Check Node.js availability
if ! command -v node >/dev/null 2>&1; then
	echo "[SKIP] Node.js not found, skipping JS unit tests" >&2
	exit 0
fi

# Check Node.js version (need v18+ for built-in test runner)
NODE_MAJOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if [ "$NODE_MAJOR" -lt 18 ] 2>/dev/null; then
	echo "[SKIP] Node.js 18+ required (found v${NODE_MAJOR}), skipping JS unit tests" >&2
	exit 0
fi

shtracer_test_header "UNIT TEST (JavaScript Diagrams)"

# Run with TAP reporter (available since Node 18.9 / LTS 18.12) so output is
# predictable and can be reformatted to match the shunit2 style used by other
# test suites in this project.
_tmp=$(mktemp 2>/dev/null || mktemp -t 'shtracer_test')
node --test --test-reporter=tap \
	"${SCRIPT_DIR}/traceability_diagrams_unittest.mjs" >"$_tmp" 2>&1
_node_exit=$?

if grep -q "^TAP version" "$_tmp" 2>/dev/null; then
	# Transform TAP output: print individual test names then "Ran N tests."
	# Individual tests appear as "    ok N - name" (4-space indent inside suites).
	# Top-level suite lines "ok N - suiteName" (no indent) are suppressed.
	# Diagnostic line "# tests N" carries the total count.
	awk '
		/^    ok [0-9]+ - / {
			sub(/^    ok [0-9]+ - /, "")
			print
		}
		/^    not ok [0-9]+ - / {
			sub(/^    not ok [0-9]+ - /, "")
			print
		}
		/^# tests [0-9]/ { tests = $3 + 0 }
		END { printf "\nRan %d tests.\n", tests }
	' "$_tmp"
else
	# Fallback for Node < 18.9: print raw output as-is
	cat "$_tmp"
fi
rm -f "$_tmp"

if [ "$_node_exit" -eq 0 ]; then
	printf '\n\033[1;32mOK\033[0m\n'
else
	printf '\n\033[1;31mFAILED\033[0m\n'
fi

exit "$_node_exit"
