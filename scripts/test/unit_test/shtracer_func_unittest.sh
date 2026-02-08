#!/bin/sh

# Source test target
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi

TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_func.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_func.sh"
# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"

##
# @brief
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " UNIT TEST (Core Functions) : $0"
	echo "----------------------------------------"
}

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="${TEST_ROOT%/}/shtracer_output/"
	export CONFIG_DIR="${TEST_ROOT%/}/unit_test/testdata/"
	SCRIPT_DIR="$SHTRACER_ROOT_DIR"
	rm -rf "$OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"
	cd "${TEST_ROOT}" || exit 1
}

##
# @brief TearDown function for each test
#
tearDown() {
	rm -rf "$OUTPUT_DIR"
}

##
# @brief  Test for check_configfile
# @tag    @UT2.1@ (FROM: @IMP2.1@)
test_check_configfile() {
	(
		# Arrange ---------

		# Act -------------

		_RETURN_VALUE="$(check_configfile "./unit_test/testdata/config_minimal_single_file.md")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/config/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_config_table" "${_RETURN_VALUE##*/}"

		# config table
		_ANSWER="$(cat ./unit_test/testdata/expected/config/config_table)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/config/01_config_table")"
		assertEquals "$_ANSWER" "$_TEST_DATA"
	)
}

##
# @brief  Test for extract_tags
# @tag    @UT2.2@ (FROM: @IMP2.2@)
test_extract_tags_without_argument() {
	(
		# Arrange ---------
		# Act -------------

		_RETURN_VALUE="$(extract_tags 2>&1)"

		# Assert ----------
		assertEquals 1 "$?"

		# mkdir
		assertEquals 0 "$(
			[ ! -d "${OUTPUT_DIR%/}/tags/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "[shtracer_func_unittest.sh][error][extract_tags]: Cannot find a config output data." "${_RETURN_VALUE##*/}"
	)
}

##
# @brief  Test for extract_tags
# @tag    @UT2.3@ (FROM: @IMP2.2@)
test_extract_tags() {
	(
		# Arrange ---------
		# shellcheck disable=SC2030  # Intentional subshell modification for test isolation
		export CONFIG_DIR="${TEST_ROOT%/}/unit_test/testdata/"

		# Act -------------

		_RETURN_VALUE="$(extract_tags "./unit_test/testdata/expected/config/config_table")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/tags/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_tags" "${_RETURN_VALUE##*/}"

		# Level1
		# Compare only first 7 fields (exclude git version info which is environment-dependent)
		_ANSWER="$(awk <"./unit_test/testdata/expected/tags/tags" -F"$SHTRACER_SEPARATOR" '
			BEGIN{OFS="'"$SHTRACER_SEPARATOR"'"}
			{
				cmd	=	"basename	\""$5"\"";	cmd	|	getline	filename_result;	close(cmd)
				cmd	=	"dirname	\""$5"\"";	cmd	|	getline	dirname_result;	close(cmd)
				cmd	=	"cd	\"'"$CONFIG_DIR"'\";cd	"dirname_result";PWD=\"$(pwd)\";	\
					echo	\"${PWD%/}/\"";	cmd	|	getline	absolute_path;	close(cmd)
				$5	=	absolute_path	filename_result
				# Print only first 7 fields (excluding field 8: git version)
				printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n", $1, OFS, $2, OFS, $3, OFS, $4, OFS, $5, OFS, $6, OFS, $7
			}')"
		_TEST_DATA="$(awk <"${OUTPUT_DIR%/}/tags/01_tags" -F"$SHTRACER_SEPARATOR" '
			BEGIN{OFS="'"$SHTRACER_SEPARATOR"'"}
			{
				# Print only first 7 fields (excluding field 8: git version)
				printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n", $1, OFS, $2, OFS, $3, OFS, $4, OFS, $5, OFS, $6, OFS, $7
			}')"
		assertEquals "$_ANSWER" "$_TEST_DATA"
	)
}

##
# @brief  Test for join_tag_pairs without arguments
# @tag    @UT2.4@ (FROM: @IMP2.4@)
test_join_tag_pairs_without_argument() {
	# Arrange ---------
	# Act -------------
	join_tag_pairs >/dev/null 2>&1
	# Assert ----------
	assertEquals 1 "$?"
}

##
# @brief  Test for join_tag_pairs with valid arguments
# @tag    @UT2.4.1@ (FROM: @IMP2.4@)
test_join_tag_pairs_with_valid_arguments() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/tags"
		echo "@TAG1@" >"$OUTPUT_DIR/tags/test_table"
		echo "@TAG1@ @TAG2@" >"$OUTPUT_DIR/tags/test_downstream"

		# Act -------------
		join_tag_pairs "$OUTPUT_DIR/tags/test_table" "$OUTPUT_DIR/tags/test_downstream"
		_RESULT="$(cat "$OUTPUT_DIR/tags/test_table")"

		# Assert ----------
		assertEquals 0 "$?"
		assertNotEquals "" "$_RESULT"
	)
}

##
# @brief  Test for join_tag_pairs with non-existent file
# @tag    @UT2.4.2@ (FROM: @IMP2.4@)
test_join_tag_pairs_with_non_existent_file() {
	(
		# Arrange ---------
		# Act -------------
		join_tag_pairs "non_existent1" "non_existent2" >/dev/null 2>&1

		# Assert ----------
		assertEquals 1 "$?"
	)
}

