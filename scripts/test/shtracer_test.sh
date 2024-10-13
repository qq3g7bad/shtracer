#!/bin/sh

# Source test targets
. "../../shtracer"
. "../main/shtracer_util.sh"

sh -c "./shtracer_func_test.sh"
sh -c "./shtracer_html_test.sh"

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
	SCRIPT_DIR="../../"
}

##
# @brief TearDown function for each test
#
tearDown() {
	rm -rf "$OUTPUT_DIR"
}

##
# @brief  Default global constant
#
test_default_global_constant() {
	assertEquals "${CONFIG_PATH}" ""
	assertEquals "${SHTRACER_MODE}" "NORMAL"
	assertEquals "${AFTER_TAG}" ""
	assertEquals "${BEFORE_TAG}" ""
	assertEquals "${OUTPUT_DIR}" "./output/"
	assertEquals "${SHTRACER_SEPARATOR}" "<shtracer_separator>"
	assertEquals "${NODATA_STRING}" "NONE"
}

##
# @brief  Test for init_environment
# @tag    @UT1.1@ (FROM: @IMP4.1@)
test_init_environment() {
	(
		# Arrange ---------
		_TMP_PATH="$(command -p getconf PATH 2>/dev/null)${PATH+:}${PATH-}"

		# Act -------------
		init_environment

		# Assert ----------

		# IFS='\n'
		IFS_HEX=$(printf "%s" "$IFS" | od -An -tx1 | tr -d ' \n')
		IFS=' '
		assertEquals "0a" "$IFS_HEX"

		# set -u : ERROR for _UNDEFINED_VAR
		(
			echo "$_UNDEFINED_VAR"
		) 2>/dev/null
		assertNotEquals 0 "$?"

		# umask 0022
		assertEquals 0022 "$(umask)"

		# export LC_ALL=C
		assertEquals "C" "$LC_ALL"

		# PATH
		assertEquals "$PATH" "$_TMP_PATH"
	)
}

##
# @brief  Test for load functions
# @tag    @UT1.2@ (FROM: @IMP1.1@)
test_load_functions() {
	(
		# Arrange ---------

		# Act -------------
		load_functions

		# Assert ----------
		(
			echo "$_SHTRACER_FUNC_SH" >/dev/null
		) 2>/dev/null
		assertEquals 0 "$?"

		(
			echo "$_SHTRACER_HTML_SH" >/dev/null
		) 2>/dev/null
		assertEquals 0 "$?"
	)
}

##
# @brief  Test for print_usage
# @tag    @UT1.3@ (FROM: @IMP1.2@)
test_print_usage() {
	(
		# Arrange ---------
		# Act -------------
		_STDOUT=$(print_usage 2>/dev/null) # Capture stdout
		_ERROUT=$(print_usage 2>&1)        # Capture stderr

		# Assert ----------
		assertEquals "" "$_STDOUT"
		assertNotEquals "" "$_ERROUT"
	)
}

##
# @brief  Test for error_exit
# @tag    @UT1.4@ (FROM: @IMP4.2@)
test_error_exit() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			error_exit 2 "test_error" 2>&1
		)"
		# Assert ----------
		assertEquals 2 "$?"
		assertEquals "shtracer_test.sh: test_error" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with -v
# @tag    @UT1.5@ (FROM: @IMP1.3@)
test_parse_arguments_version1() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "-v" 2>&1
		)"
		_USAGE="$(print_usage 2>&1)"

		# Assert ----------
		assertEquals "$_USAGE" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with --version
# @tag    @UT1.6@ (FROM: @IMP1.3@)
test_parse_arguments_version2() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "--version" 2>&1
		)"
		_USAGE="$(print_usage 2>&1)"

		# Assert ----------
		assertEquals "$_USAGE" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with --varsion
# @tag    @UT1.7@ (FROM: @IMP1.3@)
test_parse_arguments_version3() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "--varsion" 2>&1
		)"

		# Assert ----------
		assertEquals "shtracer_test.sh: Invalid argument" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with -h
