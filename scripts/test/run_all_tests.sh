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

echo "========================================"
echo " Running all tests for shtracer"
echo "========================================"
echo ""

# Track overall test result
OVERALL_EXIT_CODE=0

# Run unit tests
echo "----------------------------------------"
echo " Running Unit Tests"
echo "----------------------------------------"
for test_file in ./unit_test/*.sh; do
	if [ -f "$test_file" ] && [ -x "$test_file" ]; then
		sh -c "$test_file"
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			OVERALL_EXIT_CODE=$EXIT_CODE
		fi
	fi
done

echo ""

# Run integration tests
echo "----------------------------------------"
echo " Running Integration Tests"
echo "----------------------------------------"
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
echo "========================================"
if [ $OVERALL_EXIT_CODE -eq 0 ]; then
	echo " All tests completed successfully"
else
	echo " Some tests failed (exit code: $OVERALL_EXIT_CODE)"
fi
echo "========================================"

exit $OVERALL_EXIT_CODE
