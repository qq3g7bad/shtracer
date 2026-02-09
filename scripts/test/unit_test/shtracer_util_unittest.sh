#!/bin/sh
# Unit tests for utility functions
# Tests POSIX-compliant helper functions in shtracer_util.sh

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
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

##
# @brief OneTimeSetUp function
#
oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (Utility Functions)"
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
	result=$(remove_empty_lines <"$TEMP_DIR/empty.txt" | wc -l | tr -d ' ')
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
	result=$(remove_empty_lines <"$TEMP_DIR/whitespace.txt" | wc -l | tr -d ' ')
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
	# shellcheck disable=SC2016  # Backticks in single quotes are intentional for testing
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
	# shellcheck disable=SC2016  # Backticks in single quotes are intentional for testing
	result=$(extract_from_backticks '`command`')
	assertEquals "command" "$result"
}

##
# @brief Test extract_from_backticks with whitespace
#
test_extract_from_backticks_whitespace() {
	# shellcheck disable=SC2016  # Backticks in single quotes are intentional for testing
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

# ============================================================================
# Phase 4: Complex Processing Tests (Comment Removal)
# ============================================================================

##
# @brief Test remove_markdown_comments with inline comment
#
test_remove_markdown_comments_inline() {
	cat >"$TEMP_DIR/inline.md" <<'EOF'
Text before <!-- comment --> text after
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/inline.md")
	assertEquals "Text before  text after" "$result"
}

##
# @brief Test remove_markdown_comments with multi-line comment
#
test_remove_markdown_comments_multiline() {
	cat >"$TEMP_DIR/multiline.md" <<'EOF'
Before
<!-- Start
Middle
End -->
After
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/multiline.md" | tr '\n' ' ' | sed 's/  */ /g')
	assertEquals "Before After " "$result"
}

##
# @brief Test remove_markdown_comments preserves backtick comments
#
test_remove_markdown_comments_backtick() {
	cat >"$TEMP_DIR/backtick.md" <<'EOF'
`code <!-- keep --> end`
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/backtick.md")
	assertEquals "\`code <!-- keep --> end\`" "$result"
}

##
# @brief Test remove_markdown_comments with no comments
#
test_remove_markdown_comments_none() {
	cat >"$TEMP_DIR/none.md" <<'EOF'
Line 1
Line 2
Line 3
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/none.md" | wc -l | tr -d ' ')
	assertEquals "3" "$result"
}

##
# @brief Test remove_markdown_comments with comment at start
#
test_remove_markdown_comments_start() {
	cat >"$TEMP_DIR/start.md" <<'EOF'
<!-- comment -->Text after
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/start.md")
	assertEquals "Text after" "$result"
}

##
# @brief Test remove_markdown_comments with comment at end
#
test_remove_markdown_comments_end() {
	cat >"$TEMP_DIR/end.md" <<'EOF'
Text before<!-- comment -->
EOF
	result=$(remove_markdown_comments "$TEMP_DIR/end.md")
	assertEquals "Text before" "$result"
}

##
# @brief Test remove_trailing_whitespace
#
test_remove_trailing_whitespace() {
	result=$(echo "text   " | remove_trailing_whitespace)
	assertEquals "text" "$result"
}

##
# @brief Test remove_trailing_whitespace with tabs
#
test_remove_trailing_whitespace_tabs() {
	result=$(printf "text\t\t\n" | remove_trailing_whitespace)
	assertEquals "text" "$result"
}

##
# @brief Test convert_markdown_bold
#
test_convert_markdown_bold() {
	result=$(echo "**Header:**" | convert_markdown_bold)
	assertEquals "Header:" "$result"
}

##
# @brief Test convert_markdown_bold with text content
#
test_convert_markdown_bold_content() {
	result=$(echo "**Section Title:** description" | convert_markdown_bold)
	assertEquals "Section Title: description" "$result"
}

# ============================================================================
# Phase 5: JSON and HTML Processing Tests
# ============================================================================

##
# @brief Test extract_json_string_field with valid JSON
#
test_extract_json_string_field_basic() {
	cat >"$TEMP_DIR/test.json" <<'EOF'
{
  "config_path": "/path/to/config.md",
  "other_field": "value"
}
EOF
	result=$(extract_json_string_field "$TEMP_DIR/test.json" "config_path")
	assertEquals "/path/to/config.md" "$result"
}

##
# @brief Test extract_json_string_field with whitespace variations
#
test_extract_json_string_field_whitespace() {
	cat >"$TEMP_DIR/test2.json" <<'EOF'
{
  "field1"  :  "value1",
  "field2":"value2"
}
EOF
	result1=$(extract_json_string_field "$TEMP_DIR/test2.json" "field1")
	result2=$(extract_json_string_field "$TEMP_DIR/test2.json" "field2")
	assertEquals "value1" "$result1"
	assertEquals "value2" "$result2"
}

##
# @brief Test extract_json_string_field with missing field
#
test_extract_json_string_field_missing() {
	cat >"$TEMP_DIR/test3.json" <<'EOF'
{
  "existing": "value"
}
EOF
	result=$(extract_json_string_field "$TEMP_DIR/test3.json" "nonexistent")
	assertEquals "" "$result"
}

##
# @brief Test extract_json_string_field with missing file
#
test_extract_json_string_field_no_file() {
	result=$(extract_json_string_field "$TEMP_DIR/nonexistent.json" "field" 2>/dev/null)
	assertNotEquals "0" "$?"
}

##
# @brief Test extract_json_string_field with path containing special chars
#
test_extract_json_string_field_special_chars() {
	cat >"$TEMP_DIR/test4.json" <<'EOF'
{
  "path": "/path/with spaces/file.md"
}
EOF
	result=$(extract_json_string_field "$TEMP_DIR/test4.json" "path")
	assertEquals "/path/with spaces/file.md" "$result"
}

##
# @brief Test remove_lines_with_pattern basic
#
test_remove_lines_with_pattern_basic() {
	result=$(printf "line1\n<!-- MARKER -->\nline3\n" | remove_lines_with_pattern "<!-- MARKER -->")
	expected=$(printf "line1\nline3\n")
	assertEquals "$expected" "$result"
}

##
# @brief Test remove_lines_with_pattern with HTML comment
#
test_remove_lines_with_pattern_html_comment() {
	result=$(printf "keep\n<!-- SHTRACER INSERTED -->\nkeep too\n" | remove_lines_with_pattern "<!-- SHTRACER INSERTED -->")
	expected=$(printf "keep\nkeep too\n")
	assertEquals "$expected" "$result"
}

##
# @brief Test remove_lines_with_pattern with no match
#
test_remove_lines_with_pattern_no_match() {
	result=$(printf "line1\nline2\nline3\n" | remove_lines_with_pattern "NOTFOUND")
	assertEquals "line1" "$(echo "$result" | head -1)"
	# Count non-empty lines
	line_count=$(echo "$result" | grep -c "^")
	assertEquals "3" "$line_count"
}

##
# @brief Test remove_lines_with_pattern with special regex chars
#
test_remove_lines_with_pattern_special_chars() {
	result=$(printf "keep\n[test]\nkeep\n" | remove_lines_with_pattern "[test]")
	expected=$(printf "keep\nkeep\n")
	assertEquals "$expected" "$result"
}

# ============================================================================
# Phase 5.5: File Version Info Tests
# ============================================================================

##
# @brief Test get_file_version_info with a git-tracked file
#
test_get_file_version_info_git_file() {
	# Use the shtracer script itself which is in a git repo
	_git_file="${SHTRACER_ROOT_DIR}/shtracer"
	if [ -f "$_git_file" ]; then
		result=$(get_file_version_info "$_git_file")
		# Result should be "git:XXXXXXX" (7-char hash)
		case "$result" in
			git:??????*)
				assertTrue "Should return git hash" true
				;;
			*)
				fail "Expected git:XXXXXXX format, got: $result"
				;;
		esac
	else
		# Skip if file doesn't exist
		startSkipping
	fi
}

