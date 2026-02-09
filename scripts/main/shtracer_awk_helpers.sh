#!/bin/sh

# shtracer_awk_helpers.sh - Shared AWK helper functions for shtracer
#
# This file loads reusable AWK function definitions from standalone .awk files
# and exports them as shell variables for string injection into AWK scripts.
#
# Source .awk files (single source of truth):
#   awk/common.awk           - trim, get_last_segment, escape_html, json_escape,
#                              basename, ext_from_basename, fileid_from_path,
#                              type_from_trace_target
#   awk/field_extractors.awk - field1 through field6
#
# Note: POSIX awk does not support combining -f with inline program text,
# so consumer scripts use string injection: awk "$AWK_FN_COMMON"'...code...'
# The .awk files serve as the canonical source for testability, syntax
# highlighting, and linting. Shell variables are loaded from them at startup.
#
# shellcheck disable=SC2089,SC2090
# SC2089/SC2090: Variables contain AWK code to be passed to awk, not shell-executed
#
# @tag @IMP4.5@ (FROM: @ARC1.2@)

# Prevent double-sourcing
if [ -n "${_SHTRACER_AWK_HELPERS_LOADED:-}" ]; then
	# shellcheck disable=SC2317
	return 0 2>/dev/null || exit 0
fi
_SHTRACER_AWK_HELPERS_LOADED=1

# ============================================================================
# AWK library directory (standalone .awk files)
# ============================================================================
_UTIL_SCRIPT_DIR="${_UTIL_SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
AWK_LIB_DIR="${_UTIL_SCRIPT_DIR}/awk"
export AWK_LIB_DIR

# ============================================================================
# Load AWK functions from standalone .awk files
# ============================================================================

# Load common.awk (all 8 shared utility functions)
if [ -f "${AWK_LIB_DIR}/common.awk" ]; then
	AWK_FN_COMMON=$(cat "${AWK_LIB_DIR}/common.awk")
else
	printf '[shtracer][warn] AWK library not found: %s/common.awk\n' "$AWK_LIB_DIR" >&2
	AWK_FN_COMMON=""
fi

# Load field_extractors.awk (field1-field6)
if [ -f "${AWK_LIB_DIR}/field_extractors.awk" ]; then
	AWK_FN_FIELD_EXTRACTORS=$(cat "${AWK_LIB_DIR}/field_extractors.awk")
else
	printf '[shtracer][warn] AWK library not found: %s/field_extractors.awk\n' "$AWK_LIB_DIR" >&2
	AWK_FN_FIELD_EXTRACTORS=""
fi

# ============================================================================
# Individual function variables (subsets of common.awk for selective injection)
# ============================================================================

##
# @brief AWK function: Remove leading and trailing whitespace
# @example trim("  text  ") returns "text"
AWK_FN_TRIM='
function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}
'

##
# @brief AWK function: Extract last segment after delimiter (typically ":")
# @example get_last_segment("A:B:C") returns "C"
AWK_FN_GET_LAST_SEGMENT='
function get_last_segment(s,   n, parts) {
	n = split(s, parts, ":")
	return n > 0 ? parts[n] : s
}
'

##
# @brief AWK function: Escape HTML special characters
# @example escape_html("<script>") returns "&lt;script&gt;"
AWK_FN_ESCAPE_HTML='
function escape_html(s,   t) {
	t = s
	gsub(/&/, "\\&amp;", t)
	gsub(/</, "\\&lt;", t)
	gsub(/>/, "\\&gt;", t)
	gsub(/"/, "\\&quot;", t)
	return t
}
'

##
# @brief AWK function: Escape JSON special characters
# @example json_escape("line\nnewline") returns "line\\nnewline"
AWK_FN_JSON_ESCAPE='
function json_escape(s,   result) {
	result = s
	gsub(/\\/, "\\\\", result)
	gsub(/"/, "\\\"", result)
	gsub(/\n/, "\\n", result)
	gsub(/\r/, "\\r", result)
	gsub(/\t/, "\\t", result)
	return result
}
'

##
# @brief AWK function: Extract basename from path
# @example basename("/path/to/file.txt") returns "file.txt"
AWK_FN_BASENAME='
function basename(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	return t
}
'

##
# @brief AWK function: Extract file extension from basename
# @example ext_from_basename("file.txt") returns "txt"
AWK_FN_EXT_FROM_BASENAME='
function ext_from_basename(base) {
	if (match(base, /\.[^\.]+$/)) return substr(base, RSTART + 1)
	return "sh"
}
'

##
# @brief AWK function: Generate file ID from path (for HTML viewer)
# @example fileid_from_path("/path/to/file.txt") returns "Target_file_txt"
AWK_FN_FILEID_FROM_PATH='
function fileid_from_path(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	gsub(/\./, "_", t)
	return "Target_" t
}
'

##
# @brief AWK function: Extract layer/type from trace_target string
# @example type_from_trace_target(":Main:Implementation") returns "Implementation"
AWK_FN_TYPE_FROM_TRACE_TARGET='
function type_from_trace_target(tt,   n, p, t) {
	if (tt == "") return "Unknown"
	n = split(tt, p, ":")
	t = p[n]
	sub(/^[[:space:]]+/, "", t)
	sub(/[[:space:]]+$/, "", t)
	return t == "" ? "Unknown" : t
}
'

##
# @brief Shell function: Generate AWK code with common functions included
# @param $1 : AWK script body (the main processing logic)
# @return Complete AWK script with helper functions prepended
# @example awk_with_helpers 'BEGIN { print trim("  hello  ") }'
awk_with_helpers() {
	_awk_body="$1"
	printf '%s\n%s' "$AWK_FN_COMMON" "$_awk_body"
}

##
# @brief Shell function: Run AWK with common helper functions
# @param $@ : Arguments passed to awk (script should use helper functions)
# @example run_awk_with_helpers -v sep="$SEP" 'BEGIN { print trim("  test  ") }' file.txt
run_awk_with_helpers() {
	# Collect all args until we find one that doesn't start with -
	_awk_args=""
	_awk_script=""
	_found_script=0

	for _arg in "$@"; do
		if [ "$_found_script" -eq 0 ]; then
			case "$_arg" in
				-*)
					_awk_args="$_awk_args $_arg"
					;;
				*)
					_awk_script="$_arg"
					_found_script=1
					;;
			esac
		fi
	done
	shift $(($(echo "$@" | wc -w) - 1))

	# Prepend helper functions to script
	_full_script="$AWK_FN_COMMON
$_awk_script"

	# shellcheck disable=SC2086
	awk $_awk_args "$_full_script" "$@"
}

# Export variables and AWK_LIB_DIR for subshells
export AWK_LIB_DIR
export AWK_FN_TRIM
export AWK_FN_GET_LAST_SEGMENT
export AWK_FN_ESCAPE_HTML
export AWK_FN_JSON_ESCAPE
export AWK_FN_BASENAME
export AWK_FN_EXT_FROM_BASENAME
export AWK_FN_FILEID_FROM_PATH
export AWK_FN_FIELD_EXTRACTORS
export AWK_FN_TYPE_FROM_TRACE_TARGET
export AWK_FN_COMMON
