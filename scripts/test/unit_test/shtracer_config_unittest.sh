#!/bin/sh
# Unit tests for config parsing functions
# Tests shtracer_config.sh: _check_config_remove_comments,
#   _check_config_convert_to_table, _check_config_validate, check_configfile

# Source test target
SCRIPT_DIR=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P
)
if [ -z "$SCRIPT_DIR" ]; then
	SCRIPT_DIR=$(
		unset CDPATH
		cd -- "$(dirname -- "$(basename -- "$0")")" 2>/dev/null && pwd -P
	)
fi

TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"
# shellcheck source=../../main/shtracer_config.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_config.sh"
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (Config Functions)"
}

setUp() {
	set +u
	SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_SEPARATOR
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export EXIT_CONFIG_INVALID=3
	export OUTPUT_DIR="${TEST_ROOT%/}/shtracer_output/"
	export CONFIG_DIR="${TEST_ROOT%/}/unit_test/testdata/"
	SCRIPT_DIR="$SHTRACER_ROOT_DIR"
	rm -rf "$OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"
	cd "${TEST_ROOT}" || exit 1
}

tearDown() {
	rm -rf "$OUTPUT_DIR"
}

# ============================================================================
# _check_config_remove_comments tests
# ============================================================================

test_remove_comments_basic() {
	_result=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
	# Should contain heading and PATH
	echo "$_result" | grep -q "Requirement" || fail "Should contain heading"
	echo "$_result" | grep -q "PATH" || fail "Should contain PATH field"
}

test_remove_comments_strips_html_comments() {
	# config_minimal_single_file.md has <!-- --> comments
	# Note: TAG LINE FORMAT contains `<!--.*-->` inside backticks, which is preserved
	_result=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
	# Only the backtick-protected <!--.*--> should remain (1 match)
	_comment_count=$(echo "$_result" | grep -c '<!--' || true)
	assertEquals "Only backtick-protected comment should remain" "1" "$_comment_count"
}

test_remove_comments_strips_bold_markers() {
	_result=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
	_bold_count=$(echo "$_result" | grep -c '\*\*' || true)
	assertEquals "Bold markers should be removed" "0" "$_bold_count"
}

test_remove_comments_strips_bullet_points() {
	_result=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
	_bullet_count=$(echo "$_result" | grep -c '^\* ' || true)
	assertEquals "Bullet points should be removed" "0" "$_bullet_count"
}

test_remove_comments_empty_config() {
	_result=$(_check_config_remove_comments "./unit_test/testdata/config_empty.md")
	# Should have only the heading, no fields
	_path_count=$(echo "$_result" | grep -c "^PATH" || true)
	assertEquals "Empty config should have no PATH fields" "0" "$_path_count"
}

# ============================================================================
# _check_config_convert_to_table tests
# ============================================================================

test_convert_to_table_basic() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
		_table_file="${OUTPUT_DIR%/}/test_table"
		_check_config_convert_to_table "$_content" "$_table_file"

		assertTrue "Table file should be created" "[ -f '$_table_file' ]"
		assertTrue "Table file should not be empty" "[ -s '$_table_file' ]"
	)
}

test_convert_to_table_fields() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
		_table_file="${OUTPUT_DIR%/}/test_table_fields"
		_check_config_convert_to_table "$_content" "$_table_file"

		# Table should contain the PATH value
		grep -q "requirements_minimal.md" "$_table_file" || fail "Table should contain PATH value"
		# Table should contain TAG FORMAT
		grep -q "TD" "$_table_file" || fail "Table should contain tag format"
	)
}

test_convert_to_table_matches_expected() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_minimal_single_file.md")
		_table_file="${OUTPUT_DIR%/}/test_table_expected"
		_check_config_convert_to_table "$_content" "$_table_file"

		_expected="$(cat ./unit_test/testdata/expected/config/config_table)"
		_actual="$(cat "$_table_file")"
		assertEquals "$_expected" "$_actual"
	)
}

test_convert_to_table_unknown_field_warns() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_unknown_field.md")
		_table_file="${OUTPUT_DIR%/}/test_table_unknown"
		_stderr=$(_check_config_convert_to_table "$_content" "$_table_file" 2>&1 1>/dev/null)

		echo "$_stderr" | grep -q "Unknown field" || fail "Should warn about unknown field"
	)
}

# ============================================================================
# _check_config_validate tests
# ============================================================================

test_validate_valid_config() {
	(
		_table_file="./unit_test/testdata/expected/config/config_table"
		# Should not exit with error
		_check_config_validate "$_table_file"
		assertEquals "Valid config should pass validation" 0 $?
	)
}

test_validate_empty_table_exits() {
	(
		_table_file="${OUTPUT_DIR%/}/empty_table"
		: >"$_table_file"
		_result=$(_check_config_validate "$_table_file" 2>&1 || true)
		echo "$_result" | grep -q "empty" || fail "Should report empty config"
	)
}

test_validate_missing_path_exits() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_missing_path.md")
		_table_file="${OUTPUT_DIR%/}/test_missing_path"
		_check_config_convert_to_table "$_content" "$_table_file"
		_result=$(_check_config_validate "$_table_file" 2>&1 || true)
		echo "$_result" | grep -q "missing required field PATH\|PATH" || fail "Should report missing PATH"
	)
}

test_validate_missing_tag_format_warns() {
	(
		_content=$(_check_config_remove_comments "./unit_test/testdata/config_missing_tag_format.md")
		_table_file="${OUTPUT_DIR%/}/test_missing_tag"
		_check_config_convert_to_table "$_content" "$_table_file"
		_stderr=$(_check_config_validate "$_table_file" 2>&1 1>/dev/null)
		echo "$_stderr" | grep -q "TAG FORMAT\|no TAG FORMAT" || fail "Should warn about missing TAG FORMAT"
	)
}

# ============================================================================
# check_configfile (integration of all three stages)
# ============================================================================

test_check_configfile_creates_output_dir() {
	(
		_result="$(check_configfile "./unit_test/testdata/config_minimal_single_file.md")"
		assertTrue "Config output directory should exist" "[ -d '${OUTPUT_DIR%/}/config/' ]"
	)
}

test_check_configfile_returns_table_path() {
	(
		_result="$(check_configfile "./unit_test/testdata/config_minimal_single_file.md")"
		assertEquals "01_config_table" "${_result##*/}"
	)
}

test_check_configfile_output_matches_expected() {
	(
		_result="$(check_configfile "./unit_test/testdata/config_minimal_single_file.md")"
		_expected="$(cat ./unit_test/testdata/expected/config/config_table)"
		_actual="$(cat "$_result")"
		assertEquals "$_expected" "$_actual"
	)
}

test_check_configfile_empty_config_fails() {
	# check_configfile calls error_exit which exits the subshell
	# Capture both stdout and stderr, expect non-zero exit
	_result="$(check_configfile "./unit_test/testdata/config_empty.md" 2>&1)"
	_exit=$?
	assertNotEquals "Empty config should fail" 0 "$_exit"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
