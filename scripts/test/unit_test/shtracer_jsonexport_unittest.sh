#!/bin/sh
# Unit tests for JSON export helper functions (shtracer_json_export.sh)

# Source test target
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi

# shunit2 needs a readable path to this test file
SHUNIT_PARENT="${SCRIPT_DIR%/}/$(basename -- "$0")"
export SHUNIT_PARENT

TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"
# shellcheck source=../../main/shtracer_config.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_config.sh"
# shellcheck source=../../main/shtracer_extract.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_extract.sh"
# shellcheck source=../../main/shtracer_verify.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_verify.sh"
# shellcheck source=../../main/shtracer_json_export.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_json_export.sh"
# shellcheck source=../../main/shtracer_crossref.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_crossref.sh"
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

##
# @brief
#
oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (JSON Emit Functions)"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	export SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export NODATA_STRING="NONE"
	TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'shtracer_test')"
	export TEMP_DIR
}

##
# @brief TearDown function for each test
#
tearDown() {
	if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
		rm -rf "$TEMP_DIR"
	fi
}

# ============================================================================
# _json_emit_metadata tests
# ============================================================================

##
# @brief Test _json_emit_metadata produces correct JSON structure
# @tag @UT2.6.3@ (FROM: @IMP2.6.3@)
test_json_emit_metadata_structure() {
	result=$(_json_emit_metadata "0.2.0" "2026-01-15T10:30:00Z" "/path/to/config.md")
	# Should start with {
	first_line=$(printf '%s\n' "$result" | head -1)
	assertEquals "{" "$first_line"
	# Should contain version
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"version": "0.2.0"')"
	# Should contain generated
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"generated": "2026-01-15T10:30:00Z"')"
	# Should contain config_path
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"config_path": "/path/to/config.md"')"
}

##
# @brief Test _json_emit_metadata ends with trailing comma for concatenation
test_json_emit_metadata_trailing_comma() {
	result=$(_json_emit_metadata "1.0" "2026-01-01T00:00:00Z" "/cfg.md")
	last_line=$(printf '%s\n' "$result" | tail -1)
	# Last line should end with comma (for JSON concatenation)
	case "$last_line" in
		*,) assertTrue "Last line ends with comma" true ;;
		*) fail "Last line should end with comma, got: $last_line" ;;
	esac
}

# ============================================================================
# _json_emit_chains tests
# ============================================================================

##
# @brief Test _json_emit_chains with single chain
# @tag @UT2.6.4@ (FROM: @IMP2.6.4@)
test_json_emit_chains_single() {
	# Create tag table with one chain
	printf '@REQ1@\t@ARC1@\tNONE\n' >"$TEMP_DIR/tag_table"

	result=$(_json_emit_chains "$TEMP_DIR/tag_table")
	# Should contain chains key
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"chains"')"
	# Should contain the chain array
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"@REQ1@"')"
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"@ARC1@"')"
}

##
# @brief Test _json_emit_chains with multiple chains
test_json_emit_chains_multiple() {
	printf '@REQ1@\t@ARC1@\tNONE\n@REQ2@\tNONE\tNONE\n' >"$TEMP_DIR/tag_table"

	result=$(_json_emit_chains "$TEMP_DIR/tag_table")
	# Should have two chain entries
	chain_count=$(printf '%s\n' "$result" | grep -c '\[.*"@')
	assertEquals "2" "$chain_count"
}

##
# @brief Test _json_emit_chains with empty table
test_json_emit_chains_empty() {
	: >"$TEMP_DIR/tag_table"

	result=$(_json_emit_chains "$TEMP_DIR/tag_table")
	# Should still produce valid chains wrapper
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '"chains"')"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
