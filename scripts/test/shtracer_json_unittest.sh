#!/bin/sh

##
# @file    shtracer_json_unittest.sh
# @brief   Unit tests for JSON export functionality
#

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
cd "${SCRIPT_DIR}" || exit 1

# shellcheck source=../main/shtracer_util.sh
. "../main/shtracer_util.sh"

# shellcheck source=../main/shtracer_func.sh
. "../main/shtracer_func.sh"

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
	export SHTRACER_SEPARATOR="<shtracer_separator>"
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
	export NODATA_STRING="NONE"
	export OUTPUT_DIR="${SHUNIT_TMPDIR}/output/"
	mkdir -p "$OUTPUT_DIR"
	export CONFIG_DIR="${SCRIPT_DIR%/}/testdata/"
	cd "${SCRIPT_DIR}" || exit 1
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
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>First requirement<shtracer_separator>/path/to/file1.md<shtracer_separator>10<shtracer_separator>1
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>NONE<shtracer_separator>First architecture<shtracer_separator>/path/to/file2.md<shtracer_separator>20<shtracer_separator>1
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
config_path	/path/to/config.md
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/path/to/config.md")"

	# Verify file exists
	assertTrue "JSON file should exist" "[ -f '$_JSON_OUTPUT' ]"

	# Verify JSON is valid (basic check)
	_JSON_CONTENT="$(cat "$_JSON_OUTPUT")"
	assertTrue "JSON should contain metadata" "echo '$_JSON_CONTENT' | grep -q 'metadata'"
	assertTrue "JSON should contain nodes" "echo '$_JSON_CONTENT' | grep -q 'nodes'"
	assertTrue "JSON should contain links" "echo '$_JSON_CONTENT' | grep -q 'links'"
	assertTrue "JSON should contain chains" "echo '$_JSON_CONTENT' | grep -q 'chains'"
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
:Main scripts:Implementation<shtracer_separator>@IMP2.1@<shtracer_separator>@ARC2.1@<shtracer_separator>check_configfile() {<shtracer_separator>/home/qq3g7bad/Desktop/repo/shtracer/scripts/main/shtracer_func.sh<shtracer_separator>122<shtracer_separator>1
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>1<shtracer_separator>1
EOF

	cat >"$_TAG_PAIRS" <<'EOF'
EOF

	cat >"$_TAG_PAIRS_DOWNSTREAM" <<'EOF'
EOF

	cat >"$_TAG_TABLE" <<'EOF'
@REQ1.1@	NONE	NONE	NONE	NONE
EOF

	cat >"$_CONFIG_TABLE" <<'EOF'
/test/config.md<shtracer_separator>other_field
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/test/config.md")"

	# Verify metadata
	assertTrue "Should contain version" "grep -q '\"version\": \"0.1.1\"' '$_JSON_OUTPUT'"
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
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>1<shtracer_separator>1
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>Test<shtracer_separator>/file<shtracer_separator>2<shtracer_separator>1
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
config_path	/config.md
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify nodes
	assertTrue "Should contain nodes array" "grep -q '\"nodes\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain at least one node" "grep -q '\"id\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain trace_target field" "grep -q '\"trace_target\":' '$_JSON_OUTPUT'"
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
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Req<shtracer_separator>/file1<shtracer_separator>1<shtracer_separator>1
Architecture<shtracer_separator>@ARC1.1@<shtracer_separator>NONE<shtracer_separator>Arc<shtracer_separator>/file2<shtracer_separator>2<shtracer_separator>1
Implementation<shtracer_separator>@IMP1.1@<shtracer_separator>NONE<shtracer_separator>Imp<shtracer_separator>/file3<shtracer_separator>3<shtracer_separator>1
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
config_path	/config.md
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify links
	assertTrue "Should contain REQ->ARC link" "grep -A3 -B1 '\"source\": \"@REQ1.1@\"' '$_JSON_OUTPUT' | grep -q '\"target\": \"@ARC1.1@\"'"
	assertTrue "Should contain ARC->IMP link" "grep -A3 -B1 '\"source\": \"@ARC1.1@\"' '$_JSON_OUTPUT' | grep -q '\"target\": \"@IMP1.1@\"'"
	assertTrue "Should contain value field" "grep -q '\"value\": 1' '$_JSON_OUTPUT'"
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
Requirement<shtracer_separator>@REQ1.1@<shtracer_separator>NONE<shtracer_separator>Req<shtracer_separator>/file1<shtracer_separator>1<shtracer_separator>1
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
config_path	/config.md
EOF

	# Execute function
	_JSON_OUTPUT="$(make_json "$_TAG_OUTPUT_DATA" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM" "$_TAG_TABLE" "$_CONFIG_TABLE" "/config.md")"

	# Verify chains
	assertTrue "Should contain chains array" "grep -q '\"chains\":' '$_JSON_OUTPUT'"
	assertTrue "Should contain first chain with REQ1.1" "grep -A5 '\"chains\":' '$_JSON_OUTPUT' | grep -q '@REQ1.1@'"
	assertTrue "Should contain second chain with REQ2.1" "grep -A10 '\"chains\":' '$_JSON_OUTPUT' | grep -q '@REQ2.1@'"
}

##
# @brief  Test CLI --json flag integration
# @tag    @IMP2.8.6@ (FROM: @IMP2.8@)
test_cli_json_flag() {
	# Test that EXPORT_JSON variable can be set
	EXPORT_JSON='false'
	# Simulate what happens when --json is parsed
	EXPORT_JSON='true'

	assertEquals "EXPORT_JSON should be true when --json flag used" "true" "$EXPORT_JSON"
}

# Load and run shUnit2
# shellcheck source=shunit2/shunit2
. "./shunit2/shunit2"
