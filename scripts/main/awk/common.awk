# common.awk - Shared AWK helper functions for shtracer
#
# This file provides reusable AWK utility functions used across shtracer.
# Include via: awk -f common.awk '... main script ...'
#
# Functions:
#   trim(s)                 - Remove leading/trailing whitespace
#   get_last_segment(s)     - Extract last segment after ":"
#   escape_html(s)          - Escape HTML special characters
#   json_escape(s)          - Escape JSON special characters
#   basename(path)          - Extract filename from path
#   ext_from_basename(base) - Extract file extension
#   fileid_from_path(path)  - Generate HTML element ID from path
#   type_from_trace_target(tt) - Extract layer type from trace_target string

# @IMP5.1@ (FROM: @ARC1.2@)
function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}

# @IMP5.2@ (FROM: @ARC2.1@)
function get_last_segment(s,   n, parts) {
	n = split(s, parts, ":")
	return n > 0 ? parts[n] : s
}

# @IMP5.3@ (FROM: @ARC3.1@)
function escape_html(s,   t) {
	t = s
	gsub(/&/, "\\&amp;", t)
	gsub(/</, "\\&lt;", t)
	gsub(/>/, "\\&gt;", t)
	gsub(/"/, "\\&quot;", t)
	return t
}

# @IMP5.4@ (FROM: @ARC2.6@)
function json_escape(s,   result) {
	result = s
	gsub(/\\/, "\\\\", result)
	gsub(/"/, "\\\"", result)
	gsub(/\n/, "\\n", result)
	gsub(/\r/, "\\r", result)
	gsub(/\t/, "\\t", result)
	return result
}

# @IMP5.5@ (FROM: @ARC1.2@)
function basename(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	return t
}

# @IMP5.6@ (FROM: @ARC1.2@)
function ext_from_basename(base) {
	if (match(base, /\.[^\.]+$/)) return substr(base, RSTART + 1)
	return "sh"
}

# @IMP5.7@ (FROM: @ARC2.6@, @ARC3.1@)
function fileid_from_path(path,   t) {
	t = path
	gsub(/.*\//, "", t)
	gsub(/\./, "_", t)
	return "Target_" t
}

# @IMP5.8@ (FROM: @ARC2.1@)
function type_from_trace_target(tt,   n, p, t) {
	if (tt == "") return "Unknown"
	n = split(tt, p, ":")
	t = p[n]
	sub(/^[[:space:]]+/, "", t)
	sub(/[[:space:]]+$/, "", t)
	return t == "" ? "Unknown" : t
}
