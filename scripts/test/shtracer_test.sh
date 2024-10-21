#!/bin/sh

. "../../shtracer"

##
# @brief  Default global constant
test_default_global_constant() {
	assertEquals "${CONFIG_PATH}" ""
	assertEquals "${SHTRACER_MODE}" "NORMAL"
	assertEquals "${AFTER_TAG}" ""
	assertEquals "${BEFORE_TAG}" ""
	assertEquals "${OUTPUT_DIR}" "./output/"
	assertEquals "${SHTRACER_SEPARATOR}" "<shtracer_separator>"
	assertEquals "${NODATA_STRING}" "NONE"
}

. "./shunit2/shunit2"