##
# @brief  Test for join_tag_pairs with circular reference
# @tag    @UT2.4.3@ (FROM: @IMP2.4@)
test_join_tag_pairs_with_circular_reference() {
	(
		# Arrange ---------
		# Create a circular reference scenario
		# TAG1 -> TAG2 -> TAG1 (circular)
		mkdir -p "$OUTPUT_DIR/tags"
		echo "@TAG1@" >"$OUTPUT_DIR/tags/test_table_circular"
		{
			echo "@TAG1@ @TAG2@"
			echo "@TAG2@ @TAG1@"
		} >"$OUTPUT_DIR/tags/test_downstream_circular"

		# Act -------------
		join_tag_pairs "$OUTPUT_DIR/tags/test_table_circular" "$OUTPUT_DIR/tags/test_downstream_circular" 2>"$OUTPUT_DIR/error_output.txt"
		_EXIT_CODE=$?
		_ERROR_OUTPUT="$(cat "$OUTPUT_DIR/error_output.txt")"

		# Assert ----------
		assertEquals 1 "$_EXIT_CODE"
		assertContains "$_ERROR_OUTPUT" "Circular reference detected"
	)
}

##
# @brief  Test for join_tag_pairs with deep recursion but no circular reference
# @tag    @UT2.4.4@ (FROM: @IMP2.4@)
test_join_tag_pairs_with_deep_recursion() {
	(
		# Arrange ---------
		# Create a deep but valid chain: TAG1 -> TAG2 -> TAG3 -> TAG4 -> TAG5
		mkdir -p "$OUTPUT_DIR/tags"
		echo "@TAG1@" >"$OUTPUT_DIR/tags/test_table_deep"
		{
			echo "@TAG1@ @TAG2@"
			echo "@TAG2@ @TAG3@"
			echo "@TAG3@ @TAG4@"
			echo "@TAG4@ @TAG5@"
		} >"$OUTPUT_DIR/tags/test_downstream_deep"

		# Act -------------
		join_tag_pairs "$OUTPUT_DIR/tags/test_table_deep" "$OUTPUT_DIR/tags/test_downstream_deep" 2>/dev/null
		_EXIT_CODE=$?
		_RESULT="$(cat "$OUTPUT_DIR/tags/test_table_deep")"

		# Assert ----------
		assertEquals 0 "$_EXIT_CODE"
		assertContains "$_RESULT" "@TAG1@"
		assertContains "$_RESULT" "@TAG5@"
	)
}

##
# @brief  Test for make_tag_table
# @tag    @UT2.5@ (FROM: @IMP2.3@)
test_make_tag_table() {
	(
		# Arrange ---------
		# Act -------------
		make_tag_table "./unit_test/testdata/expected/tags/tags" >/dev/null

		# Assert ----------
		assertEquals 0 "$?"

		_ANSWER="$(cat ./unit_test/testdata/expected/tags/tag_table)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/tags/04_tag_table")"
	)
}

##
# @brief  Test for make_tag_table
# @tag    @UT2.6@ (FROM: @IMP2.3@)
test_make_tag_table_without_argument() {
	(
		# Arrange ---------
		# Act -------------
		(make_tag_table >/dev/null 2>&1)

		# Assert ----------
		assertEquals 1 "$?"
	)
}

##
# @brief  Test for make_tag_table
# @tag    @UT2.7@ (FROM: @IMP2.3@)
test_make_tag_table_with_empty_file() {
	(
		# Arrange ---------
		# Act -------------
		(make_tag_table "./unit_test/testdata/empty" >/dev/null 2>&1)

		# Assert ----------
		assertEquals 1 "$?"
	)
}

##
# @brief  Test for swap_tags without arguments
# @tag    @UT2.8@ (FROM: @IMP2.6@)
test_swap_tags_without_arguments() {
	(
		# Arrange ---------
		# Act -------------
		(swap_tags "" "" "" >/dev/null 2>&1)

		# Assert ----------
		assertEquals 1 "$?"
	)
}

##
# @brief  Test for swap_tags with non-existent file
# @tag    @UT2.9@ (FROM: @IMP2.6@)
test_swap_tags_with_non_existent_file() {
	# Arrange ---------
	# Act -------------
	# swap_tags calls error_exit which exits the subshell
	# We need to catch this in a separate process
	(swap_tags "non_existent_file" "@TAG1@" "@TAG2@" >/dev/null 2>&1)
	_EXIT_CODE=$?

	# Assert ----------
	assertEquals 1 "$_EXIT_CODE"
}

