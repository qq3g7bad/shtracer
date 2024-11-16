#!/bin/sh

# Source test target
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "${SCRIPT_DIR}" || exit 1

. "../main/shtracer_uml.sh"
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


. "./shunit2/shunit2"
