#!/bin/sh

SHTRACER_TRUE="${SHTRACER_TRUE:=1}"
SHTRACER_FALSE="${SHTRACER_FALSE:=0}"

##
# @brief Flag to enable or disable the output of time taken by each function
# @details
#
# When SHTRACER_IS_PROFILE_ENABLE is set to SHTRACER_TRUE, the time taken by each function during execution is output to stderr.
SHTRACER_IS_PROFILE_ENABLE="${SHTRACER_IS_PROFILE_ENABLE:=$SHTRACER_FALSE}"

_shtracer_tmp_base_dir() {
	if [ -n "${TMPDIR:-}" ]; then
		printf '%s' "${TMPDIR%/}"
		return 0
	fi
	printf '%s' "/tmp"
}

shtracer_tmpfile() {
	_tmp_dir="$(_shtracer_tmp_base_dir)"
	_i=0
	while [ "$_i" -lt 1000 ]; do
		_path="${_tmp_dir%/}/shtracer.${$}.${_i}"
		(
			umask 0077
			set -C
			: >"$_path"
		) 2>/dev/null && {
			printf '%s\n' "$_path"
			return 0
		}
		_i=$((_i + 1))
	done
	return 1
}

shtracer_tmpdir() {
	_tmp_dir="$(_shtracer_tmp_base_dir)"
	_i=0
	while [ "$_i" -lt 1000 ]; do
		_path="${_tmp_dir%/}/shtracer.${$}.${_i}.d"
		(
			umask 0077
			mkdir "$_path"
		) 2>/dev/null && {
			printf '%s\n' "$_path"
			return 0
		}
		_i=$((_i + 1))
	done
	return 1
}

##
# @brief  Initialize environment
# @tag    @IMP4.1@ (FROM: @ARC5.1@)
init_environment() {
	set -u
	umask 0022
	export LC_ALL=C

	PATH="$(command -p getconf PATH 2>/dev/null)${PATH+:}${PATH-}"
	export PATH
	case $PATH in :*) PATH=${PATH#?} ;; esac
	IFS='
'
}

