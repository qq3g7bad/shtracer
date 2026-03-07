#!/bin/sh
# Unit tests for cross-reference functions
# Tests shtracer_crossref.sh: swap_tags, _extract_layer_hierarchy,
#   _generate_cross_reference_matrix, make_cross_reference_tables

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
# shellcheck source=../../main/shtracer_crossref.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_crossref.sh"
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (Cross-Reference Functions)"
}

setUp() {
	set +u
	SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_SEPARATOR
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="${TEST_ROOT%/}/shtracer_output/"
	export CONFIG_DIR=""
	rm -rf "$OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"
	TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'shtracer_test')"
	export TEMP_DIR
	cd "${TEST_ROOT}" || exit 1
}

tearDown() {
	rm -rf "$OUTPUT_DIR"
	if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
		rm -rf "$TEMP_DIR"
	fi
}

# ============================================================================
# _extract_layer_hierarchy tests
# ============================================================================

test_extract_layer_hierarchy_basic() {
	_config_table="$TEMP_DIR/config_table"
	# Create a config table with two layers (8 fields separated by <shtracer_separator>)
	# shellcheck disable=SC2016  # Backticks in single quotes are intentional (literal tag format)
	printf ':Requirement%s"./req.md"%s%s%s"Requirements"%s`@REQ[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >"$_config_table"
	# shellcheck disable=SC2016
	printf ':Architecture%s"./arc.md"%s%s%s"Architecture"%s`@ARC[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >>"$_config_table"

	_result=$(_extract_layer_hierarchy "$_config_table")
	_line_count=$(echo "$_result" | wc -l | tr -d ' ')
	assertEquals "Should extract 2 layers" "2" "$_line_count"
	echo "$_result" | grep -q "Requirement" || fail "Should contain Requirement layer"
	echo "$_result" | grep -q "Architecture" || fail "Should contain Architecture layer"
}

test_extract_layer_hierarchy_empty_tag_format() {
	_config_table="$TEMP_DIR/config_table_no_tag"
	# Section with no TAG FORMAT (field 6 is empty)
	printf ':Docs%s"./docs/"%s%s%s"Documentation"%s%s%s\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >"$_config_table"

	_result=$(_extract_layer_hierarchy "$_config_table")
	assertEquals "Should return empty for no TAG FORMAT" "" "$_result"
}

test_extract_layer_hierarchy_deduplicates() {
	_config_table="$TEMP_DIR/config_table_dedup"
	# Two sections sharing the same TAG FORMAT
	# shellcheck disable=SC2016
	printf ':Req:Part1%s"./req1.md"%s%s%s"Part 1"%s`@REQ[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >"$_config_table"
	# shellcheck disable=SC2016
	printf ':Req:Part2%s"./req2.md"%s%s%s"Part 2"%s`@REQ[0-9\\.]+@`%s`<!--.*-->`%s1\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >>"$_config_table"

	_result=$(_extract_layer_hierarchy "$_config_table")
	_line_count=$(echo "$_result" | wc -l | tr -d ' ')
	assertEquals "Duplicate TAG FORMAT should be deduplicated" "1" "$_line_count"
}

test_extract_layer_hierarchy_unreadable_file() {
	_result=$(_extract_layer_hierarchy "/nonexistent/path")
	_exit=$?
	assertEquals "Should return error for unreadable file" 1 "$_exit"
}

test_extract_layer_hierarchy_nested_heading() {
	_config_table="$TEMP_DIR/config_table_nested"
	# Nested heading like :Main:Implementation
	# shellcheck disable=SC2016
	printf ':Main:Implementation%s"./src/"%s"*.sh"%s%s"Impl"%s`@IMP[0-9\\.]+@`%s`#.*`%s1\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" >"$_config_table"

	_result=$(_extract_layer_hierarchy "$_config_table")
	# Should extract last segment: "Implementation"
	echo "$_result" | grep -q "Implementation" || fail "Should extract last segment of nested heading"
}

