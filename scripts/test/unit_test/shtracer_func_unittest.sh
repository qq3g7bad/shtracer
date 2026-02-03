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
		assertEquals "0" "$(wc -l <"$_OUTPUT_FILE")"
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
		assertEquals "1" "$(wc -l <"$_OUTPUT_FILE")"
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
		assertEquals "2" "$(wc -l <"$_OUTPUT_FILE")"
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
		assertEquals "1" "$(wc -l <"$_OUTPUT_FILE")"
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
		assertEquals "2" "$(wc -l <"$_OUTPUT_FILE")"
	)
}

# shellcheck source=shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
