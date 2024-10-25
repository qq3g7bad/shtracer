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
		echo "$_SHTRACER_FUNC_SH"
	) 2>/dev/null
	assertEquals 0 "$?"

	(
		echo "$_SHTRACER_UML_SH"
	) 2>/dev/null
	assertEquals 0 "$?"
}

. "./shunit2/shunit2"
