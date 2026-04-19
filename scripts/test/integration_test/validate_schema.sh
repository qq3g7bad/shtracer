#!/bin/sh
# validate_schema.sh — structural validator for shtracer output JSON.
#
# Asserts the invariants declared in docs/output.schema.json that matter for
# drift detection: top-level key set, per-object required keys, and a handful
# of value patterns (version "git:"/"mtime:" stamps).
#
# Not a full JSON Schema validator — intentionally small and dependency-free
# (POSIX sh + awk only). The authoritative contract is docs/output.schema.json;
# this script exists so CI catches breakage without pulling in jsonschema/jq.
#
# Usage:
#   shtracer config.md | validate_schema.sh
#   validate_schema.sh path/to/output.json

set -u

_input_file=""
if [ $# -ge 1 ] && [ "$1" != "-" ]; then
	_input_file="$1"
fi

if [ -n "$_input_file" ] && [ ! -r "$_input_file" ]; then
	echo "validate_schema.sh: cannot read $_input_file" >&2
	exit 2
fi

awk '
# -----------------------------------------------------------------------------
# Tokenizer — produces parallel arrays tok[] / val[] indexed 1..nt.
# Token codes: { } [ ] , :   S=string  N=number  B=bool  Z=null
# String content is kept raw (with backslash escapes) in val[i]; we never need
# to decode because the schema only checks keys (ASCII) and a "git:"/"mtime:"
# prefix, both unambiguous even with escapes.
# -----------------------------------------------------------------------------
function tokenize(src,   n, i, c, buf, look) {
	n = length(src)
	nt = 0
	i = 1
	while (i <= n) {
		c = substr(src, i, 1)
		if (c == " " || c == "\t" || c == "\n" || c == "\r") { i++; continue }
		if (c == "{" || c == "}" || c == "[" || c == "]" || c == "," || c == ":") {
			nt++; tok[nt] = c; val[nt] = ""; i++; continue
		}
		if (c == "\"") {
			buf = ""
			i++
			while (i <= n) {
				c = substr(src, i, 1)
				if (c == "\\") {
					buf = buf c substr(src, i + 1, 1)
					i += 2
					continue
				}
				if (c == "\"") { i++; break }
				buf = buf c
				i++
			}
			nt++; tok[nt] = "S"; val[nt] = buf; continue
		}
		if (c == "-" || (c >= "0" && c <= "9")) {
			buf = ""
			while (i <= n) {
				c = substr(src, i, 1)
				if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" \
					|| (c >= "0" && c <= "9")) {
					buf = buf c; i++
				} else { break }
			}
			nt++; tok[nt] = "N"; val[nt] = buf; continue
		}
		look = substr(src, i, 4)
		if (look == "true") { nt++; tok[nt]="B"; val[nt]="true";  i+=4; continue }
		if (look == "null") { nt++; tok[nt]="Z"; val[nt]="null";  i+=4; continue }
		look = substr(src, i, 5)
		if (look == "false") { nt++; tok[nt]="B"; val[nt]="false"; i+=5; continue }
		err("tokenize: unexpected char [" substr(src, i, 1) "] at byte " i)
		return
	}
}

# -----------------------------------------------------------------------------
# Schema table — maps path pattern to space-separated required keys.
# "[*]" stands for any array index. Paths use "." and "[*]" as separators.
# -----------------------------------------------------------------------------
function build_schema() {
	required["$"] = "metadata verificationErrors files layers trace_tags chains health"
	required["$.metadata"] = "version generated config_path"
	required["$.verificationErrors"] = "isolated duplicates dangling"
	required["$.verificationErrors.isolated[*]"]   = "id file_id line"
	required["$.verificationErrors.duplicates[*]"] = "id file_id line"
	required["$.verificationErrors.dangling[*]"]   = "child_tag missing_parent file_id line"
	required["$.files[*]"]  = "file_id file version"
	required["$.layers[*]"] = "layer_id name pattern file_ids total_tags upstream_layers downstream_layers"
	required["$.trace_tags[*]"] = "id from_tags description file_id line layer_id"
	required["$.health"] = "total_tags tags_with_links isolated_tags isolated_tag_list duplicate_tags duplicate_tag_list dangling_references dangling_reference_list coverage"
	required["$.health.isolated_tag_list[*]"]  = "id file_id line"
	required["$.health.duplicate_tag_list[*]"] = "id file_id line"
	required["$.health.dangling_reference_list[*]"] = "child_tag missing_parent file_id line"
	required["$.health.coverage"] = "layers"
	required["$.health.coverage.layers[*]"] = "layer_id name total upstream downstream files"
	required["$.health.coverage.layers[*].upstream"]   = "count percent"
	required["$.health.coverage.layers[*].downstream"] = "count percent"
	required["$.health.coverage.layers[*].files[*]"]   = "file_id total upstream downstream version"
	required["$.health.coverage.layers[*].files[*].upstream"]   = "count percent"
	required["$.health.coverage.layers[*].files[*].downstream"] = "count percent"
}