# @tag    @UT1.8@ (FROM: @IMP1.3@)
test_parse_arguments_h() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "-h" 2>&1
		)"
		_USAGE="$(print_usage 2>&1)"

		# Assert ----------
		assertEquals "$_USAGE" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with --help
# @tag    @UT1.9@ (FROM: @IMP1.3@)
test_parse_arguments_help1() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "--help" 2>&1
		)"
		_USAGE="$(print_usage 2>&1)"

		# Assert ----------
		assertEquals "$_USAGE" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with -h
# @tag    @UT1.10@ (FROM: @IMP1.3@)
test_parse_arguments_help2() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "-h" 2>&1
		)"
		_USAGE="$(print_usage 2>&1)"

		# Assert ----------
		assertEquals "$_USAGE" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with -t
# @tag    @UT1.11@ (FROM: @IMP1.3@)
test_parse_arguments_test() {
	(
		# Arrange ---------
		load_functions
		# Act -------------
		parse_arguments "-t"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "TEST"
	)
}

##
# @brief  Test for parse_arguments with undefined option
# @tag    @UT1.12@ (FROM: @IMP1.3@)
test_parse_arguments_undefined_option() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "-T" 2>&1
		)"

		# Assert ----------
		assertEquals "shtracer_test.sh: Invalid argument" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with normal mode
# @tag    @UT1.13@ (FROM: @IMP1.3@)
test_parse_arguments_normal_mode() {
	(
		# Arrange ---------
		load_functions
		# Act -------------
		parse_arguments "$0"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "NORMAL"
	)
}

##
# @brief  Test for parse_arguments with -v
# @tag    @UT1.14@ (FROM: @IMP1.3@)
test_parse_arguments_verify_mode() {
	(
		# Arrange ---------
		load_functions
		# Act -------------
		parse_arguments "$0" "-v"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "VERIFY"
	)
}

##
# @brief  Test for parse_arguments in change mode
# @tag    @UT1.15@ (FROM: @IMP1.3@)
test_parse_arguments_change_mode() {
	(
		# Arrange ---------
		load_functions
		# Act -------------
		parse_arguments "$0" "-c" "old_tag" "new_tag"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "CHANGE"
	)
}

##
# @brief  Test for parse_arguments with non-existent config file
# @tag    @UT1.16@ (FROM: @IMP1.3@)
test_parse_arguments_with_non_existent_config_file() {
	(
		# Arrange ---------
		# Act -------------
		_RETURN_VALUE="$(
			parse_arguments "non_existent_file" 2>&1
		)"
		# Assert ----------
		assertEquals "shtracer_test.sh: non_existent_file does not exist" "$_RETURN_VALUE"
	)
}

##
# @brief  Test for parse_arguments with config file
# @tag    @UT1.17@ (FROM: @IMP1.3@)
test_parse_arguments_with_config_file() {
	(
		# Arrange ---------
		load_functions
		# Act -------------
		parse_arguments "$0"
		# Assert ----------
		assertEquals "$0" "$CONFIG_PATH"
		assertEquals "$(cd "$(dirname "$0")" && pwd)" "$CONFIG_DIR"
		assertEquals "${CONFIG_DIR%/}/output/" "$OUTPUT_DIR"
		assertNotEquals "" "$CONFIG_OUTPUT"
	)
}

##
# @brief  Test for main_routine
# @tag    @UT1.18@ (FROM: @IMP4.1@)
test_main_routine() {
	(
		# Arrange ---------
		set -u

		# Act -------------
		main_routine "../../sample/config.md" >/dev/null
		IFS_HEX=$(printf "%s" "$IFS" | od -An -tx1 | tr -d ' \n')
		IFS=' '

		# Assert ----------

		# main_routine returned value
		assertEquals "$?" "0"

		# init_environment
		assertEquals "0a" "$IFS_HEX"

		# load_functions
		(
			echo "$_SHTRACER_FUNC_SH" >/dev/null
		) 2>/dev/null
		assertEquals 0 "$?"

		# parse_arguments
		assertEquals "$SHTRACER_MODE" "NORMAL"

		# TODO: add tests if functions of each mode are called
	)
}

. "./shunit2/shunit2"
