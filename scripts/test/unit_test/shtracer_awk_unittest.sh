#!/bin/sh
# Unit tests for AWK library functions
# Tests standalone AWK functions in awk/common.awk and awk/field_extractors.awk

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

# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

# Load AWK library source as strings (POSIX awk cannot combine -f with inline code)
AWK_COMMON_SRC=$(cat "${SHTRACER_ROOT_DIR%/}/scripts/main/awk/common.awk")
AWK_FIELD_SRC=$(cat "${SHTRACER_ROOT_DIR%/}/scripts/main/awk/field_extractors.awk")

##
# @brief OneTimeSetUp function
#
oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (AWK Library Functions)"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
}

##
# @brief TearDown function for each test
#
tearDown() {
	set -u
}

# ============================================================================
# Helper: run AWK expression using string-injected library functions
# POSIX awk does not support combining -f with inline program text,
# so we inject library source via string concatenation.
# ============================================================================

##
# @brief Run an AWK expression with common.awk loaded
# @param $1 : AWK expression to evaluate in BEGIN block
_run_common_awk() {
	awk "${AWK_COMMON_SRC} BEGIN{ $1 }" </dev/null
}

##
# @brief Run an AWK expression with field_extractors.awk loaded
# @param $1 : AWK expression to evaluate in BEGIN block
_run_field_awk() {
	awk "${AWK_FIELD_SRC} BEGIN{ $1 }" </dev/null
}

##
# @brief Run an AWK expression with both libraries loaded
# @param $1 : AWK expression to evaluate in BEGIN block
_run_all_awk() {
	awk "${AWK_COMMON_SRC} ${AWK_FIELD_SRC} BEGIN{ $1 }" </dev/null
}

# ============================================================================
# Phase 1: trim() tests
# @tag @UT5.1@ (FROM: @IMP5.1@)
# ============================================================================

##
# @brief Test trim removes leading spaces
#
test_trim_leading_spaces() {
	result=$(_run_common_awk 'print trim("   hello")')
	assertEquals "hello" "$result"
}

##
# @brief Test trim removes trailing spaces
#
test_trim_trailing_spaces() {
	result=$(_run_common_awk 'print trim("hello   ")')
	assertEquals "hello" "$result"
}

##
# @brief Test trim removes both leading and trailing spaces
#
test_trim_both_sides() {
	result=$(_run_common_awk 'print trim("  hello world  ")')
	assertEquals "hello world" "$result"
}

##
# @brief Test trim with tabs
#
test_trim_tabs() {
	# Use printf to inject a real tab character
	result=$(printf '\thello\t' | awk "${AWK_COMMON_SRC}"'{ print trim($0) }')
	assertEquals "hello" "$result"
}

##
# @brief Test trim with already trimmed string
#
test_trim_no_whitespace() {
	result=$(_run_common_awk 'print trim("hello")')
	assertEquals "hello" "$result"
}

##
# @brief Test trim with empty string
#
test_trim_empty_string() {
	result=$(_run_common_awk 'print trim("")')
	assertEquals "" "$result"
}

##
# @brief Test trim with only whitespace
#
test_trim_all_whitespace() {
	result=$(_run_common_awk 'print trim("   ")')
	assertEquals "" "$result"
}

# ============================================================================
# Phase 2: get_last_segment() tests
# @tag @UT5.2@ (FROM: @IMP5.2@)
# ============================================================================

##
# @brief Test get_last_segment with colon-separated string
#
test_get_last_segment_basic() {
	result=$(_run_common_awk 'print get_last_segment("A:B:C")')
	assertEquals "C" "$result"
}

##
# @brief Test get_last_segment with single element (no colon)
#
test_get_last_segment_no_colon() {
	result=$(_run_common_awk 'print get_last_segment("OnlyOne")')
	assertEquals "OnlyOne" "$result"
}

##
# @brief Test get_last_segment with two elements
#
test_get_last_segment_two_parts() {
	result=$(_run_common_awk 'print get_last_segment("First:Second")')
	assertEquals "Second" "$result"
}

##
# @brief Test get_last_segment with empty last segment
#
test_get_last_segment_trailing_colon() {
	result=$(_run_common_awk 'print get_last_segment("A:B:")')
	assertEquals "" "$result"
}

##
# @brief Test get_last_segment with typical trace_target value
#
test_get_last_segment_trace_target() {
	result=$(_run_common_awk 'print get_last_segment(":Main:Requirement")')
	assertEquals "Requirement" "$result"
}

# ============================================================================
# Phase 3: escape_html() tests
# @tag @UT5.3@ (FROM: @IMP5.3@)
# ============================================================================

##
# @brief Test escape_html with ampersand
#
test_escape_html_ampersand() {
	result=$(_run_common_awk 'print escape_html("a&b")')
	assertEquals "a&amp;b" "$result"
}

