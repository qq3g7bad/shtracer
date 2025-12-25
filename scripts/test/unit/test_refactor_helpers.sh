#!/bin/sh
# Unit tests for refactoring helper functions
# Tests POSIX compliance and exact behavioral equivalence with original awk/sed patterns

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

##
# @brief OneTimeSetUp function
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " TEST : Refactoring Helper Functions"
	echo "----------------------------------------"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	export SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"

	# Create temporary directory for test files
	TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'shtracer_test')"
	export TEMP_DIR
}

##
# @brief TearDown function for each test
#
tearDown() {
	# Clean up temporary directory
	if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
		rm -rf "$TEMP_DIR"
	fi
	set -u
}

# ============================================================================
# Phase 1: Field Extraction Helper Tests
# ============================================================================

##
# @brief Test extract_field with basic colon-separated input
#
test_extract_field_basic() {
	result=$(extract_field "a:b:c" 2 ":")
	assertEquals "b" "$result"
}

##
# @brief Test extract_field with first field
#
test_extract_field_first() {
	result=$(extract_field "one:two:three" 1 ":")
	assertEquals "one" "$result"
}

##
# @brief Test extract_field with last field
#
test_extract_field_last() {
	result=$(extract_field "one:two:three" 3 ":")
	assertEquals "three" "$result"
}

##
# @brief Test extract_field with empty field
#
test_extract_field_empty() {
	result=$(extract_field "a::c" 2 ":")
	assertEquals "" "$result"
}

##
# @brief Test extract_field with multi-character separator
#
test_extract_field_multichar_separator() {
	result=$(extract_field "data1<shtracer_separator>data2<shtracer_separator>data3" 2 "<shtracer_separator>")
	assertEquals "data2" "$result"
}

##
# @brief Test extract_field with pipe separator
#
test_extract_field_pipe() {
	result=$(extract_field "field1|field2|field3" 2 "|")
	assertEquals "field2" "$result"
}

##
# @brief Test extract_field with space separator
#
test_extract_field_space() {
	result=$(extract_field "word1 word2 word3" 3 " ")
	assertEquals "word3" "$result"
}

##
# @brief Test extract_field_unquoted with double quotes
#
test_extract_field_unquoted_basic() {
	result=$(extract_field_unquoted '"value1"::"value2"' 1 "::")
	assertEquals "value1" "$result"
}

##
# @brief Test extract_field_unquoted with second field
#
test_extract_field_unquoted_second() {
	result=$(extract_field_unquoted '"val1"::"val2"::"val3"' 2 "::")
	assertEquals "val2" "$result"
}

##
# @brief Test extract_field_unquoted with no quotes (should return as-is)
#
test_extract_field_unquoted_no_quotes() {
	result=$(extract_field_unquoted 'plain::text' 1 "::")
	assertEquals "plain" "$result"
}

##
# @brief Test count_fields with varying field counts
#
test_count_fields() {
	# Create temp file with different field counts per line
	cat >"$TEMP_DIR/fields.txt" <<'EOF'
a b c
d e f g
h i
EOF
	result=$(count_fields "$TEMP_DIR/fields.txt" " ")
	assertEquals "4" "$result"
}

##
# @brief Test count_fields with single field
#
test_count_fields_single() {
	cat >"$TEMP_DIR/single.txt" <<'EOF'
one
two
three
EOF
	result=$(count_fields "$TEMP_DIR/single.txt" " ")
	assertEquals "1" "$result"
}

##
# @brief Test count_fields with colon separator
#
test_count_fields_colon() {
	cat >"$TEMP_DIR/colon.txt" <<'EOF'
a:b
c:d:e:f
x:y:z
EOF
	result=$(count_fields "$TEMP_DIR/colon.txt" ":")
	assertEquals "4" "$result"
}

# ============================================================================
# Phase 2: Whitespace and Quote Processing Tests
# ============================================================================

##
# @brief Test trim_whitespace with leading spaces
#
test_trim_whitespace_leading() {
	result=$(trim_whitespace "   text")
	assertEquals "text" "$result"
}

##
# @brief Test trim_whitespace with trailing spaces
#
test_trim_whitespace_trailing() {
	result=$(trim_whitespace "text   ")
	assertEquals "text" "$result"
}

##
# @brief Test trim_whitespace with both
#
test_trim_whitespace_both() {
	result=$(trim_whitespace "  text  ")
	assertEquals "text" "$result"
}

##
# @brief Test trim_whitespace with tabs
#
test_trim_whitespace_tabs() {
	result=$(trim_whitespace "		text		")
	assertEquals "text" "$result"
}

##
# @brief Test trim_whitespace with mixed whitespace
#
test_trim_whitespace_mixed() {
	result=$(trim_whitespace " 	 text 	 ")
	assertEquals "text" "$result"
}

##
# @brief Test remove_empty_lines
#
test_remove_empty_lines() {
	cat >"$TEMP_DIR/empty.txt" <<'EOF'
line1

line3

line5
EOF
	result=$(cat "$TEMP_DIR/empty.txt" | remove_empty_lines | wc -l)
	assertEquals "3" "$result"
}

##
# @brief Test remove_empty_lines with whitespace-only lines
#
test_remove_empty_lines_whitespace() {
	cat >"$TEMP_DIR/whitespace.txt" <<'EOF'
line1

line3

line5
EOF
	result=$(cat "$TEMP_DIR/whitespace.txt" | remove_empty_lines | wc -l)
	assertEquals "3" "$result"
}