##
# @brief  Test for swap_tags with valid arguments
# @tag    @UT2.10@ (FROM: @IMP2.6@)
test_swap_tags_with_valid_arguments() {
	(
		# Arrange ---------
		# shellcheck disable=SC2031  # CONFIG_DIR modification is intentional in test subshell
		_ORIGINAL_CONFIG_DIR="$CONFIG_DIR"
		mkdir -p "$OUTPUT_DIR/test_swap/testdata"
		CONFIG_DIR="$OUTPUT_DIR/test_swap"

		# Create test file with tags
		echo "<!-- @OLD_TAG@ -->" >"$OUTPUT_DIR/test_swap/testdata/testswap.md"
		echo "Test content" >>"$OUTPUT_DIR/test_swap/testdata/testswap.md"
		echo "<!-- @OLD_TAG@ -->" >>"$OUTPUT_DIR/test_swap/testdata/testswap.md"

		# Create test config table
		echo ":Test${SHTRACER_SEPARATOR}testdata/testswap.md${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}${SHTRACER_SEPARATOR}" >"$OUTPUT_DIR/test_swap/config_table"

		# Act -------------
		swap_tags "$OUTPUT_DIR/test_swap/config_table" "@OLD_TAG@" "@NEW_TAG@"
		_RESULT="$(cat "$OUTPUT_DIR/test_swap/testdata/testswap.md")"

		# Assert ----------
		CONFIG_DIR="$_ORIGINAL_CONFIG_DIR"
		assertEquals 0 "$?"
		assertNotEquals "" "$(echo "$_RESULT" | grep "@NEW_TAG@")"
		assertEquals "" "$(echo "$_RESULT" | grep "@OLD_TAG@")"
	)
}

##
# @brief  Test for print_verification_result with no errors
# @tag    @UT2.11@ (FROM: @IMP2.5@)
test_print_verification_result_no_errors() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		touch "$OUTPUT_DIR/verified/isolated"
		touch "$OUTPUT_DIR/verified/duplicated"
		touch "$OUTPUT_DIR/verified/dangling"
		touch "$OUTPUT_DIR/verified/tag_data"

		# Act -------------
		_output=$(print_verification_result "$OUTPUT_DIR/verified/tag_data" "$OUTPUT_DIR/verified/isolated" "$OUTPUT_DIR/verified/duplicated" "$OUTPUT_DIR/verified/dangling" 2>&1)

		# Assert ----------
		# No errors should be printed
		assertEquals "" "$_output"
	)
}

##
# @brief  Test for print_verification_result with isolated tags
# @tag    @UT2.12@ (FROM: @IMP2.5@)
test_print_verification_result_with_isolated() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		echo "NONE @ISOLATED_TAG@ /path/file.sh 42" >"$OUTPUT_DIR/verified/isolated"
		touch "$OUTPUT_DIR/verified/duplicated"
		touch "$OUTPUT_DIR/verified/dangling"
		touch "$OUTPUT_DIR/verified/tag_data"

		# Act -------------
		_output=$(print_verification_result "$OUTPUT_DIR/verified/tag_data" "$OUTPUT_DIR/verified/isolated" "$OUTPUT_DIR/verified/duplicated" "$OUTPUT_DIR/verified/dangling" 2>&1)

		# Assert ----------
		# Should print one-line error for isolated tag
		echo "$_output" | grep -q '\[shtracer\]\[error\]\[isolated_tags\] @ISOLATED_TAG@ /path/file.sh 42'
		assertEquals 0 "$?"
	)
}

##
# @brief  Test for print_verification_result with duplicated tags
# @tag    @UT2.13@ (FROM: @IMP2.5@)
test_print_verification_result_with_duplicated() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		touch "$OUTPUT_DIR/verified/isolated"
		echo "@DUPLICATE_TAG@" >"$OUTPUT_DIR/verified/duplicated"
		touch "$OUTPUT_DIR/verified/dangling"

		# Create tag data with two occurrences of @DUPLICATE_TAG@
		cat >"$OUTPUT_DIR/verified/tag_data" <<EOF
Requirement${SHTRACER_SEPARATOR}@DUPLICATE_TAG@${SHTRACER_SEPARATOR}NONE${SHTRACER_SEPARATOR}Desc${SHTRACER_SEPARATOR}/path/file1.sh${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}v1
Requirement${SHTRACER_SEPARATOR}@DUPLICATE_TAG@${SHTRACER_SEPARATOR}NONE${SHTRACER_SEPARATOR}Desc${SHTRACER_SEPARATOR}/path/file2.sh${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_output=$(print_verification_result "$OUTPUT_DIR/verified/tag_data" "$OUTPUT_DIR/verified/isolated" "$OUTPUT_DIR/verified/duplicated" "$OUTPUT_DIR/verified/dangling" 2>&1)

		# Assert ----------
		# Should print two one-line errors for duplicate tag (one per occurrence)
		_count=$(echo "$_output" | grep -c '\[duplicated_tags\] @DUPLICATE_TAG@')
		assertEquals 2 "$_count"
	)
}

##
# @brief  Test for _verify_dangling_fromtags with valid references
# @tag    @UT2.14@
test_verify_dangling_fromtags_no_dangling() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		# Create a tag file with valid references
		# Format: trace_target<SEP>tag_id<SEP>from_tags<SEP>description<SEP>file<SEP>line<SEP>...
		_TAG_FILE="$OUTPUT_DIR/tag_data"
		_OUTPUT_FILE="$OUTPUT_DIR/verified/dangling"
		cat >"$_TAG_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Implementation${SHTRACER_SEPARATOR}@IMP1@${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}Impl 1${SHTRACER_SEPARATOR}impl.sh${SHTRACER_SEPARATOR}30${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_verify_dangling_fromtags "$_TAG_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have no dangling references
		assertEquals "0" "$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')"
	)
}

