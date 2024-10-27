#!/bin/sh

# Source test target
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "${SCRIPT_DIR}" || exit 1

. "../main/shtracer_func.sh"
. "../main/shtracer_util.sh"

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	SHTRACER_SEPARATOR="<shtracer_separator>"
	NODATA_STRING="NONE"
	OUTPUT_DIR="./output/"
	CONFIG_DIR="./testdata/"
	rm -rf "$OUTPUT_DIR"
}

##
# @brief TearDown function for each test
#
tearDown() {
	:
}

##
# @brief  Test for check_configfile
# @tag    @UT2.1@ (FROM: @IMP2.1@)
test_check_configfile() {
	(
		# Arrange ---------

		# Act -------------

		_RETURN_VALUE="$(check_configfile "./testdata/config.md")"
		# cat "${OUTPUT_DIR%/}/config/1" > "${CONFIG_DIR%/}/answer/check_configfile_output1"
		# cat "${OUTPUT_DIR%/}/config/2" >"${CONFIG_DIR%/}/answer/check_configfile_output2"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/config/" ]
			echo "$?"
		)"

		# output filename
		assertEquals 2 "${_RETURN_VALUE##*/}"

		# Level1
		_ANSWER="$(cat ./testdata/answer/configfile_output1)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/config/1")"
		assertEquals "$_ANSWER" "$_TEST_DATA"

		# Level2
		_ANSWER="$(cat ./testdata/answer/configfile_output2)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/config/2")"
		assertEquals "$_ANSWER" "$_TEST_DATA"
	)
}

##
# @brief  Test for make_tags
# @tag    @UT2.2@ (FROM: @IMP2.2@)
test_make_tags_without_argument() {
	(
		# Arrange ---------
		# Act -------------

		_RETURN_VALUE="$(make_tags 2>&1)"

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
# @brief  Test for make_tags
# @tag    @UT2.3@ (FROM: @IMP2.2@)
test_make_tags() {
	(
		# Arrange ---------
		# Act -------------

		_RETURN_VALUE="$(make_tags "./testdata/answer/configfile_output2")"
		# cat ./output/tags/1 >"${CONFIG_DIR%/}/answer/make_tags_output1"

		# Assert ----------

		# mkdir
		assertEquals 0 "$(
			[ -d "${OUTPUT_DIR%/}/tags/" ]
			echo "$?"
		)"

		# output filename
		assertEquals 1 "${_RETURN_VALUE##*/}"

		# Level1
		_ANSWER="$(cat ./testdata/answer/make_tags_output1)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/tags/1")"
		assertEquals "$_ANSWER" "$_TEST_DATA"
	)
}

##
# @brief  Test for join_tag_table
# @tag    @UT2.4@ (FROM: @IMP2.4@)
test_join_tag_table_without_argument() {
	# Arrange ---------
	# Act -------------
	join_tag_table >/dev/null 2>&1
	# Assert ----------
	assertEquals 1 "$?"
}

##
# @brief  Test for join_tag_table
# @tag    @UT2.5@ (FROM: @IMP2.3@)
test_make_tag_table() {
	(
		# Arrange ---------
		# Act -------------
		make_tag_table "./testdata/answer/make_tags_output1" >/dev/null

		# Assert ----------
		assertEquals 0 "$?"

		_ANSWER="$(cat ./testdata/answer/make_tag_table_joined)"
		_TEST_DATA="$(cat "${OUTPUT_DIR%/}/tags/joined")"
	)
}

##
# @brief  Test for join_tag_table
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
# @brief  Test for join_tag_table
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
