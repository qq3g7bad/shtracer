#!/bin/sh

# Source test target
. "../main/shtracer_func.sh"

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	SCRIPT_DIR="../../"
	OUTPUT_DIR="./output/"
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
		# cat ./output/config/1 > "${OUTPUT_DIR%/}/config/check_configfile_output1"
		# cat ./output/config/2 > "${OUTPUT_DIR%/}/config/check_configfile_output2"

		# Assert ----------
		# mkdir
		assertEquals 0 "$(
			[ -d ./output/config/ ]
			echo "$?"
		)"

		# output filename
		assertEquals 2 "${_RETURN_VALUE##*/}"

		# Level1
		_ANSWER="$(cat ./testdata/answer/check_configfile_output1)"
		_TEST_DATA="$(cat ./output/config/1)"
		assertEquals "$_ANSWER" "$_TEST_DATA"

		# Level2
		_ANSWER="$(cat ./testdata/answer/check_configfile_output2)"
		_TEST_DATA="$(cat ./output/config/2)"
		assertEquals "$_ANSWER" "$_TEST_DATA"
	)
}

. "./shunit2/shunit2"