##
# @brief Test get_file_version_info with a non-git file
#
test_get_file_version_info_non_git_file() {
	# Create a file outside any git repo
	_test_file="$TEMP_DIR/non_git_file.txt"
	echo "test content" >"$_test_file"

	# Move to temp dir to ensure not in git repo context
	(
		cd "$TEMP_DIR" || exit 1
		result=$(get_file_version_info "$_test_file")

		# Should fall back to mtime format
		case "$result" in
			mtime:*)
				assertTrue "Should return mtime format" true
				;;
			unknown)
				# Also acceptable if stat/date not available
				assertTrue "Unknown is acceptable fallback" true
				;;
			*)
				fail "Expected mtime:ISO8601 or unknown, got: $result"
				;;
		esac
	)
}

##
# @brief Test get_file_version_info with non-existent file
#
test_get_file_version_info_nonexistent() {
	result=$(get_file_version_info "/nonexistent/file.txt")
	status=$?

	assertEquals "unknown" "$result"
	assertEquals "Should return error status" 1 "$status"
}

##
# @brief Test format_version_info_short with git format
#
test_format_version_info_short_git() {
	result=$(format_version_info_short "git:abc1234")
	assertEquals "abc1234" "$result"
}

##
# @brief Test format_version_info_short with mtime format
#
test_format_version_info_short_mtime() {
	result=$(format_version_info_short "mtime:2025-12-26T10:30:45Z")
	assertEquals "2025-12-26 10:30" "$result"
}

