#!/bin/sh
# Unit tests for file version information helpers
# Tests git hash extraction and timestamp formatting

# Source test target
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

TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"

##
# @brief OneTimeSetUp function
#
oneTimeSetUp() {
	echo "----------------------------------------"
	echo " TEST : File Version Information"
	echo "----------------------------------------"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	# Create temporary directory for test files
	TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'shtracer_test')"
	export TEMP_DIR
}

##
# @brief TearDown function for each test
#
tearDown() {
	# Clean up temporary directory
	if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
		rm -rf "$TEMP_DIR"
	fi
	set -u
}

# ============================================================================
# get_file_version_info() Tests
# ============================================================================

##
# @brief Test get_file_version_info with git-tracked file
#
test_get_file_version_info_git_repo() {
	# Skip if git not available
	if ! command -v git >/dev/null 2>&1; then
		startSkipping
		return
	fi

	# Create test git repo
	_test_dir="${TEMP_DIR}/git_test"
	mkdir -p "$_test_dir"
	(
		cd "$_test_dir" || return 1
		git init >/dev/null 2>&1
		git config user.email "test@example.com"
		git config user.name "Test User"
		echo "test content" >test_file.md
		git add test_file.md >/dev/null 2>&1
		git commit -m "Test commit" >/dev/null 2>&1
	)

	# Act
	_result="$(get_file_version_info "$_test_dir/test_file.md")"

	# Assert - should start with "git:"
	assertContains "$_result" "git:"

	# Assert - should be 7 chars after "git:"
	_hash_part="${_result#git:}"
	_hash_len="$(printf '%s' "$_hash_part" | wc -c)"
	assertEquals "7" "$_hash_len"
}

##
# @brief Test get_file_version_info with non-git file
#
test_get_file_version_info_no_git() {
	# Create test file NOT in git repo
	_test_file="${TEMP_DIR}/temp_test_file.md"
	echo "test content" >"$_test_file"

	# Act
	_result="$(get_file_version_info "$_test_file")"

	# Assert - should start with "mtime:" or "unknown"
	case "$_result" in
		mtime:* | unknown)
			assertTrue "Result is mtime: or unknown" true
			;;
		*)
			fail "Expected mtime: or unknown, got: $_result"
			;;
	esac
}

##
# @brief Test get_file_version_info with non-existent file
#
test_get_file_version_info_nonexistent() {
	# Act
	_result="$(get_file_version_info "/nonexistent/path/to/file.md" 2>/dev/null)"

	# Assert - should return "unknown"
	assertEquals "unknown" "$_result"
}

##
# @brief Test get_file_version_info with file containing spaces
#
test_get_file_version_info_spaces_in_path() {
	# Create file with spaces in name
	_test_file="${TEMP_DIR}/test file with spaces.md"
	echo "test" >"$_test_file"

	# Act
	_result="$(get_file_version_info "$_test_file")"

	# Assert - should not fail
	assertNotEquals "" "$_result"
}

# ============================================================================
# format_version_info_short() Tests
# ============================================================================

##
# @brief Test format_version_info_short with git hash
#
test_format_version_info_short_git() {
	# Act
	_result="$(format_version_info_short "git:abc1234")"

	# Assert
	assertEquals "abc1234" "$_result"
}

##
# @brief Test format_version_info_short with longer git hash
#
test_format_version_info_short_git_long() {
	# Act
	_result="$(format_version_info_short "git:1a2b3c4")"

	# Assert
	assertEquals "1a2b3c4" "$_result"
}

##
# @brief Test format_version_info_short with mtime
#
test_format_version_info_short_mtime() {
	# Act
	_result="$(format_version_info_short "mtime:2025-12-26T10:30:45Z")"

	# Assert - should be "2025-12-26 10:30"
	assertEquals "2025-12-26 10:30" "$_result"
}

##
# @brief Test format_version_info_short with different mtime
#
test_format_version_info_short_mtime_midnight() {
	# Act
	_result="$(format_version_info_short "mtime:2025-01-01T00:00:00Z")"

	# Assert
	assertEquals "2025-01-01 00:00" "$_result"
}

##
# @brief Test format_version_info_short with unknown
#
test_format_version_info_short_unknown() {
	# Act
	_result="$(format_version_info_short "unknown")"

	# Assert - should return as-is
	assertEquals "unknown" "$_result"
}

##
# @brief Test format_version_info_short with empty string
#
test_format_version_info_short_empty() {
	# Act
	_result="$(format_version_info_short "")"

	# Assert - should return empty
	assertEquals "" "$_result"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