##
# @brief  Echo error message and exit
# @param  $1 : Error code
# @param  $2 : Function name
# @param  $3 : Error message
# @tag    @IMP4.2@ (FROM: @ARC5.1@)
error_exit() {
	if [ $# -ge 3 ]; then
		echo "[${0##*/}][error][$2]: $3" 1>&2
	fi
	exit "$1"
}

##
# @brief  Echo warning message and exit
# @param  $1 : Exit code
# @param  $2 : Function name
# @param  $3 : Warning message
warn_exit() {
	if [ $# -ge 3 ]; then
		echo "[${0##*/}][warn][$2]: $3" 1>&2
	fi
	exit "$1"
}

##
# @brief For profiling
# @param $1 : PROCESS_NAME
profile_start() {
	if [ "$SHTRACER_IS_PROFILE_ENABLE" -ne "$SHTRACER_TRUE" ]; then
		return
	fi
	PROCESS_NAME="$1"
	if [ -z "$PROCESS_NAME" ]; then
		echo "Error: process name is required." >&2
		return 1
	fi

	eval "PROFILE_START_TIME_$PROCESS_NAME=\$(date +%s.%N)"
}

##
# @brief For profiling
# @param $1 : PROCESS_NAME
profile_end() {
	if [ "$SHTRACER_IS_PROFILE_ENABLE" -ne "$SHTRACER_TRUE" ]; then
		return
	fi
	PROCESS_NAME="$1"
	if [ -z "$PROCESS_NAME" ]; then
		echo "Error: process name is required." >&2
		return 1
	fi

	eval "START_TIME=\$PROFILE_START_TIME_$PROCESS_NAME"
	if [ -z "$START_TIME" ]; then
		echo "Error: process '$PROCESS_NAME' was not started." >&2
		return 1
	fi

	END_TIME=$(date +%s.%N)
	ELAPSED=$(awk -v end="$END_TIME" -v start="$START_TIME" 'BEGIN{printf "%.2f\n", end-start}')

	echo "[${0##*/}][profile][$PROCESS_NAME]: ${ELAPSED} sec" >&2
	eval "unset PROFILE_START_TIME_$PROCESS_NAME"
}

##
# ============================================================================
# Refactoring Helper Functions (Phase 1: Field Extraction)
# ============================================================================
#
# These functions extract common awk/sed patterns into reusable utilities
# to improve code maintainability and reduce complexity.
##

##
# @brief Extract a specific field from separator-delimited string
# @param $1 : Input string
# @param $2 : Field number (1-indexed)
# @param $3 : Field separator
# @return Extracted field via stdout
# @example extract_field "a:b:c" 2 ":" returns "b"
extract_field() {
	_input="$1"
	_field_num="$2"
	_separator="$3"

	printf '%s\n' "$_input" | awk -F "$_separator" -v n="$_field_num" '{print $n}'
}

##
# @brief Extract field and remove surrounding double quotes
# @param $1 : Input string
# @param $2 : Field number (1-indexed)
# @param $3 : Field separator
# @return Unquoted field via stdout
# @example extract_field_unquoted '"val1"::"val2"' 1 "::" returns "val1"
extract_field_unquoted() {
	_field="$(extract_field "$1" "$2" "$3")"
	# Remove quotes: "value" -> value
	printf '%s\n' "$_field" | sed 's/^"\(.*\)"$/\1/'
}

##
# @brief Count number of fields in a file or string
# @param $1 : Input file path
# @param $2 : Field separator
# @return Maximum field count via stdout
# @example count_fields "data.txt" " " returns max fields across all lines
count_fields() {
	_input="$1"
	_separator="$2"

	awk -F "$_separator" 'BEGIN{max=0}{if(NF>max)max=NF}END{print max}' "$_input"
}

##
# ============================================================================
# Refactoring Helper Functions (Phase 2: Whitespace and Quote Processing)
# ============================================================================
##

##
# @brief Remove leading and trailing whitespace from string
# @param $1 : Input string
# @return Trimmed string via stdout
# @example trim_whitespace "  text  " returns "text"
trim_whitespace() {
	printf '%s\n' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

##
# @brief Remove blank lines from input stream
# @return Non-empty lines via stdout (reads stdin)
# @example cat file.txt | remove_empty_lines
remove_empty_lines() {
	sed '/^[[:space:]]*$/d'
}

##
# @brief Remove markdown list bullets from start of lines
# @return Cleaned lines via stdout (reads stdin)
# @example echo "* item" | remove_leading_bullets returns "item"
remove_leading_bullets() {
	sed 's/^[[:space:]]*\* //'
}

##
# @brief Extract content between delimiters (generic)
# @param $1 : Input string
# @param $2 : Delimiter character (e.g., ", `)
# @return Extracted content via stdout
# @example extract_from_delimiters '"content"' '"' returns "content"
extract_from_delimiters() {
	_str="$1"
	_delim="$2"

	# Trim whitespace first
	_str="$(printf '%s' "$_str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

	# Check if delimiters are present
	case "$_str" in
		"$_delim"*"$_delim")
			# Extract content between delimiters using shell parameter expansion
			_str="${_str#*"$_delim"}" # Remove prefix including first delimiter
			_str="${_str%"$_delim"*}" # Remove suffix including last delimiter
			printf '%s' "$_str"
			;;
		*)
			# No delimiters, return trimmed string as-is
			printf '%s' "$_str"
			;;
	esac
}

##
# @brief Extract content from double-quoted string
# @param $1 : Input string (may contain "quoted content")
# @return Content without quotes via stdout
# @example extract_from_doublequotes '  "value"  ' returns "value"
extract_from_doublequotes() {
	extract_from_delimiters "$1" '"'
}

##
# @brief Extract content from backtick-quoted string
# @param $1 : Input string (may contain `quoted content`)
# @return Content without quotes via stdout
# @example extract_from_backticks '  `value`  ' returns "value"
extract_from_backticks() {
	extract_from_delimiters "$1" '`'
}

##
# ============================================================================
# Refactoring Helper Functions (Phase 3: Escaping and Encoding)
# ============================================================================
##

##
# @brief Escape special characters for sed pattern matching
# @param $1 : Pattern string
# @return Escaped pattern via stdout
# @example escape_sed_pattern "a.b*c" escapes regex metacharacters
# @details Escapes BRE/ERE metacharacters: []\.^$*+?(){}|
escape_sed_pattern() {
	printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|]/\\&/g'
}

