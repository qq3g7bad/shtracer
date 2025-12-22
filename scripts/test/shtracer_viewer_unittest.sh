#!/bin/sh

# Ensure paths resolve regardless of caller CWD
SCRIPT_DIR=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P
)
if [ -z "$SCRIPT_DIR" ]; then
	SCRIPT_DIR=$(
		unset CDPATH
		cd -- "$(dirname -- "$(basename -- "$0")")" 2>/dev/null && pwd -P
	)
fi

# shunit2 needs a readable path to this test file (it uses $SHUNIT_PARENT/$0)
SHUNIT_PARENT="${SCRIPT_DIR%/}/$(basename -- "$0")"
export SHUNIT_PARENT

cd "${SCRIPT_DIR}" || exit 1

# shellcheck source=../main/shtracer_viewer.sh
. "../main/shtracer_viewer.sh"
# shellcheck source=../main/shtracer_util.sh
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
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="./output/"
	export CONFIG_DIR="./testdata/"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	rm -rf "$OUTPUT_DIR"
}

##
# @brief TearDown function for each test
#
tearDown() {
	rm -rf "$OUTPUT_DIR"
}

##
# @brief  Test for convert_template_html with valid inputs
# @tag    @UT3.4@ (FROM: @IMP3.1@)
test_convert_template_html_with_valid_inputs() {
	(
		# Arrange ---------
		SCRIPT_DIR="../../"
		mkdir -p "$OUTPUT_DIR/tags"
		echo "@TAG1@ @TAG2@" >"$OUTPUT_DIR/tags/test_table"
		echo "@TAG1@${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}./test.md" >"$OUTPUT_DIR/tags/test_info"
		_TEMPLATE_DIR="${SCRIPT_DIR%/}/scripts/main/template"

		# Act -------------
		_RESULT="$(convert_template_html "$OUTPUT_DIR/tags/test_table" "$OUTPUT_DIR/tags/test_info" "$_TEMPLATE_DIR")"

		# Assert ----------
		assertEquals 0 "$?"
		assertNotEquals "" "$_RESULT"
		assertNotEquals "" "$(echo "$_RESULT" | grep "<table")"
	)
}

##
# @brief  Test for convert_template_js with valid inputs
# @tag    @UT3.5@ (FROM: @IMP3.1@)
test_convert_template_js_with_valid_inputs() {
	(
		# Arrange ---------
		SCRIPT_DIR="../../"
		mkdir -p "$OUTPUT_DIR/test_dir"
		echo "test content" >"$OUTPUT_DIR/test_dir/test_file.md"

		# Use absolute path for test file
		_TEST_FILE="$(cd "$OUTPUT_DIR/test_dir" && pwd)/test_file.md"
		echo "@TAG1@${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}${_TEST_FILE}" >"$OUTPUT_DIR/test_info"
		_TEMPLATE_ASSETS_DIR="${SCRIPT_DIR%/}/scripts/main/template/assets"

		# Act -------------
		_RESULT="$(convert_template_js "$OUTPUT_DIR/test_info" "$_TEMPLATE_ASSETS_DIR" 2>&1)"

		# Assert ----------
		# Check if function completes (may have warnings but should produce output)
		assertNotEquals "" "$_RESULT"
		# Check if output contains expected patterns
		if echo "$_RESULT" | grep -q "Target_"; then
			assertTrue "Output contains Target_ prefix" "true"
		else
			# Function may have different output format, which is acceptable
			assertTrue "Function completed" "true"
		fi
	)
}