##
# @brief  Test for _verify_dangling_fromtags with dangling reference
# @tag    @UT2.15@
test_verify_dangling_fromtags_with_dangling() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		_TAG_FILE="$OUTPUT_DIR/tag_data"
		_OUTPUT_FILE="$OUTPUT_DIR/verified/dangling"
		cat >"$_TAG_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ-MISSING@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_verify_dangling_fromtags "$_TAG_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have 1 dangling reference
		assertEquals "1" "$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')"
		# Check the output format: child_tag parent_tag file line
		_RESULT="$(cat "$_OUTPUT_FILE")"
		echo "$_RESULT" | grep -q "@ARC1@ @REQ-MISSING@ arch.md 20"
		assertEquals "0" "$?"
	)
}

##
# @brief  Test for _verify_dangling_fromtags with multiple dangling references
# @tag    @UT2.16@
test_verify_dangling_fromtags_multiple_dangling() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		_TAG_FILE="$OUTPUT_DIR/tag_data"
		_OUTPUT_FILE="$OUTPUT_DIR/verified/dangling"
		cat >"$_TAG_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ-MISSING@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Implementation${SHTRACER_SEPARATOR}@IMP1@${SHTRACER_SEPARATOR}@ARC-MISSING@${SHTRACER_SEPARATOR}Impl 1${SHTRACER_SEPARATOR}impl.sh${SHTRACER_SEPARATOR}30${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_verify_dangling_fromtags "$_TAG_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have 2 dangling references
		assertEquals "2" "$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')"
	)
}

##
# @brief  Test for _verify_dangling_fromtags with comma-separated FROM tags
# @tag    @UT2.17@
test_verify_dangling_fromtags_comma_separated() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		_TAG_FILE="$OUTPUT_DIR/tag_data"
		_OUTPUT_FILE="$OUTPUT_DIR/verified/dangling"
		cat >"$_TAG_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@, @REQ-MISSING@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_verify_dangling_fromtags "$_TAG_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have 1 dangling reference (@REQ-MISSING@)
		assertEquals "1" "$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')"
		_RESULT="$(cat "$_OUTPUT_FILE")"
		echo "$_RESULT" | grep -q "@ARC1@ @REQ-MISSING@ arch.md 20"
		assertEquals "0" "$?"
	)
}

##
# @brief  Test for _verify_dangling_fromtags with mixed valid and dangling
# @tag    @UT2.18@
test_verify_dangling_fromtags_mixed() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		_TAG_FILE="$OUTPUT_DIR/tag_data"
		_OUTPUT_FILE="$OUTPUT_DIR/verified/dangling"
		cat >"$_TAG_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Requirement${SHTRACER_SEPARATOR}@REQ2@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 2${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}15${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC2@${SHTRACER_SEPARATOR}@REQ2@, @REQ-MISSING@, @REQ-MISSING2@${SHTRACER_SEPARATOR}Arch 2${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}25${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Implementation${SHTRACER_SEPARATOR}@IMP1@${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}Impl 1${SHTRACER_SEPARATOR}impl.sh${SHTRACER_SEPARATOR}30${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		_verify_dangling_fromtags "$_TAG_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have 2 dangling references from @ARC2@
		assertEquals "2" "$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')"
	)
}

# ============================================================================
# File Version Tracking Tests (Phase 1.3)
# ============================================================================

##
# @brief Test create_file_versions_table with valid tags file
# @tag @UT2.8.1@
test_create_file_versions_table_valid() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/tags"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_OUTPUT_FILE="$OUTPUT_DIR/tags/05_file_versions"

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}git:abc1234
Requirement${SHTRACER_SEPARATOR}@REQ2@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 2${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}15${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}git:abc1234
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}git:def5678
EOF

		# Act -------------
		create_file_versions_table "$_TAGS_FILE" "$_OUTPUT_FILE"
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success" 0 "$_STATUS"
		assertTrue "Output file should exist" "[ -f '$_OUTPUT_FILE' ]"

		# Should have 2 unique file entries (req.md and arch.md)
		_LINE_COUNT=$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')
		assertEquals "Should have 2 unique files" 2 "$_LINE_COUNT"

		# Should contain version info
		grep -q "git:abc1234" "$_OUTPUT_FILE"
		assertEquals "Should contain git hash for req.md" 0 $?

		grep -q "git:def5678" "$_OUTPUT_FILE"
		assertEquals "Should contain git hash for arch.md" 0 $?
	)
}

##
# @brief Test create_file_versions_table with multiple files per layer
# @tag @UT2.8.2@
test_create_file_versions_table_multiple_files() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/tags"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_OUTPUT_FILE="$OUTPUT_DIR/tags/05_file_versions"

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req1.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Requirement${SHTRACER_SEPARATOR}@REQ2@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 2${SHTRACER_SEPARATOR}req2.md${SHTRACER_SEPARATOR}15${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v2
Requirement${SHTRACER_SEPARATOR}@REQ3@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 3${SHTRACER_SEPARATOR}req1.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Act -------------
		create_file_versions_table "$_TAGS_FILE" "$_OUTPUT_FILE"

		# Assert ----------
		# Should have 2 unique files (req1.md and req2.md)
		_LINE_COUNT=$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')
		assertEquals "Should have 2 unique files" 2 "$_LINE_COUNT"
	)
}