##
# @brief Escape special characters for sed replacement string
# @param $1 : Replacement string
# @return Escaped replacement via stdout
# @example escape_sed_replacement "a&b\\c" escapes &, \, and |
# @details Escapes: backslash, ampersand, and pipe (our delimiter)
escape_sed_replacement() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/&/\\&/g; s/|/\\|/g'
}

##
# @brief Escape HTML special characters
# @param $1 : Input string
# @return HTML-escaped string via stdout
# @example html_escape "<script>" returns "&lt;script&gt;"
# @details Escapes: & < > " '
html_escape() {
	printf '%s' "$1" | sed -e 's/&/\&amp;/g' \
		-e 's/</\&lt;/g' \
		-e 's/>/\&gt;/g' \
		-e 's/"/\&quot;/g' \
		-e "s/'/\&#39;/g"
}

##
# @brief Escape JavaScript special characters
# @param $1 : Input string
# @return JS-escaped string via stdout
# @example js_escape 'text"newline' escapes quotes and special chars
# @details Escapes: backslash, double-quote, newline, tab, CR
js_escape() {
	printf '%s' "$1" | awk '
	{
		gsub(/\\/, "\\\\")
		gsub(/"/, "\\\"")
		gsub(/\t/, "\\t")
		gsub(/\r/, "\\r")
		gsub(/\n/, "\\n")
		print
	}'
}

##
# ============================================================================
# Refactoring Helper Functions (Phase 4: Complex Processing)
# ============================================================================
##

##
# @brief Remove HTML comments from markdown file
# @param $1 : Input file path
# @return Cleaned content via stdout
# @details Handles three cases:
#   1. Inline comments: text <!-- comment --> more
#   2. Multi-line comments
#   3. Exception: Preserves comments in backticks: `code <!-- keep -->`
# @note This function extracts the core comment removal logic from
#       _check_config_remove_comments() for better testability
remove_markdown_comments() {
	_file="$1"

	awk <"$_file" '
		/`.*<!--.*-->.*`/   {
			match($0, /`.*<!--.*-->.*`/);               # Exception: comment in backticks
			print(substr($0, 1, RSTART + RLENGTH - 1)); # Keep everything up to backtick end
			next;
		}
		{
			sub(/<!--.*-->/, "")  # Remove inline comments
		}
		/<!--/ { in_comment=1 }
		/-->/ && in_comment { in_comment=0; next }
		/<!--/,/-->/ { if (in_comment) next }
		!in_comment { print }
	'
}

##
# @brief Remove trailing whitespace from lines
# @return Lines with trailing whitespace removed (reads stdin)
# @example cat file.txt | remove_trailing_whitespace
remove_trailing_whitespace() {
	sed 's/[[:space:]]*$//'
}

##
# @brief Convert markdown bold headers to plain text
# @return Converted lines (reads stdin)
# @example echo "**Header:**" | convert_markdown_bold returns "Header:"
convert_markdown_bold() {
	sed 's/\*\*//g'
}

##
# ============================================================================
# Refactoring Helper Functions (Phase 5: JSON and HTML Processing)
# ============================================================================
##

