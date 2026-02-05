#!/bin/sh
# Exit code validation tests
# Tests all 13 exit codes defined in shtracer

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

SHTRACER_BIN="${SHTRACER_ROOT_DIR%/}/shtracer"
TEST_DATA_DIR="${SCRIPT_DIR%/}/testdata_exit_codes"

##
# @brief OneTimeSetUp function
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " INTEGRATION TEST (Exit Codes) : $0"
	echo "----------------------------------------"
	mkdir -p "$TEST_DATA_DIR"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	rm -rf "${TEST_DATA_DIR}/shtracer_output/"
	rm -f "${TEST_DATA_DIR}"/*.md
}

##
# @brief TearDown function for each test
#
tearDown() {
	rm -rf "${TEST_DATA_DIR}/shtracer_output/"
	rm -f "${TEST_DATA_DIR}"/*.md
}

##
# @brief OneTimeTearDown function
#
oneTimeTearDown() {
	rm -rf "$TEST_DATA_DIR"
}

##
# @brief Test exit code 0 (success)
# @tag @IT4.1@
test_exit_code_0_success() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	echo "<!-- @REQ1@ --> Requirement 1" >"${TEST_DATA_DIR}/req.md"

	# Act
	"$SHTRACER_BIN" "${TEST_DATA_DIR}/config.md" >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 0 on success" 0 "$_exit_code"
}

##
# @brief Test exit code 1 (invalid arguments)
# @tag @IT4.2@
test_exit_code_1_invalid_usage() {
	# Act
	"$SHTRACER_BIN" --invalid-option >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 1 for invalid arguments" 1 "$_exit_code"
}

##
# @brief Test exit code 2 (config not found)
# @tag @IT4.3@
test_exit_code_2_config_not_found() {
	# Act
	"$SHTRACER_BIN" /nonexistent/config.md >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 2 for missing config" 2 "$_exit_code"
}

##
# @brief Test exit code 20 (isolated tags in verify mode)
# @tag @IT4.4@
test_exit_code_20_isolated_tags() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`

## Architecture
* **PATH**: "./arch.md"
* **TAG FORMAT**: `@ARC[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	echo "<!-- @REQ1@ --> Requirement 1" >"${TEST_DATA_DIR}/req.md"
	echo "<!-- @ARC1@ --> Architecture 1 (no FROM tag - isolated)" >"${TEST_DATA_DIR}/arch.md"

	# Act
	"$SHTRACER_BIN" -v "${TEST_DATA_DIR}/config.md" >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 20 for isolated tags" 20 "$_exit_code"
}

##
# @brief Test exit code 21 (duplicate tags in verify mode)
# @tag @IT4.5@
test_exit_code_21_duplicate_tags() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	cat >"${TEST_DATA_DIR}/req.md" <<'EOF'
<!-- @REQ1@ --> First occurrence
<!-- @REQ1@ --> Duplicate occurrence
EOF

	# Act
	"$SHTRACER_BIN" -v "${TEST_DATA_DIR}/config.md" >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 21 for duplicate tags" 21 "$_exit_code"
}

##
# @brief Test exit code 22 (dangling FROM tags in verify mode)
# @tag @IT4.6@
test_exit_code_22_dangling_from_tags() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`

## Architecture
* **PATH**: "./arch.md"
* **TAG FORMAT**: `@ARC[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	echo "<!-- @REQ1@ --> Requirement 1" >"${TEST_DATA_DIR}/req.md"
	echo "<!-- @ARC1@ (FROM: @REQ999@) --> Architecture references nonexistent REQ999" >"${TEST_DATA_DIR}/arch.md"

	# Act
	"$SHTRACER_BIN" -v "${TEST_DATA_DIR}/config.md" >/dev/null 2>&1
	_exit_code=$?

	# Assert
	assertEquals "Should exit with 22 for dangling FROM tags" 22 "$_exit_code"
}

##
# @brief Test verify mode priority: duplicate (21) > dangling (22) > isolated (20)
# @tag @IT4.7@
test_verify_mode_error_priority() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`

## Architecture
* **PATH**: "./arch.md"
* **TAG FORMAT**: `@ARC[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	cat >"${TEST_DATA_DIR}/req.md" <<'EOF'
<!-- @REQ1@ --> Requirement 1
<!-- @REQ1@ --> Duplicate REQ1
EOF

	cat >"${TEST_DATA_DIR}/arch.md" <<'EOF'
<!-- @ARC1@ (FROM: @REQ999@) --> Dangling FROM
<!-- @ARC2@ --> Isolated (no FROM)
EOF

	# Act
	_output=$("$SHTRACER_BIN" -v "${TEST_DATA_DIR}/config.md" 2>&1)
	_exit_code=$?

	# Assert: Exit code should be 21 (duplicate has highest priority)
	assertEquals "Should exit with 21 (highest priority error)" 21 "$_exit_code"

	# Verify all errors are reported
	echo "$_output" | grep -q "duplicated_tags"
	assertEquals "Should report duplicate tags" 0 $?

	echo "$_output" | grep -q "dangling_tags"
	assertEquals "Should report dangling tags" 0 $?

	echo "$_output" | grep -q "isolated_tags"
	assertEquals "Should report isolated tags" 0 $?
}

##
# @brief Test error message format compliance
# @tag @IT4.8@
test_error_message_format() {
	# Arrange
	cat >"${TEST_DATA_DIR}/config.md" <<'EOF'
## Requirement
* **PATH**: "./req.md"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
EOF

	cat >"${TEST_DATA_DIR}/req.md" <<'EOF'
<!-- @REQ1@ --> First
<!-- @REQ1@ --> Duplicate
EOF

	# Act
	_output=$("$SHTRACER_BIN" -v "${TEST_DATA_DIR}/config.md" 2>&1)

	# Assert: Error format should be [shtracer][error][type]
	echo "$_output" | grep -qE '\[shtracer\]\[error\]\[duplicated_tags\]'
	assertEquals "Error messages should follow format [shtracer][error][type]" 0 $?
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
