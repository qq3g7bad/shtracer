#!/bin/sh

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

# Ensure relative sources resolve regardless of caller CWD
cd "${SCRIPT_DIR}" || exit 1

# shellcheck source=../main/shtracer_func.sh
. "../main/shtracer_func.sh"
# shellcheck source=../main/shtracer_util.sh
. "../main/shtracer_util.sh"

##
# @brief
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " TEST : $0"
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
	export OUTPUT_DIR="${SCRIPT_DIR%/}/output/"
	export CONFIG_DIR="${SCRIPT_DIR%/}/testdata/"
	cd "${SCRIPT_DIR}" || exit 1
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

		_RETURN_VALUE="$(check_configfile "./testdata/unit_test/test_config1.md")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/config/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_config_table" "${_RETURN_VALUE##*/}"

		# config table
		_ANSWER="$(cat ./testdata/answer/unit_test/config/config_table)"
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
		export CONFIG_DIR="${SCRIPT_DIR%/}/testdata/unit_test/"

		# Act -------------

		_RETURN_VALUE="$(extract_tags "./testdata/answer/unit_test/config/config_table")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/tags/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_tags" "${_RETURN_VALUE##*/}"

		# Level1
		_ANSWER="$(awk <"./testdata/answer/unit_test/tags/tags" -F"$SHTRACER_SEPARATOR" '
			BEGIN{OFS="'"$SHTRACER_SEPARATOR"'"}
			{
				cmd	=	"basename	\""$5"\"";	cmd	|	getline	filename_result;	close(cmd)
				cmd	=	"dirname	\""$5"\"";	cmd	|	getline	dirname_result;	close(cmd)
				cmd	=	"cd	\"'"$CONFIG_DIR"'\";cd	"dirname_result";PWD=\"$(pwd)\";	\
					echo	\"${PWD%/}/\"";	cmd	|	getline	absolute_path;	close(cmd)
				$5	=	absolute_path	filename_result
				print	$0
			}')"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/tags/01_tags")"
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
		make_tag_table "./testdata/answer/unit_test/tags/tags" >/dev/null

		# Assert ----------
		assertEquals 0 "$?"

		_ANSWER="$(cat ./testdata/answer/unit_test/tags/tag_table)"
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
		(make_tag_table "./testdata/unit_test/empty" >/dev/null 2>&1)

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
		_INPUT="$OUTPUT_DIR/verified/isolated${SHTRACER_SEPARATOR}$OUTPUT_DIR/verified/duplicated"

		# Act -------------
		print_verification_result "$_INPUT"

		# Assert ----------
		assertEquals 0 "$?"
	)
}

##
# @brief  Test for print_verification_result with isolated tags
# @tag    @UT2.12@ (FROM: @IMP2.5@)
test_print_verification_result_with_isolated() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		echo "@ISOLATED_TAG@" >"$OUTPUT_DIR/verified/isolated"
		_INPUT="$OUTPUT_DIR/verified/isolated"

		# Act -------------
		print_verification_result "$_INPUT" 2>/dev/null

		# Assert ----------
		assertEquals 1 "$?"
	)
}

##
# @brief  Test for print_verification_result with duplicated tags
# @tag    @UT2.13@ (FROM: @IMP2.5@)
test_print_verification_result_with_duplicated() {
	(
		# Arrange ---------
		mkdir -p "$OUTPUT_DIR/verified"
		echo "@DUPLICATE_TAG@" >"$OUTPUT_DIR/verified/duplicated"
		echo "@DUPLICATE_TAG@" >"$OUTPUT_DIR/verified/duplicated"
		_INPUT="$OUTPUT_DIR/verified/duplicated"

		# Act -------------
		print_verification_result "$_INPUT" 2>/dev/null

		# Assert ----------
		assertEquals 1 "$?"
	)
}

# shellcheck source=shunit2/shunit2
. "./shunit2/shunit2"
