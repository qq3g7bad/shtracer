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
# shellcheck source=../../main/shtracer_awk_helpers.sh
_UTIL_SCRIPT_DIR="${SHTRACER_ROOT_DIR%/}/scripts/main"
export _UTIL_SCRIPT_DIR
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_awk_helpers.sh"
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

# ============================================================================
# make_json integration-style unit tests
# ============================================================================

##
# @brief Helper: build minimal intermediate files for make_json
# Creates 01_tags, 02_tag_pairs, 03_tag_pairs_downstream, 04_tag_table,
# 01_config_table, and verification files needed by make_json.
_setup_make_json_fixtures() {
	_fixture_dir="$1"
	_sep="$SHTRACER_SEPARATOR"

	# Create directory structure
	mkdir -p "${_fixture_dir}/tags/verified"
	mkdir -p "${_fixture_dir}/config"

	# Source files (used for file_path column in 01_tags)
	_req_file="${_fixture_dir}/req.md"
	_arc_file="${_fixture_dir}/arc.md"
	printf '<!-- @REQ1.1@ -->\n## Auth\n' >"$_req_file"
	printf '<!-- @ARC2.1@ (FROM: @REQ1.1@) -->\n## Auth Module\n' >"$_arc_file"

	# 01_tags (8 fields: trace_target, tag, from_tag, title, file, line, file_num, version)
	{
		printf ':Requirement%s@REQ1.1@%sNONE%sUser Authentication%s%s%s3%s1%sgit:abc1234\n' \
			"$_sep" "$_sep" "$_sep" "$_sep" "$_req_file" "$_sep" "$_sep" "$_sep"
		printf ':Architecture%s@ARC2.1@%s@REQ1.1@%sAuthentication Module%s%s%s3%s2%sgit:def5678\n' \
			"$_sep" "$_sep" "$_sep" "$_sep" "$_arc_file" "$_sep" "$_sep" "$_sep"
	} >"${_fixture_dir}/tags/01_tags"

	# 02_tag_pairs (space-separated: parent child)
	echo "@REQ1.1@ @ARC2.1@" >"${_fixture_dir}/tags/02_tag_pairs"

	# 03_tag_pairs_downstream (downstream pairs; same format)
	echo "@REQ1.1@ @ARC2.1@" >"${_fixture_dir}/tags/03_tag_pairs_downstream"

	# 04_tag_table (space-separated chains)
	echo "@REQ1.1@ @ARC2.1@" >"${_fixture_dir}/tags/04_tag_table"

	# 01_config_table (8 fields)
	{
		# shellcheck disable=SC2016
		printf ':Requirement%s"%s"%s%s%s"Requirements"%s`@REQ[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
			"$_sep" "$_req_file" "$_sep" "$_sep" "$_sep" "$_sep" "$_sep" "$_sep"
		# shellcheck disable=SC2016
		printf ':Architecture%s"%s"%s%s%s"Architecture"%s`@ARC[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
			"$_sep" "$_arc_file" "$_sep" "$_sep" "$_sep" "$_sep" "$_sep" "$_sep"
	} >"${_fixture_dir}/config/01_config_table"

	# Verification files (empty = no issues)
	: >"${_fixture_dir}/tags/verified/10_isolated_fromtag"
	: >"${_fixture_dir}/tags/verified/11_duplicated"
	: >"${_fixture_dir}/tags/verified/12_dangling_fromtag"
}

##
# @brief Test make_json produces valid JSON with all required top-level keys
test_make_json_top_level_keys() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config_integration.md" \
			"")

		assertTrue "JSON output file should exist" "[ -f '$_json_file' ]"

		# Check all required top-level keys
		for _key in metadata verificationErrors files layers trace_tags chains health; do
			grep -q "\"$_key\"" "$_json_file" \
				|| fail "JSON should contain top-level key: $_key"
		done
	)
}

##
# @brief Test make_json metadata contains version
test_make_json_metadata_version() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		grep -q '"version": "0.1.5"' "$_json_file" \
			|| fail "JSON metadata should contain version 0.1.5"
	)
}

##
# @brief Test make_json files array contains expected entries
test_make_json_files_array() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		# Should have file_id entries
		grep -q '"file_id"' "$_json_file" \
			|| fail "JSON files array should contain file_id entries"

		# Should reference the req and arc files
		grep -q 'req.md' "$_json_file" \
			|| fail "JSON files should reference req.md"
		grep -q 'arc.md' "$_json_file" \
			|| fail "JSON files should reference arc.md"
	)
}

##
# @brief Test make_json layers array lists correct layers
test_make_json_layers_array() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		grep -q '"Requirement"' "$_json_file" \
			|| fail "JSON layers should contain Requirement"
		grep -q '"Architecture"' "$_json_file" \
			|| fail "JSON layers should contain Architecture"
	)
}

##
# @brief Test make_json trace_tags contains expected tag IDs
test_make_json_trace_tags() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		grep -q '"id": "@REQ1.1@"' "$_json_file" \
			|| fail "JSON trace_tags should contain @REQ1.1@"
		grep -q '"id": "@ARC2.1@"' "$_json_file" \
			|| fail "JSON trace_tags should contain @ARC2.1@"

		# ARC2.1 should have from_tags referencing REQ1.1
		grep -q '"from_tags": \["@REQ1.1@"\]' "$_json_file" \
			|| fail "ARC2.1 should have from_tags containing @REQ1.1@"
	)
}

##
# @brief Test make_json chains contains expected chain
test_make_json_chains() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		# Chain should contain REQ1.1 -> ARC2.1
		grep -q '"@REQ1.1@"' "$_json_file" \
			|| fail "Chain should contain @REQ1.1@"
		grep -q '"@ARC2.1@"' "$_json_file" \
			|| fail "Chain should contain @ARC2.1@"
	)
}

##
# @brief Test make_json verificationErrors is empty when no issues
test_make_json_verification_no_errors() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		# isolated and duplicates arrays should be empty
		grep -q '"isolated": \[\]' "$_json_file" \
			|| grep -q '"isolated": \[' "$_json_file" \
			|| fail "verificationErrors should have isolated array"
	)
}

##
# @brief Test make_json health section exists
test_make_json_health_section() {
	(
		OUTPUT_DIR="$TEMP_DIR/"
		export OUTPUT_DIR
		SHTRACER_VERSION="0.1.5"
		export SHTRACER_VERSION

		_setup_make_json_fixtures "$TEMP_DIR"

		_json_file=$(make_json \
			"$TEMP_DIR/tags/01_tags" \
			"$TEMP_DIR/tags/02_tag_pairs" \
			"$TEMP_DIR/tags/03_tag_pairs_downstream" \
			"$TEMP_DIR/tags/04_tag_table" \
			"$TEMP_DIR/config/01_config_table" \
			"$TEMP_DIR/config.md" \
			"")

		grep -q '"health"' "$_json_file" \
			|| fail "JSON should contain health section"
		grep -q '"total_tags"' "$_json_file" \
			|| fail "Health should contain total_tags"
	)
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
