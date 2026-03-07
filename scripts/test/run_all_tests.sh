#!/bin/sh
# Test runner script
# Executes all unit tests and integration tests

# Ensure paths resolve regardless of caller CWD
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi

cd "${SCRIPT_DIR}" || exit 1

# Source test helper for colorful output
# shellcheck source=test_helper.sh
. "${SCRIPT_DIR%/}/test_helper.sh"

shtracer_test_result 0 "Running all tests for shtracer"
echo ""

# Track overall test result
OVERALL_EXIT_CODE=0

# Run unit tests
shtracer_test_section_header "Running Unit Tests"
for test_file in ./unit_test/*_unittest.sh; do
	if [ -f "$test_file" ] && [ -x "$test_file" ]; then
		sh -c "$test_file"
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			OVERALL_EXIT_CODE=$EXIT_CODE
		fi
	fi
done

echo ""

# Run JavaScript unit tests (if Node.js 18+ is available)
shtracer_test_section_header "Running JavaScript Unit Tests"
if [ -f "./unit_test/run_js_tests.sh" ]; then
	sh "./unit_test/run_js_tests.sh"
	EXIT_CODE=$?
	if [ $EXIT_CODE -ne 0 ]; then
		OVERALL_EXIT_CODE=$EXIT_CODE
	fi
fi

echo ""

# Run integration tests
shtracer_test_section_header "Running Integration Tests"
for test_file in ./integration_test/*.sh; do
	if [ -f "$test_file" ] && [ -x "$test_file" ]; then
		sh -c "$test_file"
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			OVERALL_EXIT_CODE=$EXIT_CODE
		fi
	fi
done

echo ""
if [ $OVERALL_EXIT_CODE -eq 0 ]; then
	shtracer_test_result 0 "All tests completed successfully"
else
	shtracer_test_result 1 "Some tests failed (exit code: $OVERALL_EXIT_CODE)"
fi

exit $OVERALL_EXIT_CODE