# ============================================================================
# _generate_cross_reference_matrix tests
# ============================================================================

test_generate_matrix_basic() {
	_tags_file="$TEMP_DIR/01_tags"
	_pairs_file="$TEMP_DIR/02_tag_pairs"
	_output_file="$TEMP_DIR/matrix_output"

	# Create tags file (fields: trace_target, tag_id, from_tags, description, file_path, line_num)
	{
		printf ':Requirement%s@REQ1.1@%s%s%sReq 1%s/path/req.md%s10\n' \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR"
		printf ':Architecture%s@ARC2.1@%s@REQ1.1@%s%sArc 1%s/path/arc.md%s20\n' \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR"
	} >"$_tags_file"

	# Create pairs file (space-separated: parent child)
	echo "@REQ1.1@ @ARC2.1@" >"$_pairs_file"

	_generate_cross_reference_matrix "$_tags_file" "$_pairs_file" \
		'@REQ[0-9.]+@' '@ARC[0-9.]+@' "$_output_file"

	assertTrue "Output file should be created" "[ -f '$_output_file' ]"
	grep -q '\[METADATA\]' "$_output_file" || fail "Should contain METADATA section"
	grep -q '\[ROW_TAGS\]' "$_output_file" || fail "Should contain ROW_TAGS section"
	grep -q '\[COL_TAGS\]' "$_output_file" || fail "Should contain COL_TAGS section"
	grep -q '\[MATRIX\]' "$_output_file" || fail "Should contain MATRIX section"
	grep -q '@REQ1.1@' "$_output_file" || fail "Should contain row tag"
	grep -q '@ARC2.1@' "$_output_file" || fail "Should contain column tag"
}

test_generate_matrix_no_matches() {
	_tags_file="$TEMP_DIR/01_tags_empty"
	_pairs_file="$TEMP_DIR/02_pairs_empty"
	_output_file="$TEMP_DIR/matrix_empty"

	printf ':Requirement%s@REQ1.1@%s%s%sReq%s/path/req.md%s10\n' \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
		"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" >"$_tags_file"
	: >"$_pairs_file"

	_generate_cross_reference_matrix "$_tags_file" "$_pairs_file" \
		'@REQ[0-9.]+@' '@ARC[0-9.]+@' "$_output_file"

	assertTrue "Output file should be created even with no matches" "[ -f '$_output_file' ]"
}

test_generate_matrix_unreadable_input() {
	_result=$(_generate_cross_reference_matrix "/nonexistent" "/also_nonexistent" \
		'@REQ[0-9.]+@' '@ARC[0-9.]+@' "$TEMP_DIR/out" 2>&1)
	assertEquals "Should return error for unreadable files" 1 $?
}

# ============================================================================
# swap_tags tests
# ============================================================================

test_swap_tags_basic() {
	(
		# Set up a minimal config table and target file
		CONFIG_DIR="$TEMP_DIR"
		_config_table="$TEMP_DIR/config_table"
		_target_file="$TEMP_DIR/source.md"

		# Create target file with tags
		cat >"$_target_file" <<'EOF'
<!-- @TAG_OLD@ -->
Some content
<!-- @TAG_NEW@ (FROM: @TAG_OLD@) -->
EOF

		# Create config table pointing to target file
		# shellcheck disable=SC2016
		printf '%s%s"%s"%s%s%s%s`@TAG_[A-Z]+@`%s`<!--.*-->`%s1\n' \
			":Section" \
			"$SHTRACER_SEPARATOR" "$_target_file" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" >"$_config_table"

		swap_tags "$_config_table" "@TAG_OLD@" "@TAG_RENAMED@"
		_exit=$?
		assertEquals "swap_tags should succeed" 0 "$_exit"

		# Verify the swap occurred
		grep -q "@TAG_RENAMED@" "$_target_file" || fail "Should contain renamed tag"
	)
}

test_swap_tags_missing_config() {
	(
		_result=$(swap_tags "/nonexistent/config" "@OLD@" "@NEW@" 2>&1 || true)
		echo "$_result" | grep -q "Cannot find" || fail "Should report missing config"
	)
}