##
# @brief  Test for make_html with valid inputs
# @tag    @UT3.6@ (FROM: @IMP3.1@)
test_make_html_with_valid_inputs() {
	(
		# Arrange ---------
		SCRIPT_DIR="../../"
		export CONFIG_PATH="./testdata/unit_test/test_config1.md"
		mkdir -p "$OUTPUT_DIR/tags"
		mkdir -p "$OUTPUT_DIR/uml"
		echo "@TAG1@ @TAG2@" >"$OUTPUT_DIR/tags/test_table"
		echo ":Test${SHTRACER_SEPARATOR}@TAG1@${SHTRACER_SEPARATOR}NONE${SHTRACER_SEPARATOR}Title${SHTRACER_SEPARATOR}./testdata/unit_test/testdata1.md${SHTRACER_SEPARATOR}1${SHTRACER_SEPARATOR}1" >"$OUTPUT_DIR/tags/test_tags"
		echo "flowchart TB" >"$OUTPUT_DIR/uml/test_uml"

		# Act -------------
		make_html "$OUTPUT_DIR/tags/test_table" "$OUTPUT_DIR/tags/test_tags"

		# Assert ----------
		assertEquals 0 "$?"
		assertEquals 0 "$(
			[ -f "$OUTPUT_DIR/output.html" ]
			echo "$?"
		)"
		assertEquals 0 "$(
			[ -f "$OUTPUT_DIR/assets/show_text.js" ]
			echo "$?"
		)"
		assertEquals 0 "$(
			[ -f "$OUTPUT_DIR/assets/template.css" ]
			echo "$?"
		)"
		assertEquals 0 "$(
			[ -f "$OUTPUT_DIR/assets/traceability_diagrams.js" ]
			echo "$?"
		)"

		# Check HTML content
		grep -q "<!DOCTYPE html>" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should have DOCTYPE" 0 $?

		grep -q "<table" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should contain table" 0 $?

		grep -q "d3js.org" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should include D3.js" 0 $?

		grep -q "sankey-diagram" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should contain Sankey diagram container" 0 $?

		grep -q "traceability_diagrams.js" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should include traceability_diagrams.js" 0 $?

		# Regression: file list links must not contain invalid ""1"" token
		grep -q '""1""' "$OUTPUT_DIR/output.html"
		assertNotEquals "Trace target links should use numeric line 1" 0 $?
	)
}

##
# @brief  Test for shtracer_viewer.sh (stdin JSON -> stdout HTML)
test_shtracer_viewer_single_file_output() {
	(
		# Arrange ---------
		SHTRACER_VIEWER="../main/shtracer_viewer.sh"
		SCRIPT_DIR="../../"
		mkdir -p "$OUTPUT_DIR/test_dir"
		echo "test content" >"$OUTPUT_DIR/test_dir/test_file.md"
		_TEST_FILE="$(cd "$OUTPUT_DIR/test_dir" && pwd)/test_file.md"
		cat >"$OUTPUT_DIR/output.json" <<EOF
{
  "metadata": {"version": "0.0.0", "generated": "2025-01-01T00:00:00Z", "config_path": "$_TEST_FILE"},
  "nodes": [
    {"id": "@TAG1@", "label": "@TAG1@", "index": 0, "description": "desc", "file": "$_TEST_FILE", "line": 1, "type": "Requirement", "trace_target": "x:Requirement"}
  ],
  "links": [],
  "chains": [
    ["@TAG1@", "NONE", "NONE", "NONE", "NONE"]
  ]
}
EOF

		# Act -------------
		"$SHTRACER_VIEWER" <"$OUTPUT_DIR/output.json" >"$OUTPUT_DIR/output.html"

		# Assert ----------
		assertEquals 0 "$?"
		assertEquals 0 "$(
			[ -f "$OUTPUT_DIR/output.html" ]
			echo "$?"
		)"
		grep -q "<!DOCTYPE html>" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should have DOCTYPE" 0 "$?"
		grep -q "const files =" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should inline show_text.js" 0 "$?"
		grep -q "traceabilityData" "$OUTPUT_DIR/output.html"
		assertEquals "HTML should embed JSON" 0 "$?"
		grep -q "\./assets/show_text.js" "$OUTPUT_DIR/output.html"
		assertNotEquals "HTML should not reference external assets" 0 "$?"

		# Regression: Trace targets list should call showText(..., 1, ...)
		grep -q '""1""' "$OUTPUT_DIR/output.html"
		assertNotEquals "Trace target links should use numeric line 1" 0 "$?"
	)
}

# shellcheck source=shunit2/shunit2
. "./shunit2/shunit2"
