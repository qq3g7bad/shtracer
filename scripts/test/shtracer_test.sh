#!/bin/sh

# Source test target
. "../../shtracer"

##
# @brief
#
setUp() {
	set +u
	SCRIPT_DIR="../../"
}

##
# @brief
#
tearDown() {
	:
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
# @tag    @UT1.1@ (FROM: @IMP1.1@)
test_init_environment() {

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
}

##
# @brief  Test for load functions
# @tag    @UT1.2@ (FROM: @IMP1.2@)
test_load_functions() {
	# Arrange ---------
	set -u

	# Act -------------
	load_functions

	# Assert ----------
	(
		echo "$_SHTRACER_FUNC_SH" >/dev/null
	) 2>/dev/null
	assertEquals 0 "$?"

	(
		echo "$_SHTRACER_UML_SH" >/dev/null
	) 2>/dev/null
	assertEquals 0 "$?"
}

##
# @brief  Test for print_usage
# @tag    @UT1.3@ (FROM: @IMP1.3@)
test_print_usage() {
	# Arrange ---------
	# Act -------------
	_STDOUT=$(print_usage 2>/dev/null) # Capture stdout
	_ERROUT=$(print_usage 2>&1)        # Capture stderr

	# Assert ----------
	assertEquals "" "$_STDOUT"
	assertNotEquals "" "$_ERROUT"
}

##
# @brief  Test for error_exit
# @tag    @UT1.4@ (FROM: @IMP1.4@)
test_error_exit() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		error_exit 2 "test_error" 2>&1
	)"
	# Assert ----------
	assertEquals 2 "$?"
	assertEquals "shtracer_test.sh: test_error" "$_RETURN_VALUE"

}

##
# @brief  Test for parse_arguments with -v
# @tag    @UT1.5@ (FROM: @IMP1.5@)
test_parse_arguments_version1() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "-v" 2>&1
	)"
	_USAGE="$(print_usage 2>&1)"

	# Assert ----------
	assertEquals "$_USAGE" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with --version
# @tag    @UT1.6@ (FROM: @IMP1.5@)
test_parse_arguments_version2() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "--version" 2>&1
	)"
	_USAGE="$(print_usage 2>&1)"

	# Assert ----------
	assertEquals "$_USAGE" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with --varsion
# @tag    @UT1.7@ (FROM: @IMP1.5@)
test_parse_arguments_version3() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "--varsion" 2>&1
	)"

	# Assert ----------
	assertEquals "shtracer_test.sh: Invalid argument" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with -h
# @tag    @UT1.8@ (FROM: @IMP1.5@)
test_parse_arguments_h() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "-h" 2>&1
	)"
	_USAGE="$(print_usage 2>&1)"

	# Assert ----------
	assertEquals "$_USAGE" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with --help
# @tag    @UT1.9@ (FROM: @IMP1.5@)
test_parse_arguments_help1() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "--help" 2>&1
	)"
	_USAGE="$(print_usage 2>&1)"

	# Assert ----------
	assertEquals "$_USAGE" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with -h
# @tag    @UT1.10@ (FROM: @IMP1.5@)
test_parse_arguments_help2() {
	# Arrange ---------
	# Act -------------
	_RETURN_VALUE="$(
		parse_arguments "-h" 2>&1
	)"
	_USAGE="$(print_usage 2>&1)"

	# Assert ----------
	assertEquals "$_USAGE" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with -t
# @tag    @UT1.11@ (FROM: @IMP1.5@)
test_parse_arguments_test() {
  # Arrange ---------
  # Act -------------
  parse_arguments "-t"
  # Assert ----------
  assertEquals "$SHTRACER_MODE" "TEST"
}

##
# @brief  Test for parse_arguments with undefined option
# @tag    @UT1.12@ (FROM: @IMP1.5@)
test_parse_arguments_undefined_option() {
  # Arrange ---------
  # Act -------------
	_RETURN_VALUE="$(
		parse_arguments "-T" 2>&1
	)"

	# Assert ----------
	assertEquals "shtracer_test.sh: Invalid argument" "$_RETURN_VALUE"
}

##
# @brief  Test for parse_arguments with normal mode
# @tag    @UT1.13@ (FROM: @IMP1.5@)
test_parse_arguments_normal_mode() {
  # Arrange ---------
  # Act -------------
  parse_arguments "./shtracer_test.sh"
  # Assert ----------
  assertEquals "$SHTRACER_MODE" "NORMAL"
}
. "./shunit2/shunit2"
