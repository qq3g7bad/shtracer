#!/bin/sh

# Integration tests for shtracer
# Tests end-to-end functionality with real configuration and data

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SHTRACER_BIN="${SCRIPT_DIR}/../../shtracer"
TEST_DATA_DIR="${SCRIPT_DIR}/testdata/integration"
ANSWER_DIR="${SCRIPT_DIR}/testdata/answer/integration"

##
# @brief
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " INTEGRATION TEST : $0"
	echo "----------------------------------------"
}

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	cd "${TEST_DATA_DIR}" || exit 1
	# Clean up any previous output
	rm -rf output/
}

##
# @brief TearDown function for each test
#
tearDown() {
	# Clean up output after each test
	rm -rf "${TEST_DATA_DIR}/output/"
}

##
# @brief  Integration test for normal mode
# @tag    @IT1.1@ (FROM: @UT1.18@)
test_integration_normal_mode() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Act -------------
		"${SHTRACER_BIN}" ./config_integration.md >/dev/null 2>&1
		_EXIT_CODE=$?

		# Assert ----------
		assertEquals "Shtracer should exit successfully" 0 "${_EXIT_CODE}"

		# Check output files exist
		assertTrue "Config table should exist" "[ -f output/config/01_config_table ]"
		assertTrue "Tags file should exist" "[ -f output/tags/01_tags ]"
		assertTrue "Tag table should exist" "[ -f output/tags/04_tag_table ]"
		assertTrue "HTML output should exist" "[ -f output/output.html ]"
		assertTrue "JSON output should exist" "[ -f output/output.json ]"

		# Verify tag table content
		_TAG_TABLE=$(cat output/tags/04_tag_table)
		_EXPECTED=$(cat "${ANSWER_DIR}/tag_table_expected.txt")

		assertEquals "Tag table should match expected output" "${_EXPECTED}" "${_TAG_TABLE}"

		# Check HTML is valid (contains basic structure)
		grep -q "<!DOCTYPE html>" output/output.html
		assertEquals "HTML should have DOCTYPE" 0 $?

		grep -q "<table" output/output.html
		assertEquals "HTML should contain table" 0 $?

		# Check D3.js and Sankey elements
		grep -q "d3js.org" output/output.html
		assertEquals "HTML should include D3.js" 0 $?

		grep -q "sankey-diagram" output/output.html
		assertEquals "HTML should contain Sankey diagram container" 0 $?

		grep -q "sankey.js" output/output.html
		assertEquals "HTML should include sankey.js" 0 $?

		# Check JSON is valid
		python3 -m json.tool output/output.json >/dev/null 2>&1
		assertEquals "JSON should be valid" 0 $?
	)
}

##
# @brief  Integration test for verify mode
# @tag    @IT1.2@ (FROM: @UT1.18@)
test_integration_verify_mode() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Act -------------
		_OUTPUT=$("${SHTRACER_BIN}" ./config_integration.md -v 2>&1)
		_EXIT_CODE=$?

		# Assert ----------
		assertEquals "Verify mode should exit successfully with valid data" 0 "${_EXIT_CODE}"

		# HTML should NOT be generated in verify mode
		assertFalse "HTML should not exist in verify mode" "[ -f output/output.html ]"

		# Tag table should still be generated
		assertTrue "Tag table should exist in verify mode" "[ -f output/tags/04_tag_table ]"

		# Output should not contain pre-extra-script or post-extra-script messages
		echo "${_OUTPUT}" | grep -q "pre-extra-script"
		assertNotEquals "Output should not contain pre-extra-script in verify mode" 0 $?

		echo "${_OUTPUT}" | grep -q "post-extra-script"
		assertNotEquals "Output should not contain post-extra-script in verify mode" 0 $?
	)
}

##
# @brief  Integration test for change mode
# @tag    @IT1.3@ (FROM: @UT1.18@)
test_integration_change_mode() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Create a temporary copy of the test file
		cp req_sample.md req_sample_temp.md

		# Act -------------
		# Create a simple config that points to the temp file
		cat >config_temp.md <<'EOF'
# Temp Config

## Requirements