##
# @brief Test escape_html with less-than
#
test_escape_html_lt() {
	result=$(_run_common_awk 'print escape_html("a<b")')
	assertEquals "a&lt;b" "$result"
}

##
# @brief Test escape_html with greater-than
#
test_escape_html_gt() {
	result=$(_run_common_awk 'print escape_html("a>b")')
	assertEquals "a&gt;b" "$result"
}

##
# @brief Test escape_html with double quotes
#
test_escape_html_quot() {
	# Use printf to avoid shell quoting issues
	result=$(printf 'a"b' | awk "${AWK_COMMON_SRC}"'{ print escape_html($0) }')
	assertEquals 'a&quot;b' "$result"
}

##
# @brief Test escape_html with mixed special characters
#
test_escape_html_mixed() {
	result=$(_run_common_awk 'print escape_html("<script>alert(1)</script>")')
	assertEquals "&lt;script&gt;alert(1)&lt;/script&gt;" "$result"
}

##
# @brief Test escape_html with no special characters
#
test_escape_html_plain_text() {
	result=$(_run_common_awk 'print escape_html("hello world")')
	assertEquals "hello world" "$result"
}

##
# @brief Test escape_html with empty string
#
test_escape_html_empty() {
	result=$(_run_common_awk 'print escape_html("")')
	assertEquals "" "$result"
}

##
# @brief Test escape_html processes ampersand before other entities
# @details Ensures & is escaped first so &lt; doesn't become &amp;lt;
#
test_escape_html_order_of_operations() {
	result=$(_run_common_awk 'print escape_html("&<>")')
	assertEquals "&amp;&lt;&gt;" "$result"
}

# ============================================================================
# Phase 4: json_escape() tests
# @tag @UT5.4@ (FROM: @IMP5.4@)
# ============================================================================

##
# @brief Test json_escape with backslash
#
test_json_escape_backslash() {
	result=$(printf 'a\\b' | awk "${AWK_COMMON_SRC}"'{ print json_escape($0) }')
	assertEquals 'a\\b' "$result"
}

##
# @brief Test json_escape with double quotes
#
test_json_escape_quotes() {
	result=$(printf 'say "hello"' | awk "${AWK_COMMON_SRC}"'{ print json_escape($0) }')
	assertEquals 'say \"hello\"' "$result"
}

##
# @brief Test json_escape with tab character
#
test_json_escape_tab() {
	result=$(printf 'a\tb' | awk "${AWK_COMMON_SRC}"'{ print json_escape($0) }')
	assertEquals 'a\tb' "$result"
}

##
# @brief Test json_escape with plain text (no special characters)
#
test_json_escape_plain_text() {
	result=$(_run_common_awk 'print json_escape("hello world")')
	assertEquals "hello world" "$result"
}

##
# @brief Test json_escape with empty string
#
test_json_escape_empty() {
	result=$(_run_common_awk 'print json_escape("")')
	assertEquals "" "$result"
}

# ============================================================================
# Phase 5: basename() tests
# @tag @UT5.5@ (FROM: @IMP5.5@)
# ============================================================================

##
# @brief Test basename with standard path
#
test_basename_standard_path() {
	result=$(_run_common_awk 'print basename("/path/to/file.txt")')
	assertEquals "file.txt" "$result"
}

##
# @brief Test basename with deeply nested path
#
test_basename_deep_path() {
	result=$(_run_common_awk 'print basename("/a/b/c/d/e/report.md")')
	assertEquals "report.md" "$result"
}

##
# @brief Test basename with filename only (no path)
#
test_basename_no_path() {
	result=$(_run_common_awk 'print basename("file.txt")')
	assertEquals "file.txt" "$result"
}

##
# @brief Test basename with trailing slash
#
test_basename_trailing_slash() {
	result=$(_run_common_awk 'print basename("/path/to/")')
	assertEquals "" "$result"
}

##
# @brief Test basename with relative path
#
test_basename_relative_path() {
	result=$(_run_common_awk 'print basename("./scripts/main/shtracer.sh")')
	assertEquals "shtracer.sh" "$result"
}

# ============================================================================
# Phase 6: ext_from_basename() tests
# @tag @UT5.6@ (FROM: @IMP5.6@)
# ============================================================================

##
# @brief Test ext_from_basename with .txt extension
#
test_ext_from_basename_txt() {
	result=$(_run_common_awk 'print ext_from_basename("file.txt")')
	assertEquals "txt" "$result"
}

##
# @brief Test ext_from_basename with .md extension
#
test_ext_from_basename_md() {
	result=$(_run_common_awk 'print ext_from_basename("README.md")')
	assertEquals "md" "$result"
}

##
# @brief Test ext_from_basename with .sh extension
#
test_ext_from_basename_sh() {
	result=$(_run_common_awk 'print ext_from_basename("script.sh")')
	assertEquals "sh" "$result"
}