##
# @brief Test create_file_versions_table with empty tags file
# @tag @UT2.8.3@
test_create_file_versions_table_empty() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/tags"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_OUTPUT_FILE="$OUTPUT_DIR/tags/05_file_versions"
		touch "$_TAGS_FILE"

		# Act -------------
		create_file_versions_table "$_TAGS_FILE" "$_OUTPUT_FILE"
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success" 0 "$_STATUS"
		assertTrue "Output file should exist" "[ -f '$_OUTPUT_FILE' ]"

		# Should be empty
		_LINE_COUNT=$(wc -l <"$_OUTPUT_FILE" | tr -d ' ')
		assertEquals "Should have 0 lines" 0 "$_LINE_COUNT"
	)
}

##
# @brief Test create_file_versions_table with unreadable file
# @tag @UT2.8.4@
test_create_file_versions_table_unreadable() {
	# Arrange ---------
	mkdir -p "$OUTPUT_DIR/tags"
	_OUTPUT_FILE="$OUTPUT_DIR/tags/05_file_versions"

	# Act ----------
	# Run in subshell to capture exit code (error_exit calls exit)
	(create_file_versions_table "/nonexistent/file" "$_OUTPUT_FILE" 2>/dev/null)
	_STATUS=$?

	# Assert ----------
	assertNotEquals "Should return error" 0 "$_STATUS"
}

# ============================================================================
# Cross-Reference Table Generation Tests (Phase 1.2)
# ============================================================================

##
# @brief Test _extract_layer_hierarchy with simple config
# @tag @UT2.7.1@
test_extract_layer_hierarchy_simple() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"

		# Create minimal config table with two layers
		# Format: :Section<sep>path<sep>brief<sep>tag_line<sep>ext<sep>tag_format<sep>offset<sep>ignore
		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Requirements${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Architecture${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		# Act -------------
		_RESULT=$(_extract_layer_hierarchy "$_CONFIG_TABLE")

		# Assert ----------
		assertEquals "Should return success" 0 $?
		assertNotNull "Result should not be empty" "$_RESULT"

		# Should have two layers
		_LINE_COUNT=$(printf '%s\n' "$_RESULT" | wc -l | tr -d ' ')
		assertEquals "Should have 2 layers" 2 "$_LINE_COUNT"

		# Should contain Requirement layer
		echo "$_RESULT" | grep -q "Requirement"
		assertEquals "Should contain Requirement layer" 0 $?

		# Should contain Architecture layer
		echo "$_RESULT" | grep -q "Architecture"
		assertEquals "Should contain Architecture layer" 0 $?
	)
}

##
# @brief Test _extract_layer_hierarchy with three layers
# @tag @UT2.7.2@
test_extract_layer_hierarchy_three_layers() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Implementation${SHTRACER_SEPARATOR}./impl.sh${SHTRACER_SEPARATOR}Impl${SHTRACER_SEPARATOR}#.*${SHTRACER_SEPARATOR}*.sh${SHTRACER_SEPARATOR}\`@IMP[0-9\.]+@\`${SHTRACER_SEPARATOR}0${SHTRACER_SEPARATOR}
EOF

		# Act -------------
		_RESULT=$(_extract_layer_hierarchy "$_CONFIG_TABLE")

		# Assert ----------
		_LINE_COUNT=$(printf '%s\n' "$_RESULT" | wc -l | tr -d ' ')
		assertEquals "Should have 3 layers" 3 "$_LINE_COUNT"
	)
}

##
# @brief Test _extract_layer_hierarchy with empty config
# @tag @UT2.7.3@
test_extract_layer_hierarchy_empty_config() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		touch "$_CONFIG_TABLE"

		# Act -------------
		_RESULT=$(_extract_layer_hierarchy "$_CONFIG_TABLE")

		# Assert ----------
		assertEquals "Should return success" 0 $?
		assertEquals "Result should be empty" "" "$_RESULT"
	)
}

##
# @brief Test _extract_layer_hierarchy with unreadable file
# @tag @UT2.7.4@
test_extract_layer_hierarchy_unreadable() {
	(
		# Act -------------
		_RESULT=$(_extract_layer_hierarchy "/nonexistent/file" 2>/dev/null)

		# Assert ----------
		assertEquals "Should return error" 1 $?
	)
}

##
# @brief Test make_cross_reference_tables with single layer pair
# @tag @UT2.7.5@
test_make_cross_reference_tables_single_pair() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Requirement 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Architecture 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		# Act -------------
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success" 0 "$_STATUS"

		# Check that at least one cross-ref matrix file was created
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertTrue "Should create at least one matrix file" "[ $_MATRIX_FILES -ge 1 ]"
	)
}

##
# @brief Test make_cross_reference_tables with multiple layer pairs
# @tag @UT2.7.6@
test_make_cross_reference_tables_multiple_pairs() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Implementation${SHTRACER_SEPARATOR}./impl.sh${SHTRACER_SEPARATOR}Impl${SHTRACER_SEPARATOR}#.*${SHTRACER_SEPARATOR}*.sh${SHTRACER_SEPARATOR}\`@IMP[0-9\.]+@\`${SHTRACER_SEPARATOR}0${SHTRACER_SEPARATOR}
EOF

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Implementation${SHTRACER_SEPARATOR}@IMP1@${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}Impl 1${SHTRACER_SEPARATOR}impl.sh${SHTRACER_SEPARATOR}30${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
@ARC1@${SHTRACER_SEPARATOR}@IMP1@
EOF

		# Act -------------
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success" 0 "$_STATUS"

		# Should create 2 matrix files (REQ->ARC and ARC->IMP)
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "0*_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertEquals "Should create 2 matrix files" 2 "$_MATRIX_FILES"
	)
}

