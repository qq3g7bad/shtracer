#!/bin/sh

# test_helper.sh - Common test infrastructure for shtracer unit tests
#
# This file provides shared setup functions for all shtracer test files.
# Source this file at the beginning of test scripts to get common utilities.
#
# Usage:
#   . "${SHTRACER_ROOT_DIR}/scripts/test/test_helper.sh"
#   shtracer_test_init "Test Suite Name"

# Prevent double-sourcing
if [ -n "${_SHTRACER_TEST_HELPER_LOADED:-}" ]; then
	return 0 2>/dev/null
fi
_SHTRACER_TEST_HELPER_LOADED=1

##
# @brief Detect script directory reliably across different shells
# @return Sets _TEST_SCRIPT_DIR variable
_detect_script_dir() {
	_TEST_SCRIPT_DIR=$(
		unset CDPATH
		cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P
	)
	if [ -z "$_TEST_SCRIPT_DIR" ]; then
		_TEST_SCRIPT_DIR=$(
			unset CDPATH
			cd -- "$(dirname -- "$(basename -- "$0")")" 2>/dev/null && pwd -P
		)
	fi
	if [ -z "$_TEST_SCRIPT_DIR" ]; then
		echo "[ERROR] Failed to determine script directory" >&2
		exit 1
	fi
}

##
# @brief Initialize test environment paths
# @details Sets TEST_ROOT and SHTRACER_ROOT_DIR based on script location
shtracer_test_init_paths() {
	_detect_script_dir

	# Set TEST_ROOT to scripts/test directory
	TEST_ROOT=${TEST_ROOT:-$(
		unset CDPATH
		cd -- "${_TEST_SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P
	)}
	export TEST_ROOT

	# Set SHTRACER_ROOT_DIR to repository root
	SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(
		unset CDPATH
		cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P
	)}
	export SHTRACER_ROOT_DIR

	cd "${TEST_ROOT}" || exit 1
}

##
# @brief Source common shtracer modules
# @param $@ : List of modules to source (util, func, html_viewer, markdown_viewer, awk_helpers, json_parser)
shtracer_test_source_modules() {
	for _module in "$@"; do
		case "$_module" in
			util)
				# shellcheck source=../main/shtracer_util.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"
				;;
			func)
				# shellcheck source=../main/shtracer_func.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_func.sh"
				;;
			html_viewer)
				export SHTRACER_SCRIPT_DIR="${SHTRACER_ROOT_DIR%/}/scripts/main"
				# shellcheck source=../main/shtracer_html_viewer.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_html_viewer.sh"
				;;
			markdown_viewer)
				# shellcheck source=../main/shtracer_markdown_viewer.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_markdown_viewer.sh"
				;;
			awk_helpers)
				# shellcheck source=../main/shtracer_awk_helpers.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_awk_helpers.sh"
				;;
			json_parser)
				# shellcheck source=../main/shtracer_json_parser.sh
				. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_json_parser.sh"
				;;
			*)
				echo "[WARNING] Unknown module: $_module" >&2
				;;
		esac
	done
}

##
# @brief Standard setUp function for shtracer tests
# @details Sets common environment variables
shtracer_test_setUp() {
	set +u
	SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_SEPARATOR
	export SHTRACER_IS_PROFILE_ENABLE="${SHTRACER_FALSE:-0}"
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="${TEST_ROOT%/}/shtracer_output/"
	export CONFIG_DIR="${TEST_ROOT%/}/unit_test/testdata/"
	export SCRIPT_DIR="$SHTRACER_ROOT_DIR"
	cd "${TEST_ROOT}" || exit 1
}

##
# @brief Standard tearDown function for shtracer tests
# @details Cleans up test artifacts
shtracer_test_tearDown() {
	rm -rf "${OUTPUT_DIR:-/nonexistent}" 2>/dev/null || true
}

##
# @brief Create a temporary directory for tests
# @return Prints temp directory path
shtracer_test_tmpdir() {
	mktemp -d 2>/dev/null || mktemp -d -t 'shtracer_test'
}

##
# @brief Create a temporary file for tests
# @return Prints temp file path
shtracer_test_tmpfile() {
	mktemp 2>/dev/null || mktemp -t 'shtracer_test'
}

##
# @brief Print test suite header
# @param $1 : Test suite name
shtracer_test_header() {
	_suite_name="${1:-Unit Tests}"
	echo "----------------------------------------"
	echo " $_suite_name : $0"
	echo "----------------------------------------"
}
