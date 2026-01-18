#!/bin/sh

##
# @file    shtracer_json_unittest.sh
# @brief   Unit tests for JSON export functionality
#

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi
TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"

# shellcheck source=../../main/shtracer_func.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_func.sh"

##
# @brief
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " UNIT TEST (JSON Export) : $0"
	echo "----------------------------------------"
}

##
# @brief  SetUp function for each test
#
setUp() {
	set +u
	export SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="${SHUNIT_TMPDIR}/output/"
	mkdir -p "$OUTPUT_DIR"
	export CONFIG_DIR="${TEST_ROOT%/}/unit_test/testdata/"
	cd "${TEST_ROOT}" || exit 1
}

##
# @brief TearDown function for each test
#
tearDown() {
	rm -rf "$OUTPUT_DIR"
}

##
# @brief  Test basic JSON file creation and validity
# @tag    @IMP2.8.1@ (FROM: @IMP2.8@)
test_make_json_basic() {
	# Setup test data
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	# Create test data
	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>First requirement<shtracer_separator>/path/to/file1.md<shtracer_separator>10<shtracer_separator>1<shtracer_separator>unknown
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>NONE<shtracer_separator>First architecture<shtracer_separator>/path/to/file2.md<shtracer_separator>20<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
@REQ1.1@	@ARC1.1@
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
@ARC1.1@	NONE
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	@ARC1.1@	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
:Architecture<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@ARC[0-9\.]+@
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/path/to/config.md")"

	# Verify file exists
	assertTrue "JSON file should exist" "[ -f '$_JSON_OUTPUT' ]"

	# Verify JSON is valid (basic check)
	_JSON_CONTENT="$(cat "$_JSON_OUTPUT")"
	assertTrue "JSON should contain metadata" "echo '$_JSON_CONTENT' | grep -q 'metadata'"
	assertTrue "JSON should contain health" "echo '$_JSON_CONTENT' | grep -q 'health'"
	assertTrue "JSON should contain files array" "echo '$_JSON_CONTENT' | grep -q '\"files\":'"
	assertTrue "JSON should contain layers array" "echo '$_JSON_CONTENT' | grep -q '\"layers\":'"
	assertTrue "JSON should contain trace_tags" "echo '$_JSON_CONTENT' | grep -q 'trace_tags'"
	assertTrue "JSON should contain chains" "echo '$_JSON_CONTENT' | grep -q 'chains'"
	assertFalse "JSON should NOT contain nodes" "echo '$_JSON_CONTENT' | grep -q '\"nodes\":'"
	assertFalse "JSON should NOT contain links" "echo '$_JSON_CONTENT' | grep -q '\"links\":'"
}