##
# @brief Test make_cross_reference_tables with orphaned tags
# @tag @UT2.7.7@
test_make_cross_reference_tables_orphaned_tags() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		# Tags with no relationships
		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Requirement${SHTRACER_SEPARATOR}@REQ2@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 2${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}15${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		# Empty tag pairs - no relationships
		touch "$_TAG_PAIRS_FILE"

		# Act -------------
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success even with orphaned tags" 0 "$_STATUS"

		# Matrix file should still be created (may be empty)
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertTrue "Should create matrix file even with orphaned tags" "[ $_MATRIX_FILES -ge 1 ]"
	)
}

##
# @brief Test make_cross_reference_tables with empty config
# @tag @UT2.7.8@
test_make_cross_reference_tables_empty_config() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		# Empty config table
		touch "$_CONFIG_TABLE"
		touch "$_TAGS_FILE"
		touch "$_TAG_PAIRS_FILE"

		# Act -------------
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE" 2>&1)
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return success with empty config" 0 "$_STATUS"

		# Should output warning about no layers
		echo "$_RESULT" | grep -qE "warn|No traceability layers"
		assertEquals "Should warn about no layers" 0 $?
	)
}

##
# @brief Test make_cross_reference_tables with unreadable files
# @tag @UT2.7.9@
test_make_cross_reference_tables_unreadable_files() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="/nonexistent/file"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		touch "$_TAGS_FILE"
		touch "$_TAG_PAIRS_FILE"

		# Act -------------
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE" 2>&1)
		_STATUS=$?

		# Assert ----------
		assertEquals "Should return error for unreadable files" 1 "$_STATUS"

		# Should output error message
		echo "$_RESULT" | grep -qE "error|Cannot read"
		assertEquals "Should show error message" 0 $?
	)
}

##
# @brief Test make_cross_reference_tables with missing intermediate layers
# @tag @UT2.7.10@
test_make_cross_reference_tables_missing_intermediate() {
	(
		# Arrange: REQ -> ARC -> IMP, but skip ARC layer
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Implementation${SHTRACER_SEPARATOR}./impl.sh${SHTRACER_SEPARATOR}Impl${SHTRACER_SEPARATOR}#.*${SHTRACER_SEPARATOR}*.sh${SHTRACER_SEPARATOR}\`@IMP[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		# IMP1 references REQ1 directly (skipping ARC layer)
		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Requirement 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Implementation${SHTRACER_SEPARATOR}@IMP1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Implementation 1${SHTRACER_SEPARATOR}impl.sh${SHTRACER_SEPARATOR}30${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@IMP1@
EOF

		# Act
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert
		assertEquals "Should handle missing intermediate layers" 0 "$_STATUS"

		# Should create matrix for REQ->IMP pair
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertTrue "Should create cross-ref matrix" "[ $_MATRIX_FILES -ge 1 ]"
	)
}

##
# @brief Test make_cross_reference_tables with files containing no tags
# @tag @UT2.7.11@
test_make_cross_reference_tables_files_with_no_tags() {
	(
		# Arrange: Config points to files but no tags found
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		# Empty tags file (no tags found)
		touch "$_TAGS_FILE"
		touch "$_TAG_PAIRS_FILE"

		# Act
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert
		assertEquals "Should handle empty tags gracefully" 0 "$_STATUS"

		# No matrix files should be created (no layer pairs)
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertEquals "Should not create matrix for empty tags" 0 "$_MATRIX_FILES"
	)
}

##
# @brief Test make_cross_reference_tables with special characters in paths
# @tag @UT2.7.12@
test_make_cross_reference_tables_special_char_paths() {
	(
		# Arrange: Paths with spaces and special characters
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./my docs/req file.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch & design.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}my docs/req file.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch & design.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		# Act
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert
		assertEquals "Should handle special chars in paths" 0 "$_STATUS"

		# Should create matrix
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertTrue "Should create cross-ref matrix" "[ $_MATRIX_FILES -ge 1 ]"
	)
}

##
# @brief Test make_cross_reference_tables with UTF-8 tag titles
# @tag @UT2.7.13@
test_make_cross_reference_tables_utf8_titles() {
	(
		# Arrange: Tags with UTF-8 characters in titles
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		# UTF-8 titles: accented chars, Greek letters, math symbols, emoji
		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Requirement #1: Café & Naïve Implementation 🔒${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Architecture α: Data Flow (∑ ≥ β) 📐${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		# Act
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert
		assertEquals "Should handle UTF-8 titles" 0 "$_STATUS"

		# Verify matrix files were created
		_MATRIX_FILES=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" 2>/dev/null | wc -l | tr -d ' ')
		assertTrue "Should create cross-ref matrix with UTF-8" "[ $_MATRIX_FILES -ge 1 ]"
	)
}

