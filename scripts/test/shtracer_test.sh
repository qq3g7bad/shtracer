#!/bin/sh

. "../../shtracer"

echo "$0"
test_global_constant() {
	assertEquals "NONE" "${NODATA_STRING}"
}

. "./shunit2/shunit2"