##
# @brief Test format_version_info_short with unknown format
#
test_format_version_info_short_unknown() {
	result=$(format_version_info_short "unknown")
	assertEquals "unknown" "$result"
}

##
# @brief Test format_version_info_short with arbitrary format
#
test_format_version_info_short_other() {
	result=$(format_version_info_short "some_other_value")
	assertEquals "some_other_value" "$result"
}

# ============================================================================
# Phase 6: Temporary File/Directory Handling Tests
# ============================================================================

##
# @brief Test _shtracer_tmp_base_dir returns TMPDIR when set
#
test_shtracer_tmp_base_dir_with_tmpdir() {
	# Save original TMPDIR
	_orig_tmpdir="${TMPDIR:-}"

	# Set custom TMPDIR
	export TMPDIR="$TEMP_DIR/custom_tmp"
	mkdir -p "$TMPDIR"

	result=$(_shtracer_tmp_base_dir)
	assertEquals "$TEMP_DIR/custom_tmp" "$result"

	# Restore original TMPDIR
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test _shtracer_tmp_base_dir returns /tmp when TMPDIR is unset
#
test_shtracer_tmp_base_dir_default() {
	# Save and unset TMPDIR
	_orig_tmpdir="${TMPDIR:-}"
	unset TMPDIR

	result=$(_shtracer_tmp_base_dir)
	assertEquals "/tmp" "$result"

	# Restore original TMPDIR
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	fi
}

##
# @brief Test _shtracer_tmp_base_dir strips trailing slash from TMPDIR
#
test_shtracer_tmp_base_dir_strips_trailing_slash() {
	_orig_tmpdir="${TMPDIR:-}"

	export TMPDIR="$TEMP_DIR/custom_tmp/"
	mkdir -p "$TEMP_DIR/custom_tmp"

	result=$(_shtracer_tmp_base_dir)
	assertEquals "$TEMP_DIR/custom_tmp" "$result"

	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile creates a file successfully
#
test_shtracer_tmpfile_creates_file() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpfile)
	status=$?

	assertEquals "shtracer_tmpfile should return success" 0 "$status"
	assertTrue "File should exist: $result" "[ -f '$result' ]"

	# Cleanup
	rm -f "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile creates unique files
#
test_shtracer_tmpfile_unique_files() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	file1=$(shtracer_tmpfile)
	file2=$(shtracer_tmpfile)

	assertNotEquals "Files should have unique paths" "$file1" "$file2"

	# Cleanup
	rm -f "$file1" "$file2"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile creates files with secure permissions (0600)
#
test_shtracer_tmpfile_secure_permissions() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpfile)

	# Get file permissions (platform-independent approach)
	if stat -c '%a' "$result" >/dev/null 2>&1; then
		# GNU stat (Linux)
		perms=$(stat -c '%a' "$result")
	else
		# BSD stat (macOS)
		perms=$(stat -f '%Lp' "$result")
	fi

	assertEquals "File permissions should be 600" "600" "$perms"

	# Cleanup
	rm -f "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile uses custom TMPDIR
