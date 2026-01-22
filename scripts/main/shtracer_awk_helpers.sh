#!/bin/sh

# shtracer_awk_helpers.sh - Shared AWK helper functions for shtracer
#
# This file provides reusable AWK function definitions that can be embedded
# into AWK scripts. Functions are exported as shell variables containing
# AWK code strings that can be included via -v or direct interpolation.
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

##
# @brief AWK function: Remove leading and trailing whitespace
# @usage Include in AWK via: -v trim_fn="$AWK_FN_TRIM" then eval trim_fn in BEGIN
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
# @usage get_last_segment("A:B:C") returns "C"
AWK_FN_GET_LAST_SEGMENT='
function get_last_segment(s,   n, parts) {
	n = split(s, parts, ":")
	return n > 0 ? parts[n] : s
}
'

##
# @brief AWK function: Escape HTML special characters
# @usage escape_html("<script>") returns "&lt;script&gt;"
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
# @usage json_escape("line\nnewline") returns "line\\nnewline"
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
# @usage basename("/path/to/file.txt") returns "file.txt"
AWK_FN_BASENAME='
function basename(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	return t
}
'

##
# @brief AWK function: Extract file extension from basename
# @usage ext_from_basename("file.txt") returns "txt"
AWK_FN_EXT_FROM_BASENAME='
function ext_from_basename(base) {
	if (match(base, /\.[^\.]+$/)) return substr(base, RSTART + 1)
	return "sh"
}
'

##
# @brief AWK function: Generate file ID from path (for HTML viewer)
# @usage fileid_from_path("/path/to/file.txt") returns "Target_file_txt"
AWK_FN_FILEID_FROM_PATH='
function fileid_from_path(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	gsub(/\./, "_", t)
	return "Target_" t
}
'

##
# @brief AWK functions: Field extractors for delimiter-separated strings
# @details These functions extract specific fields from strings using a delimiter.
#          Unlike AWK -F which has issues with multi-character delimiters,
#          these use index() for reliable extraction.
# @usage field1("a<sep>b<sep>c", "<sep>") returns "a"
AWK_FN_FIELD_EXTRACTORS='
function field1(s, delim,   p1) {
	p1 = index(s, delim)
	if (p1 <= 0) return s
	return substr(s, 1, p1 - 1)
}
function field2(s, delim,   rest, p1, p2) {
	p1 = index(s, delim)
	if (p1 <= 0) return ""
	rest = substr(s, p1 + length(delim))
	p2 = index(rest, delim)
	if (p2 <= 0) return rest
	return substr(rest, 1, p2 - 1)
}
function field3(s, delim,   rest, p1, p2, p3) {
	p1 = index(s, delim)
	if (p1 <= 0) return ""
	rest = substr(s, p1 + length(delim))
	p2 = index(rest, delim)
	if (p2 <= 0) return ""
	rest = substr(rest, p2 + length(delim))
	p3 = index(rest, delim)
	if (p3 <= 0) return rest
	return substr(rest, 1, p3 - 1)
}
function field4(s, delim,   rest, p1, p2, p3, p4) {
	p1 = index(s, delim)
	if (p1 <= 0) return ""
	rest = substr(s, p1 + length(delim))
	p2 = index(rest, delim)
	if (p2 <= 0) return ""
	rest = substr(rest, p2 + length(delim))
	p3 = index(rest, delim)
	if (p3 <= 0) return ""
	rest = substr(rest, p3 + length(delim))
	p4 = index(rest, delim)
	if (p4 <= 0) return rest
	return substr(rest, 1, p4 - 1)
}
function field5(s, delim,   rest, p1, p2, p3, p4, p5) {
	p1 = index(s, delim)
	if (p1 <= 0) return ""
	rest = substr(s, p1 + length(delim))
	p2 = index(rest, delim)
	if (p2 <= 0) return ""
	rest = substr(rest, p2 + length(delim))
	p3 = index(rest, delim)
	if (p3 <= 0) return ""
	rest = substr(rest, p3 + length(delim))
	p4 = index(rest, delim)
	if (p4 <= 0) return ""
	rest = substr(rest, p4 + length(delim))
	p5 = index(rest, delim)
	if (p5 <= 0) return rest
	return substr(rest, 1, p5 - 1)
}
function field6(s, delim,   rest, p1, p2, p3, p4, p5, p6) {
	p1 = index(s, delim)
	if (p1 <= 0) return ""
	rest = substr(s, p1 + length(delim))
	p2 = index(rest, delim)
	if (p2 <= 0) return ""
	rest = substr(rest, p2 + length(delim))
	p3 = index(rest, delim)
	if (p3 <= 0) return ""
	rest = substr(rest, p3 + length(delim))
	p4 = index(rest, delim)
	if (p4 <= 0) return ""
	rest = substr(rest, p4 + length(delim))
	p5 = index(rest, delim)
	if (p5 <= 0) return ""
	rest = substr(rest, p5 + length(delim))
	p6 = index(rest, delim)
	if (p6 <= 0) return rest
	return substr(rest, 1, p6 - 1)
}
'

##
# @brief AWK function: Extract layer/type from trace_target string
# @usage type_from_trace_target(":Main:Implementation") returns "Implementation"
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
# @brief Combined AWK helper functions for common use cases
# @details Combines all commonly used functions for convenience
AWK_FN_COMMON='
function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}
function get_last_segment(s,   n, parts) {
	n = split(s, parts, ":")
	return n > 0 ? parts[n] : s
}
function escape_html(s,   t) {
	t = s
	gsub(/&/, "\\&amp;", t)
	gsub(/</, "\\&lt;", t)
	gsub(/>/, "\\&gt;", t)
	gsub(/"/, "\\&quot;", t)
	return t
}
function json_escape(s,   result) {
	result = s
	gsub(/\\/, "\\\\", result)
	gsub(/"/, "\\\"", result)
	gsub(/\n/, "\\n", result)
	gsub(/\r/, "\\r", result)
	gsub(/\t/, "\\t", result)
	return result
}
function basename(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	return t
}
function ext_from_basename(base) {
	if (match(base, /\.[^\.]+$/)) return substr(base, RSTART + 1)
	return "sh"
}
function fileid_from_path(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	gsub(/\./, "_", t)
	return "Target_" t
}
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

# Export functions for subshells
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