##
# @brief Test ext_from_basename with multiple dots
#
test_ext_from_basename_multiple_dots() {
	result=$(_run_common_awk 'print ext_from_basename("archive.tar.gz")')
	assertEquals "gz" "$result"
}

##
# @brief Test ext_from_basename with no extension (defaults to "sh")
#
test_ext_from_basename_no_extension() {
	result=$(_run_common_awk 'print ext_from_basename("Makefile")')
	assertEquals "sh" "$result"
}

##
# @brief Test ext_from_basename with dot-only filename
#
test_ext_from_basename_hidden_file() {
	result=$(_run_common_awk 'print ext_from_basename(".gitignore")')
	assertEquals "gitignore" "$result"
}

# ============================================================================
# Phase 7: fileid_from_path() tests
# @tag @UT5.7@ (FROM: @IMP5.7@)
# ============================================================================

##
# @brief Test fileid_from_path with standard path
#
test_fileid_from_path_standard() {
	result=$(_run_common_awk 'print fileid_from_path("/path/to/file.txt")')
	assertEquals "Target_file_txt" "$result"
}

##
# @brief Test fileid_from_path with .md file
#
test_fileid_from_path_md() {
	result=$(_run_common_awk 'print fileid_from_path("/docs/01_requirements.md")')
	assertEquals "Target_01_requirements_md" "$result"
}

##
# @brief Test fileid_from_path with .sh file
#
test_fileid_from_path_sh() {
	result=$(_run_common_awk 'print fileid_from_path("./scripts/main/shtracer_util.sh")')
	assertEquals "Target_shtracer_util_sh" "$result"
}

##
# @brief Test fileid_from_path dots replaced with underscores
#
test_fileid_from_path_multiple_dots() {
	result=$(_run_common_awk 'print fileid_from_path("/path/archive.tar.gz")')
	assertEquals "Target_archive_tar_gz" "$result"
}

##
# @brief Test fileid_from_path with filename only
#
test_fileid_from_path_no_directory() {
	result=$(_run_common_awk 'print fileid_from_path("config.md")')
	assertEquals "Target_config_md" "$result"
}

# ============================================================================
# Phase 8: type_from_trace_target() tests
# @tag @UT5.8@ (FROM: @IMP5.8@)
# ============================================================================

##
# @brief Test type_from_trace_target with standard trace_target
#
test_type_from_trace_target_standard() {
	result=$(_run_common_awk 'print type_from_trace_target(":Main:Requirement")')
	assertEquals "Requirement" "$result"
}

##
# @brief Test type_from_trace_target with Implementation
#
test_type_from_trace_target_implementation() {
	result=$(_run_common_awk 'print type_from_trace_target(":Main:Implementation")')
	assertEquals "Implementation" "$result"
}

##
# @brief Test type_from_trace_target with single segment
#
test_type_from_trace_target_single() {
	result=$(_run_common_awk 'print type_from_trace_target("Architecture")')
	assertEquals "Architecture" "$result"
}

##
# @brief Test type_from_trace_target with empty string
#
test_type_from_trace_target_empty() {
	result=$(_run_common_awk 'print type_from_trace_target("")')
	assertEquals "Unknown" "$result"
}

##
# @brief Test type_from_trace_target trims whitespace from result
#
test_type_from_trace_target_whitespace() {
	result=$(_run_common_awk 'print type_from_trace_target(":Main: Test ")')
	assertEquals "Test" "$result"
}

##
# @brief Test type_from_trace_target with trailing colon (empty last segment)
#
test_type_from_trace_target_trailing_colon() {
	result=$(_run_common_awk 'print type_from_trace_target(":Main:")')
	assertEquals "Unknown" "$result"
}

# ============================================================================
# Phase 9: field1() - field6() tests (field_extractors.awk)
# @tag @UT6.1@ (FROM: @IMP6.1@)
# ============================================================================

##
# @brief Test field1 extracts first field
#
test_field1_basic() {
	result=$(_run_field_awk 'print field1("alpha<SEP>bravo<SEP>charlie", "<SEP>")')
	assertEquals "alpha" "$result"
}

##
# @brief Test field1 with no delimiter present
#
test_field1_no_delimiter() {
	result=$(_run_field_awk 'print field1("onlyone", "<SEP>")')
	assertEquals "onlyone" "$result"
}