##
# @brief  Test JSON metadata fields
# @tag    @IMP2.8.2@ (FROM: @IMP2.8@)
test_make_json_metadata() {
	# Setup test data (minimal)
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
:Main scripts:Implementation<shtracer_separator>@IMP2.1@<shtracer_separator>@ARC2.1@<shtracer_separator>check_configfile() {<shtracer_separator>/home/qq3g7bad/Desktop/repo/shtracer/scripts/main/shtracer_func.sh<shtracer_separator>122<shtracer_separator>1<shtracer_separator>unknown
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>1<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	NONE	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
:Main scripts:Implementation<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@IMP[0-9\.]+@
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/test/config.md")"

	# Verify metadata
	assertTrue "Should contain generated timestamp" "grep -q '\"generated\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain config path" "grep -q '\"config_path\": \"/test/config.md\"' '$_JSON_OUTPUT'"
}

##
# @brief  Test JSON nodes structure
# @tag    @IMP2.8.3@ (FROM: @IMP2.8@)
test_make_json_nodes() {
	# Setup test data
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>1<shtracer_separator>1<shtracer_separator>unknown
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>NONE<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>2<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	NONE	NONE	NONE	NONE
@ARC1.1@	NONE	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
:Architecture<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@ARC[0-9\.]+@
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify trace_tags
	assertTrue "Should contain trace_tags array" "grep -q '\"trace_tags\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain at least one tag" "grep -q '\"id\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain file_id field" "grep -q '\"file_id\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain from_tags field" "grep -q '\"from_tags\":' '$_JSON_OUTPUT'"
	assertFalse "Should NOT contain nodes array" "grep -q '\"nodes\":' '$_JSON_OUTPUT'"
}

##
# @brief  Test JSON links structure
# @tag    @IMP2.8.4@ (FROM: @IMP2.8@)
test_make_json_links() {
	# Setup test data
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Req<shtracer_separator>/file1<shtracer_separator>1<shtracer_separator>1<shtracer_separator>unknown
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>@REQ1.1@<shtracer_separator>Arc<shtracer_separator>/file2<shtracer_separator>2<shtracer_separator>1<shtracer_separator>unknown
Implementation<shtracer_separator>@IMP1.1@<shtracer_separator>@ARC1.1@<shtracer_separator>Imp<shtracer_separator>/file3<shtracer_separator>3<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
@REQ1.1@	@ARC1.1@
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
@ARC1.1@	@IMP1.1@
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	@ARC1.1@	@IMP1.1@	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
:Architecture<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@ARC[0-9\.]+@
:Implementation<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@IMP[0-9\.]+@
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify links via from_tags array in trace_tags (v0.2.0 format)
	assertTrue "Should contain REQ->ARC link via from_tags" "grep -A5 '\"id\": \"@ARC1.1@\"' '$_JSON_OUTPUT' | grep -q '\"from_tags\": \[\"@REQ1.1@\"\]'"
	assertTrue "Should contain ARC->IMP link via from_tags" "grep -A5 '\"id\": \"@IMP1.1@\"' '$_JSON_OUTPUT' | grep -q '\"from_tags\": \[\"@ARC1.1@\"\]'"
	assertFalse "Should NOT contain links array" "grep -q '\"links\":' '$_JSON_OUTPUT'"
}

##
# @brief  Test JSON preserves multiple upstream tags
# @tag    @IMP2.8.4@ (FROM: @IMP2.8@)
test_make_json_multiple_from_tags() {
	# Setup test data
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Req1<shtracer_separator>/file1<shtracer_separator>1<shtracer_separator>1<shtracer_separator>unknown
Requirement<shtracer_separator>@REQ1.2@<shtracer_separator>NONE<shtracer_separator>Req2<shtracer_separator>/file1<shtracer_separator>2<shtracer_separator>1<shtracer_separator>unknown
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>@REQ1.1@, @REQ1.2@<shtracer_separator>Arc<shtracer_separator>/file2<shtracer_separator>3<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
@REQ1.1@	@ARC1.1@
@REQ1.2@	@ARC1.1@
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	@ARC1.1@	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
:Architecture<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@ARC[0-9\.]+@
EOF

	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	assertTrue "Should contain from_tags array with both upstreams" \
		"grep -A6 '\"id\": \"@ARC1.1@\"' '$_JSON_OUTPUT' | grep -q '\"from_tags\": \[\"@REQ1.1@\", \"@REQ1.2@\"\]'"
}

##
# @brief  Test JSON chains structure
# @tag    @IMP2.8.5@ (FROM: @IMP2.8@)
test_make_json_chains() {
	# Setup test data
	_TAG_OUTPUT_DATA="${SHUNIT_TMPDIR}/01_tags_test"
	_TAG_PAIRS="${SHUNIT_TMPDIR}/02_tag_pairs_test"
	_TAG_PAIRS_DOWNSTREAM="${SHUNIT_TMPDIR}/03_tag_pairs_downstream_test"
	_TAG_TABLE="${SHUNIT_TMPDIR}/04_tag_table_test"
	_CONFIG_TABLE="${SHUNIT_TMPDIR}/01_config_table_test"

	cat >"$_TAG_OUTPUT_DATA" <<'EOF'
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Req<shtracer_separator>/file1<shtracer_separator>1<shtracer_separator>1<shtracer_separator>unknown
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	@ARC1.1@	@IMP1.1@	NONE	NONE
@REQ2.1@	NONE	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
:Requirement<shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator><shtracer_separator>@REQ[0-9\.]+@
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify chains
	assertTrue "Should contain chains array" "grep -q '\"chains\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain first chain with REQ1.1" "grep -A5 '\"chains\":' '$_JSON_OUTPUT' | grep -q '@REQ1.1@'"
	assertTrue "Should contain second chain with REQ2.1" "grep -A10 '\"chains\":' '$_JSON_OUTPUT' | grep -q '@REQ2.1@'"
}

# Load and run shUnit2
# shellcheck source=shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