##
# @brief Extract a string field value from JSON file
# @param $1 : JSON file path
# @param $2 : Field name to extract
# @return Extracted field value via stdout (empty if not found)
# @example extract_json_string_field "data.json" "config_path"
# @details Extracts value from pattern: "field_name": "value"
#   Uses grep + sed for simple JSON parsing (not a full JSON parser)
extract_json_string_field() {
	_json_file="$1"
	_field_name="$2"

	if [ ! -r "$_json_file" ]; then
		return 1
	fi

	# Pattern: "field_name"[whitespace]*:[whitespace]*"value"
	# Extract the value between quotes after the field name
	grep -m 1 "\"$_field_name\"" "$_json_file" 2>/dev/null \
		| sed "s/.*\"$_field_name\"[[:space:]]*:[[:space:]]*\"//; s/\".*//"
}

##
# @brief Remove lines matching a specific pattern
# @param $1 : Pattern to match (plain string, not regex)
# @return Filtered lines via stdout (reads stdin)
# @example cat file.html | remove_lines_with_pattern "<!-- MARKER -->"
remove_lines_with_pattern() {
	_pattern="$1"
	_escaped="$(escape_sed_pattern "$_pattern")"
	sed "/^.*$_escaped.*$/d"
}

##
# ============================================================================
# File Version Information Helpers (Phase 1: Git Integration)
# ============================================================================
##

##
# @brief Get version information for a file (git hash or last modified time)
# @param $1 : Absolute file path
# @return Echoes version string to stdout (format: "git:HASH" or "mtime:ISO8601")
# @details
#   - If file is in git repo and tracked: returns "git:<commit-hash>" (7 chars)
#   - Otherwise: returns "mtime:<ISO8601-timestamp>"
#   - Handles errors gracefully (git not installed, file doesn't exist, etc.)
# @example get_file_version_info "/path/to/file.md" returns "git:abc1234" or "mtime:2025-12-26T10:30:00Z"
get_file_version_info() {
	_file_path="$1"

	# Validate file exists
	if [ ! -f "$_file_path" ]; then
		printf '%s' "unknown"
		return 1
	fi

	# Try git first (if available)
	if command -v git >/dev/null 2>&1; then
		# Check if file is in a git repo and tracked
		_git_hash="$(cd "$(dirname "$_file_path")" 2>/dev/null \
			&& git log -1 --format='%H' -- "$(basename "$_file_path")" 2>/dev/null)"

		if [ -n "$_git_hash" ]; then
			# Get short hash (first 7 chars) - more readable
			_short_hash="$(printf '%s' "$_git_hash" | cut -c1-7)"
			printf 'git:%s' "$_short_hash"
			return 0
		fi
	fi

	# Fallback: use last modified time in ISO 8601 format
	# POSIX-compliant approach using stat or ls
	if command -v stat >/dev/null 2>&1; then
		# Try GNU stat (Linux)
		_mtime="$(stat -c '%Y' "$_file_path" 2>/dev/null)"
		if [ -z "$_mtime" ]; then
			# Try BSD stat (macOS)
			_mtime="$(stat -f '%m' "$_file_path" 2>/dev/null)"
		fi

		if [ -n "$_mtime" ]; then
			# Convert Unix timestamp to ISO 8601 using date
			# Try GNU date format first, then BSD format
			_iso_time="$(date -u -d "@$_mtime" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
				|| date -u -r "$_mtime" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
			if [ -n "$_iso_time" ]; then
				printf 'mtime:%s' "$_iso_time"
				return 0
			fi
		fi
	fi

	# Last resort: return unknown
	printf '%s' "unknown"
	return 0
}

##
# @brief Format version info for compact display (text summary)
# @param $1 : Version string (from get_file_version_info)
# @return Formatted string for display
# @example format_version_info_short "git:abc1234" returns "abc1234"
# @example format_version_info_short "mtime:2025-12-26T10:30:45Z" returns "2025-12-26 10:30"
format_version_info_short() {
	_version="$1"

	case "$_version" in
		git:*)
			# Strip "git:" prefix
			printf '%s' "${_version#git:}"
			;;
		mtime:*)
			# Strip "mtime:" and format timestamp shorter
			_timestamp="${_version#mtime:}"
			# Extract date and time (remove 'Z' and seconds)
			# 2025-12-26T10:30:45Z -> 2025-12-26 10:30
			printf '%s' "$_timestamp" | sed 's/T/ /; s/:[0-9][0-9]Z$//'
			;;
		*)
			printf '%s' "$_version"
			;;
	esac
}

