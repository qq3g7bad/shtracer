#!/bin/sh

# Source test target
. "../../shtracer"

##
# @brief
#
setUp() {
	set +u
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
# @brief
test_init_environment() {
  _TMP_PATH="$(command -p getconf PATH 2>/dev/null)${PATH+:}${PATH-}"

	init_environment

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
. "./shunit2/shunit2"
