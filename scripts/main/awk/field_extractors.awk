# field_extractors.awk - Field extraction functions for delimiter-separated strings
#
# These functions extract specific fields from strings using a delimiter.
# Unlike AWK -F which has issues with multi-character delimiters,
# these use index() for reliable extraction.
#
# Include via: awk -f field_extractors.awk '... main script ...'
#
# Functions:
#   field1(s, delim) - Extract 1st field
#   field2(s, delim) - Extract 2nd field
#   field3(s, delim) - Extract 3rd field
#   field4(s, delim) - Extract 4th field
#   field5(s, delim) - Extract 5th field
#   field6(s, delim) - Extract 6th field

# @IMP6.1@ (FROM: @ARC2.1@)
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