##
# ============================================================================
# Cross-Reference Table Helpers
# ============================================================================
##

##
# @brief   Compute relative path from one directory to a target file
# @param   $1 : From directory (absolute path)
# @param   $2 : To file (absolute path)
# @return  Relative path via stdout (e.g., "../../docs/file.md")
# @example _compute_relative_path "/a/b/c/output" "/a/b/docs/file.md" returns "../../docs/file.md"
# @tag     @IMP2.7.6@ (FROM: @ARC2.7@)
_compute_relative_path() {
	_from_dir="$1"
	_to_file="$2"

	# Normalize paths: remove trailing slashes
	_from_dir="${_from_dir%/}"
	_to_file="${_to_file%/}"

	# Handle edge cases
	if [ -z "$_from_dir" ] || [ -z "$_to_file" ]; then
		printf '%s' "$_to_file"
		return 1
	fi

	# Find common prefix using IFS and set
	_from_clean="$_from_dir/"
	_to_clean="$_to_file"

	# Split paths into components and find common prefix
	_common=""
	_remaining_from="$_from_clean"
	_remaining_to="$_to_clean"

	# Build common prefix character by character
	_i=1
	_max_len=${#_from_clean}
	[ ${#_to_clean} -lt "$_max_len" ] && _max_len=${#_to_clean}

	while [ "$_i" -le "$_max_len" ]; do
		_from_char="$(printf '%s' "$_from_clean" | cut -c "$_i")"
		_to_char="$(printf '%s' "$_to_clean" | cut -c "$_i")"

		if [ "$_from_char" = "$_to_char" ]; then
			_common="${_common}${_from_char}"
		else
			break
		fi
		_i=$((_i + 1))
	done

	# Trim common prefix to last directory separator
	case "$_common" in
		*/*)
			# Find last '/' in common prefix
			_common="${_common%/*}/"
			;;
		*)
			_common=""
			;;
	esac

	# Remove common prefix from both paths
	_remaining_from="${_from_clean#"$_common"}"
	_remaining_to="${_to_clean#"$_common"}"

	# Count directory levels in remaining FROM path
	_up_levels=0
	_temp="$_remaining_from"
	while [ -n "$_temp" ]; do
		case "$_temp" in
			*/*)
				_up_levels=$((_up_levels + 1))
				_temp="${_temp#*/}"
				;;
			*)
				_temp=""
				;;
		esac
	done

	# Build relative path
	_relative=""
	_i=0
	while [ "$_i" -lt "$_up_levels" ]; do
		_relative="${_relative}../"
		_i=$((_i + 1))
	done
	_relative="${_relative}${_remaining_to}"

	printf '%s' "$_relative"
	return 0
}

##
# ============================================================================
# Source AWK Helper Library
# ============================================================================
##

# Source AWK helper functions (provides AWK_FN_* variables for reusable AWK code)
# shellcheck source=scripts/main/shtracer_awk_helpers.sh
_UTIL_SCRIPT_DIR="${_UTIL_SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
if [ -f "${_UTIL_SCRIPT_DIR}/shtracer_awk_helpers.sh" ]; then
	. "${_UTIL_SCRIPT_DIR}/shtracer_awk_helpers.sh"
fi

# Source JSON parser functions (provides json_parse_* functions for JSON processing)
# shellcheck source=scripts/main/shtracer_json_parser.sh
if [ -f "${_UTIL_SCRIPT_DIR}/shtracer_json_parser.sh" ]; then
	. "${_UTIL_SCRIPT_DIR}/shtracer_json_parser.sh"
fi