##
# @brief Test field1 with empty first field
#
test_field1_empty_first() {
	result=$(_run_field_awk 'print field1("<SEP>bravo<SEP>charlie", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field2 extracts second field
#
test_field2_basic() {
	result=$(_run_field_awk 'print field2("alpha<SEP>bravo<SEP>charlie", "<SEP>")')
	assertEquals "bravo" "$result"
}

##
# @brief Test field2 with only one field (returns empty)
#
test_field2_missing() {
	result=$(_run_field_awk 'print field2("onlyone", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field2 when it is the last field
#
test_field2_last_field() {
	result=$(_run_field_awk 'print field2("alpha<SEP>bravo", "<SEP>")')
	assertEquals "bravo" "$result"
}

##
# @brief Test field3 extracts third field
#
test_field3_basic() {
	result=$(_run_field_awk 'print field3("alpha<SEP>bravo<SEP>charlie<SEP>delta", "<SEP>")')
	assertEquals "charlie" "$result"
}

##
# @brief Test field3 with too few fields
#
test_field3_missing() {
	result=$(_run_field_awk 'print field3("alpha<SEP>bravo", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field4 extracts fourth field
#
test_field4_basic() {
	result=$(_run_field_awk 'print field4("a<SEP>b<SEP>c<SEP>d<SEP>e", "<SEP>")')
	assertEquals "d" "$result"
}

##
# @brief Test field4 with too few fields
#
test_field4_missing() {
	result=$(_run_field_awk 'print field4("a<SEP>b", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field5 extracts fifth field
#
test_field5_basic() {
	result=$(_run_field_awk 'print field5("a<SEP>b<SEP>c<SEP>d<SEP>e<SEP>f", "<SEP>")')
	assertEquals "e" "$result"
}

##
# @brief Test field5 with too few fields
#
test_field5_missing() {
	result=$(_run_field_awk 'print field5("a<SEP>b<SEP>c", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field6 extracts sixth field
#
test_field6_basic() {
	result=$(_run_field_awk 'print field6("a<SEP>b<SEP>c<SEP>d<SEP>e<SEP>f<SEP>g", "<SEP>")')
	assertEquals "f" "$result"
}

##
# @brief Test field6 with too few fields
#
test_field6_missing() {
	result=$(_run_field_awk 'print field6("a<SEP>b", "<SEP>")')
	assertEquals "" "$result"
}

##
# @brief Test field6 as the last field
#
test_field6_last_field() {
	result=$(_run_field_awk 'print field6("a<SEP>b<SEP>c<SEP>d<SEP>e<SEP>f", "<SEP>")')
	assertEquals "f" "$result"
}

# ============================================================================
# Phase 10: field extractors with multi-character delimiter (shtracer_separator)
# ============================================================================

##
# @brief Test field extractors with shtracer_separator delimiter
#
test_fields_with_shtracer_separator() {
	_sep="<shtracer_separator>"
	_input="tag1${_sep}file.md${_sep}10${_sep}Title${_sep}@REQ1@${_sep}Requirement"
	result=$(_run_field_awk "print field1(\"${_input}\", \"${_sep}\")")
	assertEquals "tag1" "$result"
	result=$(_run_field_awk "print field2(\"${_input}\", \"${_sep}\")")
	assertEquals "file.md" "$result"
	result=$(_run_field_awk "print field3(\"${_input}\", \"${_sep}\")")
	assertEquals "10" "$result"
	result=$(_run_field_awk "print field4(\"${_input}\", \"${_sep}\")")
	assertEquals "Title" "$result"
	result=$(_run_field_awk "print field5(\"${_input}\", \"${_sep}\")")
	assertEquals "@REQ1@" "$result"
	result=$(_run_field_awk "print field6(\"${_input}\", \"${_sep}\")")
	assertEquals "Requirement" "$result"
}

# ============================================================================
# Phase 11: Cross-library integration tests
# @tag @UT4.5@ (FROM: @IMP4.5@)
# ============================================================================

##
# @brief Test that both AWK libraries can be loaded together
#
test_combined_libraries_load() {
	result=$(_run_all_awk 'print trim(" hello ") " " field1("a<S>b", "<S>")')
	assertEquals "hello a" "$result"
}

##
# @brief Test common + field_extractors on a realistic record
#
test_combined_realistic_record() {
	_sep="<shtracer_separator>"
	_input="/path/to/req.md${_sep}Implementation"
	result=$(_run_all_awk "print basename(field1(\"${_input}\", \"${_sep}\"))")
	assertEquals "req.md" "$result"
	result=$(_run_all_awk "print type_from_trace_target(field2(\"${_input}\", \"${_sep}\"))")
	assertEquals "Implementation" "$result"
}

##
# @brief Test escape_html with field_extractors
#
test_combined_escape_html_with_field() {
	result=$(_run_all_awk 'print escape_html(field1("<b>bold</b><D>normal", "<D>"))')
	assertEquals "&lt;b&gt;bold&lt;/b&gt;" "$result"
}

# ============================================================================
# Load shUnit2 test framework
# ============================================================================
# shellcheck source=../shunit2/shunit2
. "${SHTRACER_ROOT_DIR%/}/scripts/test/shunit2/shunit2"