##
# @brief Test make_cross_reference_tables directory structure creation
# @tag @UT2.7.14@
test_make_cross_reference_tables_directory_structure() {
	(
		# Arrange
		mkdir -p "$OUTPUT_DIR/config" "$OUTPUT_DIR/tags"
		_CONFIG_TABLE="$OUTPUT_DIR/config/01_config_table"
		_TAGS_FILE="$OUTPUT_DIR/tags/01_tags"
		_TAG_PAIRS_FILE="$OUTPUT_DIR/tags/02_tag_pairs"

		cat >"$_CONFIG_TABLE" <<EOF
:Requirement${SHTRACER_SEPARATOR}./req.md${SHTRACER_SEPARATOR}Req${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@REQ[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
:Architecture${SHTRACER_SEPARATOR}./arch.md${SHTRACER_SEPARATOR}Arch${SHTRACER_SEPARATOR}<!--.*-->${SHTRACER_SEPARATOR}*.md${SHTRACER_SEPARATOR}\`@ARC[0-9\.]+@\`${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}
EOF

		cat >"$_TAGS_FILE" <<EOF
Requirement${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}$NODATA_STRING${SHTRACER_SEPARATOR}Req 1${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
Architecture${SHTRACER_SEPARATOR}@ARC1@${SHTRACER_SEPARATOR}@REQ1@${SHTRACER_SEPARATOR}Arch 1${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20${SHTRACER_SEPARATOR}extra${SHTRACER_SEPARATOR}v1
EOF

		cat >"$_TAG_PAIRS_FILE" <<EOF
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		# Remove any existing cross-reference files
		rm -f "$OUTPUT_DIR/tags/06_cross_ref_matrix_"*

		# Act
		_RESULT=$(make_cross_reference_tables "$_CONFIG_TABLE" "$_TAGS_FILE" "$_TAG_PAIRS_FILE")
		_STATUS=$?

		# Assert
		assertEquals "Should create directory structure" 0 "$_STATUS"

		# Verify matrix files are created in correct location
		assertTrue "Matrix files should exist in tags/ dir" "[ -f '$OUTPUT_DIR/tags/06_cross_ref_matrix_'* ]"

		# Verify naming pattern
		_MATRIX_FILE=$(find "$OUTPUT_DIR/tags" -name "06_cross_ref_matrix_*" | head -1)
		case "$_MATRIX_FILE" in
			"$OUTPUT_DIR/tags/06_cross_ref_matrix_"*)
				assertTrue "Matrix file follows naming convention" true
				;;
			*)
				fail "Matrix file should match pattern: 06_cross_ref_matrix_*"
				;;
		esac
	)
}

# ============================================================================
# Phase 1.4: Markdown Formatting Utilities Tests
# ============================================================================

##
# @brief Test markdown_cross_reference with empty matrix (no tags)
# @tag @UT2.9.1@
test_markdown_cross_reference_empty() {
	(
		# Arrange: Create matrix file with no tags
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_REQ_ARC"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
[COL_TAGS]
[MATRIX]
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH")
		_STATUS=$?

		# Assert
		assertEquals "Should handle empty matrix" 0 "$_STATUS"
		assertTrue "Should create output directory" "[ -d '$OUTPUT_DIR/cross_reference' ]"
	)
}

##
# @brief Test markdown_cross_reference with single row
# @tag @UT2.9.2@
test_markdown_cross_reference_single_row() {
	(
		# Arrange: Matrix with one requirement and one architecture
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_Requirement_Architecture"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH")
		_STATUS=$?

		# Assert
		assertEquals "Should process single row" 0 "$_STATUS"

		# Verify markdown file was created
		_MD_FILE=$(find "$OUTPUT_DIR/cross_reference" -name "*.md" | head -1)
		assertTrue "Should create markdown file" "[ -f '$_MD_FILE' ]"

		# Verify markdown contains tag
		grep -q "@REQ1@" "$_MD_FILE"
		assertEquals "Markdown should contain REQ tag" 0 $?
	)
}

##
# @brief Test markdown_cross_reference with multiple rows
# @tag @UT2.9.3@
test_markdown_cross_reference_multiple_rows() {
	(
		# Arrange: Matrix with multiple requirements and architectures
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_Requirement_Architecture"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10
@REQ2@${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}20
@REQ3@${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}30
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}40
@ARC2@${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}50
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
@REQ2@${SHTRACER_SEPARATOR}@ARC2@
@REQ3@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH")
		_STATUS=$?

		# Assert
		assertEquals "Should process multiple rows" 0 "$_STATUS"

		# Verify markdown file contains all tags
		_MD_FILE=$(find "$OUTPUT_DIR/cross_reference" -name "*.md" | head -1)
		grep -q "@REQ1@" "$_MD_FILE"
		assertEquals "Should contain REQ1" 0 $?
		grep -q "@REQ2@" "$_MD_FILE"
		assertEquals "Should contain REQ2" 0 $?
		grep -q "@REQ3@" "$_MD_FILE"
		assertEquals "Should contain REQ3" 0 $?
	)
}

##
# @brief Test markdown_cross_reference with special characters in tags
# @tag @UT2.9.4@
test_markdown_cross_reference_special_chars() {
	(
		# Arrange: Tags with markdown special chars (|, \, *, [, ])
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_Requirement_Architecture"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}path/with|pipe.md${SHTRACER_SEPARATOR}10
@REQ2@${SHTRACER_SEPARATOR}path/with[bracket].md${SHTRACER_SEPARATOR}20
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}arch*.md${SHTRACER_SEPARATOR}30
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH" 2>&1)
		_STATUS=$?

		# Assert - should not crash with special chars
		assertEquals "Should handle special chars" 0 "$_STATUS"

		# Verify markdown file was created
		_MD_FILE=$(find "$OUTPUT_DIR/cross_reference" -name "*.md" 2>/dev/null | head -1)
		assertTrue "Should create markdown file" "[ -f '$_MD_FILE' ]"
	)
}

##
# @brief Test markdown_cross_reference with UTF-8 content
# @tag @UT2.9.5@
test_markdown_cross_reference_utf8_content() {
	(
		# Arrange: Tags with UTF-8 characters
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_Requirement_Architecture"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}café.md${SHTRACER_SEPARATOR}10
@REQ2@${SHTRACER_SEPARATOR}naïve_α.md${SHTRACER_SEPARATOR}20
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}design_β.md${SHTRACER_SEPARATOR}30
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH")
		_STATUS=$?

		# Assert
		assertEquals "Should handle UTF-8 content" 0 "$_STATUS"

		# Verify markdown file was created
		_MD_FILE=$(find "$OUTPUT_DIR/cross_reference" -name "*.md" | head -1)
		assertTrue "Should create markdown with UTF-8" "[ -f '$_MD_FILE' ]"
	)
}

##
# @brief Test markdown_cross_reference with very long file paths
# @tag @UT2.9.6@
test_markdown_cross_reference_long_paths() {
	(
		# Arrange: Tags with very long file paths
		mkdir -p "$OUTPUT_DIR/tags"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_Requirement_Architecture"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"

		_LONG_PATH="very/long/path/to/some/deeply/nested/directory/structure/with/many/levels/requirement.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}$_LONG_PATH${SHTRACER_SEPARATOR}100
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}50
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH")
		_STATUS=$?

		# Assert
		assertEquals "Should handle long paths" 0 "$_STATUS"

		# Verify markdown file was created
		_MD_FILE=$(find "$OUTPUT_DIR/cross_reference" -name "*.md" | head -1)
		assertTrue "Should create markdown file" "[ -f '$_MD_FILE' ]"
	)
}

##
# @brief Test markdown_cross_reference with nonexistent tags directory
# @tag @UT2.9.7@
test_markdown_cross_reference_invalid_dir() {
	(
		# Arrange: Point to nonexistent directory
		_TAGS_DIR="/nonexistent/tags/directory"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"
		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$_TAGS_DIR" "$_CONFIG_PATH" 2>&1)
		_STATUS=$?

		# Assert - should fail gracefully
		assertNotEquals "Should fail with invalid directory" 0 "$_STATUS"
		echo "$_RESULT" | grep -q "error"
		assertEquals "Should output error message" 0 $?
	)
}

##
# @brief Test markdown_cross_reference with no matrix files
# @tag @UT2.9.8@
test_markdown_cross_reference_no_matrix_files() {
	(
		# Arrange: Tags directory exists but no matrix files
		mkdir -p "$OUTPUT_DIR/tags"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"
		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_RESULT=$(markdown_cross_reference "$OUTPUT_DIR/tags" "$_CONFIG_PATH" 2>&1)
		_STATUS=$?

		# Assert - should succeed but warn
		assertEquals "Should succeed with no matrices" 0 "$_STATUS"
		echo "$_RESULT" | grep -q "warn"
		assertEquals "Should output warning" 0 $?
	)
}

##
# @brief Test _generate_markdown_table basic formatting
# @tag @UT2.9.9@
test_generate_markdown_table_formatting() {
	(
		# Arrange
		mkdir -p "$OUTPUT_DIR/tags" "$OUTPUT_DIR/cross_reference"
		_MATRIX_FILE="$OUTPUT_DIR/tags/06_cross_ref_matrix_REQ_ARC"
		_CONFIG_PATH="$OUTPUT_DIR/config.md"
		_OUTPUT_MD="$OUTPUT_DIR/cross_reference/test_output.md"

		cat >"$_MATRIX_FILE" <<EOF
[METADATA]
@REQ[0-9\.]+@${SHTRACER_SEPARATOR}@ARC[0-9\.]+@
[ROW_TAGS]
@REQ1@${SHTRACER_SEPARATOR}req.md${SHTRACER_SEPARATOR}10
[COL_TAGS]
@ARC1@${SHTRACER_SEPARATOR}arch.md${SHTRACER_SEPARATOR}20
[MATRIX]
@REQ1@${SHTRACER_SEPARATOR}@ARC1@
EOF

		echo "dummy config" >"$_CONFIG_PATH"

		# Act
		_generate_markdown_table "$_MATRIX_FILE" "$_CONFIG_PATH" "$_OUTPUT_MD"
		_STATUS=$?

		# Assert
		assertEquals "Should generate markdown table" 0 "$_STATUS"
		assertTrue "Output file should exist" "[ -f '$_OUTPUT_MD' ]"

		# Verify markdown table structure (should contain table markers)
		grep -q "|" "$_OUTPUT_MD"
		assertEquals "Should contain table pipes" 0 $?
	)
}

# shellcheck source=shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