# Normalize a live path ($.files.3.file_id) into a schema key
# ($.files[*].file_id) by replacing numeric components with [*].
function normalize(p,   parts, n, i, out) {
	n = split(p, parts, ".")
	out = parts[1]
	for (i = 2; i <= n; i++) {
		if (parts[i] ~ /^[0-9]+$/) {
			out = out "[*]"
		} else {
			out = out "." parts[i]
		}
	}
	return out
}

function check_required(live_path, seen_keys_str,   schema_key, req_list, n, a, i, seen) {
	schema_key = normalize(live_path)
	if (!(schema_key in required)) return
	req_list = required[schema_key]
	split(" " seen_keys_str " ", seen, " ")
	n = split(req_list, a, " ")
	for (i = 1; i <= n; i++) {
		if (index(" " seen_keys_str " ", " " a[i] " ") == 0) {
			err("missing required key \"" a[i] "\" at " live_path)
		}
	}
}

# -----------------------------------------------------------------------------
# Walker — consumes tokens linearly, maintains path + per-scope seen-keys map.
# Stack entries:
#   stype[d]  = "O" (object) or "A" (array)
#   slabel[d] = path segment introduced at this depth
#   skeys[d]  = space-separated list of keys seen so far in this object
#   sidx[d]   = current array index (for arrays)
# -----------------------------------------------------------------------------
function walk(   i, t, v, d, cur_key, live) {
	d = 0
	stype[0] = ""; slabel[0] = "$"; skeys[0] = ""; sidx[0] = -1
	cur_key = ""

	for (i = 1; i <= nt; i++) {
		t = tok[i]; v = val[i]

		if (t == "{") {
			d++
			stype[d] = "O"
			skeys[d] = ""
			if (d == 1) {
				slabel[d] = "$"
			} else if (stype[d-1] == "A") {
				sidx[d-1]++
				slabel[d] = sidx[d-1]
			} else {
				slabel[d] = cur_key
			}
			sidx[d] = -1
			continue
		}
		if (t == "[") {
			d++
			stype[d] = "A"
			skeys[d] = ""
			if (d == 1) {
				slabel[d] = "$"
			} else if (stype[d-1] == "A") {
				sidx[d-1]++
				slabel[d] = sidx[d-1]
			} else {
				slabel[d] = cur_key
			}
			sidx[d] = -1
			continue
		}
		if (t == "}" || t == "]") {
			if (t == "}") check_required(path_str(d), skeys[d])
			d--
			continue
		}
		if (t == ":" || t == ",") continue

		# Value token (S/N/B/Z) or key-string before a colon.
		if (stype[d] == "O" && t == "S" && i + 1 <= nt && tok[i+1] == ":") {
			cur_key = v
			# Record key seen
			if (skeys[d] == "") skeys[d] = cur_key
			else skeys[d] = skeys[d] " " cur_key
			# Check known value patterns
			# version must match git:<hex>|mtime:<...>
			# (applies to files[*].version and coverage.layers[*].files[*].version)
			# We just mark the path; actual value is the next token after ":".
			continue
		}
		# Primitive array element or value after "key:"
		# Validate version strings only on files[*].version (not metadata.version).
		if (t == "S" && cur_key == "version" && stype[d] == "O") {
			_pp = normalize(path_str(d))
			if (_pp == "$.files[*]" || _pp == "$.health.coverage.layers[*].files[*]") {
				if (v !~ /^git:[0-9a-f]+$/ && v !~ /^mtime:/) {
					err("bad version value \"" v "\" at " path_str(d) ".version")
				}
			}
		}
		# Array elements: advance index tracker so path normalization works.
		if (stype[d] == "A") sidx[d]++
	}

	if (d != 0) err("unbalanced brackets, depth=" d " at end of input")
}

function path_str(d,   i, out) {
	if (d <= 0) return "$"
	out = slabel[1]
	for (i = 2; i <= d; i++) {
		out = out "." slabel[i]
	}
	return out
}

function err(msg) {
	print "validate_schema: " msg > "/dev/stderr"
	errcount++
}

BEGIN { src = "" }
{ src = src $0 "\n" }

END {
	errcount = 0
	build_schema()
	tokenize(src)
	if (errcount == 0) walk()
	if (errcount > 0) {
		print "validate_schema: " errcount " error(s)" > "/dev/stderr"
		exit 1
	}
	exit 0
}
' "${_input_file:-/dev/stdin}"