##
# @brief Test remove_leading_bullets
#
test_remove_leading_bullets() {
	result=$(echo "* item" | remove_leading_bullets)
	assertEquals "item" "$result"
}

##
# @brief Test remove_leading_bullets with spaces
#
test_remove_leading_bullets_spaces() {
	result=$(echo "  * item" | remove_leading_bullets)
	assertEquals "item" "$result"
}

##
# @brief Test extract_from_delimiters with double quotes
#
test_extract_from_delimiters_quotes() {
	result=$(extract_from_delimiters '"content"' '"')
	assertEquals "content" "$result"
}

##
# @brief Test extract_from_delimiters with backticks
#
test_extract_from_delimiters_backticks() {
	result=$(extract_from_delimiters '`test`' '`')
	assertEquals "test" "$result"
}

##
# @brief Test extract_from_delimiters with whitespace
#
test_extract_from_delimiters_whitespace() {
	result=$(extract_from_delimiters '  "trimmed"  ' '"')
	assertEquals "trimmed" "$result"
}

##
# @brief Test extract_from_delimiters without delimiters
#
test_extract_from_delimiters_no_delim() {
	result=$(extract_from_delimiters 'plain text' '"')
	assertEquals "plain text" "$result"
}

##
# @brief Test extract_from_doublequotes
#
test_extract_from_doublequotes() {
	result=$(extract_from_doublequotes '"value"')
	assertEquals "value" "$result"
}

##
# @brief Test extract_from_doublequotes with whitespace
#
test_extract_from_doublequotes_whitespace() {
	result=$(extract_from_doublequotes '  "value"  ')
	assertEquals "value" "$result"
}

##
# @brief Test extract_from_backticks
#
test_extract_from_backticks() {
	result=$(extract_from_backticks '`command`')
	assertEquals "command" "$result"
}

##
# @brief Test extract_from_backticks with whitespace
#
test_extract_from_backticks_whitespace() {
	result=$(extract_from_backticks '  `command`  ')
	assertEquals "command" "$result"
}

# ============================================================================
# Phase 3: Escaping and Encoding Tests
# ============================================================================

##
# @brief Test escape_sed_pattern with basic metacharacters
#
test_escape_sed_pattern_basic() {
	result=$(escape_sed_pattern "a.b*c")
	assertEquals "a\\.b\\*c" "$result"
}

##
# @brief Test escape_sed_pattern with brackets
#
test_escape_sed_pattern_brackets() {
	result=$(escape_sed_pattern "[a-z]")
	assertEquals "\\[a-z\\]" "$result"
}

##
# @brief Test escape_sed_pattern with anchors
#
test_escape_sed_pattern_anchors() {
	result=$(escape_sed_pattern "^start$")
	assertEquals "\\^start\\$" "$result"
}

##
# @brief Test escape_sed_pattern with parens and pipe
#
test_escape_sed_pattern_complex() {
	result=$(escape_sed_pattern "(foo|bar)")
	assertEquals "\\(foo\\|bar\\)" "$result"
}

##
# @brief Test escape_sed_replacement with backslash
#
test_escape_sed_replacement_backslash() {
	result=$(escape_sed_replacement 'path\to\file')
	assertEquals 'path\\to\\file' "$result"
}

##
# @brief Test escape_sed_replacement with ampersand
#
test_escape_sed_replacement_ampersand() {
	result=$(escape_sed_replacement 'foo&bar')
	assertEquals 'foo\&bar' "$result"
}

##
# @brief Test escape_sed_replacement with pipe
#
test_escape_sed_replacement_pipe() {
	result=$(escape_sed_replacement 'a|b')
	assertEquals 'a\|b' "$result"
}

##
# @brief Test escape_sed_replacement with all special chars
#
test_escape_sed_replacement_all() {
	result=$(escape_sed_replacement 'a\b&c|d')
	assertEquals 'a\\b\&c\|d' "$result"
}

##
# @brief Test html_escape with ampersand
#
test_html_escape_ampersand() {
	result=$(html_escape 'a&b')
	assertEquals 'a&amp;b' "$result"
}

##
# @brief Test html_escape with less-than and greater-than
#
test_html_escape_brackets() {
	result=$(html_escape '<script>')
	assertEquals '&lt;script&gt;' "$result"
}

##
# @brief Test html_escape with quotes
#
test_html_escape_quotes() {
	result=$(html_escape 'say "hello"')
	assertEquals 'say &quot;hello&quot;' "$result"
}

##
# @brief Test html_escape with single quotes
#
test_html_escape_single_quotes() {
	result=$(html_escape "it's")
	assertEquals 'it&#39;s' "$result"
}

##
# @brief Test html_escape with XSS attempt
#
test_html_escape_xss() {
	result=$(html_escape '<script>alert("XSS")</script>')
	assertEquals '&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;' "$result"
}

##
# @brief Test js_escape with backslash
#
test_js_escape_backslash() {
	result=$(js_escape 'path\to\file')
	assertEquals 'path\\to\\file' "$result"
}

##
# @brief Test js_escape with double quotes
#
test_js_escape_quotes() {
	result=$(js_escape 'say "hello"')
	assertEquals 'say \"hello\"' "$result"
}

##
# @brief Test js_escape with tab
#
test_js_escape_tab() {
	# Create string with actual tab character
	tab_str="a	b"
	result=$(js_escape "$tab_str")
	assertEquals 'a\tb' "$result"
}

##
# @brief Test js_escape with combined escapes
#
test_js_escape_combined() {
	result=$(js_escape 'a\"b\\c')
	assertEquals 'a\\\"b\\\\c' "$result"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