* **PATH**: "./req_sample_temp.md"
  * **BRIEF**: "Temporary requirements"
  * **TAG FORMAT**: `@REQ[0-9\.]+@`
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1
EOF

		"${SHTRACER_BIN}" ./config_temp.md -c "@REQ1.1@" "@REQ2.1@" >/dev/null 2>&1
		_EXIT_CODE=$?

		# Assert ----------
		assertEquals "Change mode should exit successfully" 0 "${_EXIT_CODE}"

		# Check that the tag was changed
		grep -q "@REQ2.1@" req_sample_temp.md
		assertEquals "Tag should be changed to @REQ2.1@" 0 $?

		grep -q "@REQ1.1@" req_sample_temp.md
		assertNotEquals "Original tag @REQ1.1@ should not exist" 0 $?

		# Clean up
		rm -f req_sample_temp.md config_temp.md
	)
}

##
# @brief  Integration test for multi-file traceability
# @tag    @IT1.4@ (FROM: @UT1.18@)
test_integration_multiple_files() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Act -------------
		"${SHTRACER_BIN}" ./config_integration.md >/dev/null 2>&1
		_EXIT_CODE=$?

		# Assert ----------
		assertEquals "Multi-file test should exit successfully" 0 "${_EXIT_CODE}"

		_TAG_TABLE=$(cat output/tags/04_tag_table)

		# Verify complete traceability chains exist
		echo "${_TAG_TABLE}" | grep -q "@REQ1.1@ @ARC1.1@ @IMP1.1@"
		assertEquals "Complete chain REQ->ARC->IMP should exist for requirement 1.1" 0 $?

		echo "${_TAG_TABLE}" | grep -q "@REQ1.2@ @ARC1.2@ @IMP1.2@"
		assertEquals "Complete chain REQ->ARC->IMP should exist for requirement 1.2" 0 $?

		echo "${_TAG_TABLE}" | grep -q "@REQ1.3@ @ARC1.3@ @IMP1.3@"
		assertEquals "Complete chain REQ->ARC->IMP should exist for requirement 1.3" 0 $?

		# Count total chains
		_CHAIN_COUNT=$(echo "${_TAG_TABLE}" | wc -l)
		assertEquals "Should have exactly 3 traceability chains" 3 "${_CHAIN_COUNT}"
	)
}

##
# @brief  Integration test for error handling
# @tag    @IT1.5@ (FROM: @UT1.18@)
test_integration_error_handling() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Create config with non-existent path
		cat >config_error.md <<'EOF'
# Error Config

## NonExistent

* **PATH**: "./non_existent_file.md"
  * **BRIEF**: "This file does not exist"
  * **TAG FORMAT**: `@TEST[0-9\.]+@`
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1
EOF

		# Act -------------
		_OUTPUT=$("${SHTRACER_BIN}" ./config_error.md 2>&1)
		_EXIT_CODE=$?

		# Assert ----------
		assertNotEquals "Shtracer should exit with error for non-existent file" 0 "${_EXIT_CODE}"

		# Error message should be present
		echo "${_OUTPUT}" | grep -q "error\|Error\|No linked tags"
		assertEquals "Error message should be present" 0 $?

		# Clean up
		rm -f config_error.md
	)
}

##
# @brief  Integration test for JSON export
# @tag    @IT1.4@ (FROM: @UT1.18@)
test_integration_json_export() {
	(
		# Arrange ---------
		cd "${TEST_DATA_DIR}" || exit 1

		# Act -------------
		_OUTPUT=$("${SHTRACER_BIN}" ./config_integration.md --json 2>&1)
		_EXIT_CODE=$?

		# Assert ----------
		assertEquals "Shtracer should exit successfully with JSON export" 0 "${_EXIT_CODE}"

		# Check JSON output exists
		assertTrue "JSON output should exist" "[ -f output/output.json ]"

		# Verify JSON is valid (basic structure check)
		_JSON_CONTENT=$(cat output/output.json)
		echo "${_JSON_CONTENT}" | grep -q '"metadata"'
		assertEquals "JSON should contain metadata" 0 $?

		echo "${_JSON_CONTENT}" | grep -q '"nodes"'
		assertEquals "JSON should contain nodes" 0 $?

		echo "${_JSON_CONTENT}" | grep -q '"links"'
		assertEquals "JSON should contain links" 0 $?

		echo "${_JSON_CONTENT}" | grep -q '"chains"'
		assertEquals "JSON should contain chains" 0 $?

		# HTML should still be generated
		assertTrue "HTML should still be generated with --json" "[ -f output/output.html ]"
	)
}

# shellcheck source=shunit2/shunit2
. "${SCRIPT_DIR}/shunit2/shunit2"
