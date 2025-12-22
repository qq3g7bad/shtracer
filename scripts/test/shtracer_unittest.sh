#!/bin/sh

# Ensure paths resolve regardless of caller CWD
TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$TEST_DIR" ]; then
	TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$(basename -- "$0")")" 2>/dev/null && pwd -P)
fi
cd "${TEST_DIR}" || exit 1

# Ensure shunit2 can find this script after we cd
SELF_PATH="${TEST_DIR%/}/$(basename -- "$0")"
export SHUNIT_PARENT="$SELF_PATH"

# Let ../../shtracer resolve its own SCRIPT_DIR even when sourced
SHTRACER_ROOT_DIR=$(CDPATH='' cd -- "${TEST_DIR%/}/../.." 2>/dev/null && pwd -P)
SCRIPT_DIR="$SHTRACER_ROOT_DIR"

# Source test targets
# shellcheck source=/dev/null
. "${SCRIPT_DIR%/}/shtracer"
# shellcheck source=../main/shtracer_util.sh
. "../main/shtracer_util.sh"

sh -c "./shtracer_func_unittest.sh"
sh -c "./shtracer_viewer_unittest.sh"
sh -c "./shtracer_integration_test.sh"

##
# @brief
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " UNIT TEST : $0"
	echo "----------------------------------------"
}

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	SCRIPT_DIR="$SHTRACER_ROOT_DIR"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
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
			error_exit 2 "function_name" "test_error" 2>&1
		)"
		# Assert ----------
		assertEquals 2 "$?"
		assertEquals "[shtracer_unittest.sh][error][function_name]: test_error" "$_RETURN_VALUE"
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
		assertEquals "[shtracer_unittest.sh][error][parse_arguments]: Invalid argument" "$_RETURN_VALUE"
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
		assertEquals "[shtracer_unittest.sh][error][parse_arguments]: Invalid argument" "$_RETURN_VALUE"
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
		parse_arguments "$SELF_PATH"
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
		parse_arguments "$SELF_PATH" "-v"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "VERIFY"
	)
}

##
# @brief  Test for parse_arguments with --summary
test_parse_arguments_summary_mode() {
	(
		# Arrange ---------
		load_functions
		EXPORT_SUMMARY='false'
		# Act -------------
		parse_arguments "$SELF_PATH" "--summary"
		# Assert ----------
		assertEquals "$SHTRACER_MODE" "NORMAL"
		assertEquals "$EXPORT_SUMMARY" "true"
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
		parse_arguments "$SELF_PATH" "-c" "old_tag" "new_tag"
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
		assertEquals "[shtracer_unittest.sh][error][parse_arguments]: non_existent_file does not exist" "$_RETURN_VALUE"
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
		parse_arguments "$SELF_PATH"
		# Assert ----------
		_DIRNAME=$(cd "$(dirname "$SELF_PATH")" && pwd)
		assertEquals "$SELF_PATH" "$CONFIG_PATH"
		assertEquals "${_DIRNAME%/}" "$CONFIG_DIR"
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
		main_routine "./testdata/unit_test/test_config4.md" >/dev/null 2>&1
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

##
# @brief  Test for main_routine (tag output is isolated)
# @tag    @UT1.19@ (FROM: @IMP4.1@)
test_main_routine_multiple_directories() {
	(
		# Arrange ---------
		set -u

		# Act -------------
		_RETURN="$(main_routine "./testdata/unit_test/test_config3.md" 2>&1)"
		IFS=' '

		# Assert ----------
		assertEquals "$(echo "$_RETURN" | grep -o -E "\[[^]]*\]" | sed -n '1p')" "[shtracer_unittest.sh]" # Error occur

	)
}

##
# @brief  Test for main_routine (tag output is isolated)
# @tag    @UT1.20@ (FROM: @IMP4.1@)
test_main_routine_output_isolated() {
	(
		# Arrange ---------
		set -u

		# Act -------------
		_RETURN="$(main_routine "./testdata/unit_test/test_config3.md" 2>&1)"
		IFS=' '

		# Assert ----------
		assertEquals "[shtracer_unittest.sh][error][make_tag_table]: No linked tags found." "$(echo "$_RETURN" | sed -n '1p')"

	)
}

##
# @brief  Test for main_routine with invalid config (nonexistent paths)
# @tag    @UT1.21@ (FROM: @IMP4.1@)
test_main_routine_invalid_config_paths() {
	(
		# Arrange ---------
		set -u

		# Act -------------
		_RETURN="$(main_routine "./testdata/unit_test/wrong_config.md" 2>&1)"
		IFS=' '

		# Assert ----------
		# Should output error about no linked tags found
		echo "$_RETURN" | grep -q "No linked tags found"
		assertEquals 0 "$?"

		# Should output find errors for nonexistent paths
		echo "$_RETURN" | grep -q "No such file or directory"
		assertEquals 0 "$?"

	)
}

# shellcheck source=shunit2/shunit2
. "./shunit2/shunit2"
