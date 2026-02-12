#!/bin/sh
# Unit tests for markdown viewer functions (shtracer_markdown_viewer.sh)

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
# shellcheck source=../../main/shtracer_json_parser.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_json_parser.sh"
# shellcheck source=../../main/shtracer_markdown_viewer.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_markdown_viewer.sh"
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

# Minimal JSON fixture
# shellcheck disable=SC2034
TEST_JSON='{
  "metadata": {
    "version": "0.2.0",
    "generated": "2026-01-15T10:30:00Z",
    "config_path": "/path/to/config.md"
  },
  "files": [],
  "layers": [],
  "trace_tags": [],
  "chains": [],
  "health": {
    "total_tags": 0,
    "tags_with_links": 0,
    "isolated_tags": 0,
    "isolated_tag_list": [],
    "duplicate_tags": 0,
    "duplicate_tag_list": [],
    "dangling_references": 0,
    "dangling_reference_list": [],
    "coverage": {"layers": []}
  }
}'

##
# @brief
#
oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (Markdown Viewer)"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
}

# ============================================================================
# _generate_markdown_header tests
# ============================================================================

##
# @brief Test _generate_markdown_header contains title
# @tag @UT4.3.1@ (FROM: @IMP4.3.1@)
test_generate_markdown_header_title() {
	result=$(_generate_markdown_header "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '# Traceability Report')"
}

##
# @brief Test _generate_markdown_header contains version
test_generate_markdown_header_version() {
	result=$(_generate_markdown_header "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '0.2.0')"
}

##
# @brief Test _generate_markdown_header contains generated timestamp
test_generate_markdown_header_generated() {
	result=$(_generate_markdown_header "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '2026-01-15T10:30:00Z')"
}

##
# @brief Test _generate_markdown_header contains config path
test_generate_markdown_header_config_path() {
	result=$(_generate_markdown_header "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '/path/to/config.md')"
}

##
# @brief Test _generate_markdown_header ends with horizontal rule
test_generate_markdown_header_rule() {
	result=$(_generate_markdown_header "$TEST_JSON")
	last_line=$(printf '%s\n' "$result" | tail -1)
	assertEquals "---" "$last_line"
}

# ============================================================================
# _generate_markdown_toc tests
# ============================================================================

##
# @brief Test _generate_markdown_toc contains section header
# @tag @UT4.3.2@ (FROM: @IMP4.3.2@)
test_generate_markdown_toc_header() {
	result=$(_generate_markdown_toc "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep '## Table of Contents')"
}

##
# @brief Test _generate_markdown_toc contains expected sections
test_generate_markdown_toc_sections() {
	result=$(_generate_markdown_toc "$TEST_JSON")
	assertNotEquals "" "$(printf '%s\n' "$result" | grep 'Executive Summary')"
	assertNotEquals "" "$(printf '%s\n' "$result" | grep 'Traceability Health')"
	assertNotEquals "" "$(printf '%s\n' "$result" | grep 'Tag Index')"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
