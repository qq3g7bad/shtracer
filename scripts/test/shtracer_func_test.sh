#!/bin/sh

# Source test target
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "../main/shtracer_func.sh"
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
	NODATA_STRING="NONE"
	OUTPUT_DIR="${SCRIPT_DIR%/}/output/"
	CONFIG_DIR="${SCRIPT_DIR%/}/testdata/"
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

		_RETURN_VALUE="$(check_configfile "./testdata/config.md")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/config/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_config_table" "${_RETURN_VALUE##*/}"

		# config table
		_ANSWER="$(cat ./testdata/answer/config/config_table)"
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
		assertEquals "shtracer_func_test.sh: cannot find a config output data." "${_RETURN_VALUE##*/}"
	)
}

##
# @brief  Test for extract_tags
# @tag    @UT2.3@ (FROM: @IMP2.2@)
test_extract_tags() {
	(
		# Arrange ---------
		# Act -------------

		_RETURN_VALUE="$(extract_tags "./testdata/answer/config/config_table")"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/tags/" ]
			echo "$?"
		)"

		# output filename
		assertEquals "01_tags" "${_RETURN_VALUE##*/}"

		# Level1
		_ANSWER="$(awk <"./testdata/answer/tags/tags" -F"$SHTRACER_SEPARATOR" '
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
# @brief  Test for join_tag_table
# @tag    @UT2.4@ (FROM: @IMP2.4@)
test_join_tag_table_without_argument() {
	# Arrange ---------
	# Act -------------
	join_tag_pairs >/dev/null 2>&1
	# Assert ----------
	assertEquals 1 "$?"
}

##
# @brief  Test for make_tag_table
# @tag    @UT2.5@ (FROM: @IMP2.3@)
test_make_tag_table() {
	(
		# Arrange ---------
		# Act -------------
		make_tag_table "./testdata/answer/tags/tags" >/dev/null

		# Assert ----------
		assertEquals 0 "$?"

		_ANSWER="$(cat ./testdata/answer/tags/tag_table)"
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
		(make_tag_table "./testdata/empty" >/dev/null 2>&1)

		# Assert ----------
		assertEquals 1 "$?"
	)
}

. "./shunit2/shunit2"