#
test_shtracer_tmpfile_uses_tmpdir() {
	_orig_tmpdir="${TMPDIR:-}"

	custom_tmp="$TEMP_DIR/my_custom_tmp"
	mkdir -p "$custom_tmp"
	export TMPDIR="$custom_tmp"

	result=$(shtracer_tmpfile)

	# Verify file is in custom TMPDIR
	case "$result" in
		"$custom_tmp"/*) assertTrue "File should be in TMPDIR" true ;;
		*) fail "File should be in $custom_tmp, got: $result" ;;
	esac

	# Cleanup
	rm -f "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile file naming pattern
#
test_shtracer_tmpfile_naming_pattern() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpfile)

	# Filename should match pattern: shtracer.<pid>.<counter>
	filename=$(basename "$result")
	case "$filename" in
		shtracer.*.*)
			assertTrue "Filename matches expected pattern" true
			;;
		*)
			fail "Filename should match 'shtracer.<pid>.<n>' pattern, got: $filename"
			;;
	esac

	# Cleanup
	rm -f "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile concurrent creation (sequential for testing)
#
test_shtracer_tmpfile_sequential_creation() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	# Create multiple temp files in sequence
	files=""
	for _ in 1 2 3 4 5; do
		file=$(shtracer_tmpfile)
		files="$files $file"
	done

	# Verify all files exist and are unique
	count=0
	for file in $files; do
		assertTrue "File should exist: $file" "[ -f '$file' ]"
		count=$((count + 1))
	done
	assertEquals "Should have created 5 files" 5 "$count"

	# Cleanup
	for file in $files; do
		rm -f "$file"
	done
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir creates a directory successfully
#
test_shtracer_tmpdir_creates_directory() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpdir)
	status=$?

	assertEquals "shtracer_tmpdir should return success" 0 "$status"
	assertTrue "Directory should exist: $result" "[ -d '$result' ]"

	# Cleanup
	rmdir "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir creates unique directories
#
test_shtracer_tmpdir_unique_directories() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	dir1=$(shtracer_tmpdir)
	dir2=$(shtracer_tmpdir)

	assertNotEquals "Directories should have unique paths" "$dir1" "$dir2"

	# Cleanup
	rmdir "$dir1" "$dir2"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir creates directories with secure permissions (0700)
#
test_shtracer_tmpdir_secure_permissions() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpdir)

	# Get directory permissions (platform-independent approach)
	if stat -c '%a' "$result" >/dev/null 2>&1; then
		# GNU stat (Linux)
		perms=$(stat -c '%a' "$result")
	else
		# BSD stat (macOS)
		perms=$(stat -f '%Lp' "$result")
	fi

	assertEquals "Directory permissions should be 700" "700" "$perms"

	# Cleanup
	rmdir "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir directory naming pattern (ends with .d)
#
test_shtracer_tmpdir_naming_pattern() {
	_orig_tmpdir="${TMPDIR:-}"
	export TMPDIR="$TEMP_DIR"

	result=$(shtracer_tmpdir)

	# Directory name should match pattern: shtracer.<pid>.<counter>.d
	dirname=$(basename "$result")
	case "$dirname" in
		shtracer.*.*.d)
			assertTrue "Directory name matches expected pattern" true
			;;
		*)
			fail "Directory should match 'shtracer.<pid>.<n>.d' pattern, got: $dirname"
			;;
	esac

	# Cleanup
	rmdir "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir uses custom TMPDIR
#
test_shtracer_tmpdir_uses_tmpdir() {
	_orig_tmpdir="${TMPDIR:-}"

	custom_tmp="$TEMP_DIR/my_custom_tmp_dir"
	mkdir -p "$custom_tmp"
	export TMPDIR="$custom_tmp"

	result=$(shtracer_tmpdir)

	# Verify directory is in custom TMPDIR
	case "$result" in
		"$custom_tmp"/*) assertTrue "Directory should be in TMPDIR" true ;;
		*) fail "Directory should be in $custom_tmp, got: $result" ;;
	esac

	# Cleanup
	rmdir "$result"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpfile handles permission denied gracefully
# @note  Creates read-only directory and verifies function fails appropriately
#
test_shtracer_tmpfile_permission_denied() {
	_orig_tmpdir="${TMPDIR:-}"

	# Create a read-only directory
	readonly_dir="$TEMP_DIR/readonly_tmp"
	mkdir -p "$readonly_dir"
	chmod 500 "$readonly_dir"
	export TMPDIR="$readonly_dir"

	# Attempt to create tmpfile (should fail)
	result=$(shtracer_tmpfile 2>/dev/null)
	exit_code=$?

	# Should fail with non-zero exit code
	assertNotEquals "Should fail with permission denied" 0 "$exit_code"
	assertEquals "Should return empty string on failure" "" "$result"

	# Cleanup
	chmod 700 "$readonly_dir"
	rmdir "$readonly_dir"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir handles permission denied gracefully
# @note  Creates read-only directory and verifies function fails appropriately
#
test_shtracer_tmpdir_permission_denied() {
	_orig_tmpdir="${TMPDIR:-}"

	# Create a read-only directory
	readonly_dir="$TEMP_DIR/readonly_tmp"
	mkdir -p "$readonly_dir"
	chmod 500 "$readonly_dir"
	export TMPDIR="$readonly_dir"

	# Attempt to create tmpdir (should fail)
	result=$(shtracer_tmpdir 2>/dev/null)
	exit_code=$?

	# Should fail with non-zero exit code
	assertNotEquals "Should fail with permission denied" 0 "$exit_code"
	assertEquals "Should return empty string on failure" "" "$result"

	# Cleanup
	chmod 700 "$readonly_dir"
	rmdir "$readonly_dir"
	if [ -n "$_orig_tmpdir" ]; then
		export TMPDIR="$_orig_tmpdir"
	else
		unset TMPDIR
	fi
}

##
# @brief Test shtracer_tmpdir Windows path compatibility
# @note  Verifies paths work in MSYS2/Git Bash environments
#
test_shtracer_tmpdir_windows_path_compatibility() {
	result=$(shtracer_tmpdir)

	# Verify directory was created
	assertTrue "Directory should exist" "[ -d '$result' ]"

	# Verify path doesn't contain backslashes (POSIX requirement)
	case "$result" in
		*\\*)
			fail "Path should not contain backslashes: $result"
			;;
		*)
			assertTrue "Path is POSIX-compliant" true
			;;
	esac

	# Verify path is absolute
	case "$result" in
		/*)
			assertTrue "Path is absolute" true
			;;
		*)
			fail "Path should be absolute, got: $result"
			;;
	esac

	# Cleanup
	rmdir "$result"
}

##
# @brief Test shtracer_tmpdir prevents symlink attacks
# @note  Verifies that existing symlinks don't cause security issues
#
test_shtracer_tmpdir_symlink_attack_prevention() {
	_tmp_base="$(_shtracer_tmp_base_dir)"

	# Create a target directory for symlink
	attack_target="$TEMP_DIR/attack_target"
	mkdir -p "$attack_target"

	# Pre-create first possible tmpdir path as a symlink
	symlink_path="${_tmp_base%/}/shtracer.$$.0.d"
	ln -s "$attack_target" "$symlink_path" 2>/dev/null || {
		# If symlink creation fails, skip test
		rmdir "$attack_target"
		startSkipping
		return
	}

	# Try to create tmpdir (should skip the symlink and use next index)
	result=$(shtracer_tmpdir)

	# Verify result is NOT the symlink
	assertNotEquals "Should not use existing symlink" "$symlink_path" "$result"

	# Verify result is a real directory, not a symlink
	assertTrue "Result should be a directory" "[ -d '$result' ]"
	assertFalse "Result should not be a symlink" "[ -L '$result' ]"

	# Verify it's index 1, not 0
	case "$result" in
		*shtracer.$$.1.d)
			assertTrue "Should use next available index" true
			;;
		*)
			fail "Should have used index 1, got: $result"
			;;
	esac

	# Cleanup
	rm -f "$symlink_path"
	rmdir "$attack_target"
	rmdir "$result"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