test_swap_tags_bidirectional() {
	(
		# Swap should be bidirectional: OLD->NEW and NEW->OLD
		CONFIG_DIR="$TEMP_DIR"
		_config_table="$TEMP_DIR/config_table_swap"
		_target_file="$TEMP_DIR/swap_test.md"

		cat >"$_target_file" <<'EOF'
@ALPHA@ references @BETA@
@BETA@ is independent
EOF

		# shellcheck disable=SC2016
		printf '%s%s"%s"%s%s%s%s`@[A-Z]+@`%s`.*`%s1\n' \
			":Section" \
			"$SHTRACER_SEPARATOR" "$_target_file" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" >"$_config_table"

		swap_tags "$_config_table" "@ALPHA@" "@BETA@"

		_content="$(cat "$_target_file")"
		_line1="$(echo "$_content" | head -1)"
		_line2="$(echo "$_content" | sed -n '2p')"

		# After swap: ALPHA->BETA and BETA->ALPHA
		assertEquals "@BETA@ references @ALPHA@" "$_line1"
		assertEquals "@ALPHA@ is independent" "$_line2"
	)
}

# ============================================================================
# make_cross_reference_tables tests
# ============================================================================

test_make_cross_reference_tables_unreadable_files() {
	_result=$(make_cross_reference_tables "/nonexistent" "/nonexistent" "/nonexistent" 2>&1)
	_exit=$?
	assertEquals "Should return error for unreadable files" 1 "$_exit"
}

test_make_cross_reference_tables_no_layers() {
	(
		mkdir -p "${OUTPUT_DIR%/}/tags/"
		# Config table with no TAG FORMAT
		_config_table="$TEMP_DIR/config_no_layers"
		printf ':Docs%s"./docs/"%s%s%s"Documentation"%s%s%s\n' \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" "$SHTRACER_SEPARATOR" \
			"$SHTRACER_SEPARATOR" >"$_config_table"

		_tags_file="$TEMP_DIR/01_tags_empty"
		_pairs_file="$TEMP_DIR/02_pairs_empty"
		: >"$_tags_file"
		: >"$_pairs_file"

		_result=$(make_cross_reference_tables "$_config_table" "$_tags_file" "$_pairs_file" 2>/dev/null)
		_exit=$?
		assertEquals "Should succeed even with no layers" 0 "$_exit"
	)
}

# ============================================================================
# _generate_markdown_table tests
# ============================================================================

test_generate_markdown_table_basic() {
	_matrix_file="$TEMP_DIR/matrix_for_md"
	_output_md="$TEMP_DIR/output.md"

	# Create a minimal intermediate matrix file
	cat >"$_matrix_file" <<EOF
[METADATA]
@REQ[0-9.]+@<shtracer_separator>@ARC[0-9.]+@<shtracer_separator>2026-01-01 00:00:00 UTC

[ROW_TAGS]
@REQ1.1@<shtracer_separator>/path/req.md<shtracer_separator>10

[COL_TAGS]
@ARC2.1@<shtracer_separator>/path/arc.md<shtracer_separator>20

[MATRIX]
@REQ1.1@<shtracer_separator>@ARC2.1@
EOF

	_generate_markdown_table "$_matrix_file" "" "$_output_md"
	assertTrue "Markdown output should be created" "[ -f '$_output_md' ]"
	grep -q "Cross-Reference Table" "$_output_md" || fail "Should contain table title"
	grep -q "@REQ1.1@" "$_output_md" || fail "Should contain row tag"
	grep -q "@ARC2.1@" "$_output_md" || fail "Should contain column tag"
	grep -q "Statistics" "$_output_md" || fail "Should contain statistics"
}

test_generate_markdown_table_unreadable() {
	_result=$(_generate_markdown_table "/nonexistent" "" "$TEMP_DIR/out.md" 2>&1)
	assertEquals "Should return error for unreadable matrix" 1 $?
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
