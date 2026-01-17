#!/bin/sh

# This script can be executed (JSON -> single HTML to stdout) or sourced (unit tests).

##
# @brief  Get template HTML content with external override support
# @return Template HTML content via stdout
# @details
#   Resolution priority:
#   1. $SHTRACER_TEMPLATE_DIR/template.html (if set)
#   2. $HOME/.shtracer/template.html
#   3. scripts/main/templates/template.html (bundled)
#   Environment: SHTRACER_SCRIPT_DIR can be set to override script directory detection
# @tag    @IMP3.10@ (FROM: @ARC3.2@)
_viewer_get_template_html() {
	_custom_template=""
	# Try to determine script directory (handles both execution and sourcing)
	# Priority: SHTRACER_SCRIPT_DIR env var (required when sourced), $0 (when executed)
	if [ -n "${SHTRACER_SCRIPT_DIR:-}" ]; then
		_script_dir="$SHTRACER_SCRIPT_DIR"
	elif [ -f "$0" ]; then
		_script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
	else
		_script_dir=""
	fi

	# Priority 1: SHTRACER_TEMPLATE_DIR environment variable
	if [ -n "${SHTRACER_TEMPLATE_DIR:-}" ] \
		&& [ -f "${SHTRACER_TEMPLATE_DIR%/}/template.html" ]; then
		_custom_template="${SHTRACER_TEMPLATE_DIR%/}/template.html"
	# Priority 2: User home directory
	elif [ -n "${HOME:-}" ] && [ -f "${HOME}/.shtracer/template.html" ]; then
		_custom_template="${HOME}/.shtracer/template.html"
	# Priority 3: Bundled templates directory
	elif [ -n "$_script_dir" ] && [ -f "${_script_dir}/templates/template.html" ]; then
		_custom_template="${_script_dir}/templates/template.html"
	fi

	# Use external template if found, otherwise error
	if [ -n "$_custom_template" ]; then
		cat "$_custom_template"
	else
		echo "[shtracer_html_viewer.sh][error]: template.html not found" >&2
		return 1
	fi
}

##
# @brief  Get template CSS content with external override support
# @return Template CSS content via stdout
# @details
#   Resolution priority:
#   1. $SHTRACER_TEMPLATE_DIR/assets/template.css (if set)
#   2. $HOME/.shtracer/assets/template.css
#   3. scripts/main/templates/template.css (bundled)
#   4. Embedded heredoc (fallback)
# @tag    @IMP3.11@ (FROM: @ARC3.2@)
_viewer_get_template_css() {
	_custom_css=""
	# Try to determine script directory (handles both execution and sourcing)
	# Priority: SHTRACER_SCRIPT_DIR env var (required when sourced), $0 (when executed)
	if [ -n "${SHTRACER_SCRIPT_DIR:-}" ]; then
		_script_dir="$SHTRACER_SCRIPT_DIR"
	elif [ -f "$0" ]; then
		_script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
	else
		_script_dir=""
	fi

	# Priority 1: SHTRACER_TEMPLATE_DIR environment variable
	if [ -n "${SHTRACER_TEMPLATE_DIR:-}" ] \
		&& [ -f "${SHTRACER_TEMPLATE_DIR%/}/assets/template.css" ]; then
		_custom_css="${SHTRACER_TEMPLATE_DIR%/}/assets/template.css"
	# Priority 2: User home directory
	elif [ -n "${HOME:-}" ] && [ -f "${HOME}/.shtracer/assets/template.css" ]; then
		_custom_css="${HOME}/.shtracer/assets/template.css"
	# Priority 3: Bundled templates directory
	elif [ -n "$_script_dir" ] && [ -f "${_script_dir}/templates/template.css" ]; then
		_custom_css="${_script_dir}/templates/template.css"
	fi

	if [ -n "$_custom_css" ]; then
		cat "$_custom_css"
	else
		echo "[shtracer_html_viewer.sh][error]: template.css not found" >&2
		return 1
	fi
}

##
# @brief  Get JavaScript template content with external override support
# @param  $1 : JavaScript template filename (e.g., "show_text.js", "traceability_diagrams.js")
# @return Template JavaScript content via stdout
# @details
#   Resolution priority:
#   1. $SHTRACER_TEMPLATE_DIR/assets/<filename> (if set)
#   2. $HOME/.shtracer/assets/<filename>
#   3. scripts/main/templates/<filename> (bundled)
#   4. Embedded heredoc (fallback)
_viewer_get_template_js() {
	_js_filename="${1:-}"
	_custom_js=""
	# Try to determine script directory (handles both execution and sourcing)
	# Priority: SHTRACER_SCRIPT_DIR env var (required when sourced), $0 (when executed)
	if [ -n "${SHTRACER_SCRIPT_DIR:-}" ]; then
		_script_dir="$SHTRACER_SCRIPT_DIR"
	elif [ -f "$0" ]; then
		_script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
	else
		_script_dir=""
	fi

	if [ -z "$_js_filename" ]; then
		return 1
	fi

	# Priority 1: SHTRACER_TEMPLATE_DIR environment variable
	if [ -n "${SHTRACER_TEMPLATE_DIR:-}" ] \
		&& [ -f "${SHTRACER_TEMPLATE_DIR%/}/assets/${_js_filename}" ]; then
		_custom_js="${SHTRACER_TEMPLATE_DIR%/}/assets/${_js_filename}"
	# Priority 2: User home directory
	elif [ -n "${HOME:-}" ] && [ -f "${HOME}/.shtracer/assets/${_js_filename}" ]; then
		_custom_js="${HOME}/.shtracer/assets/${_js_filename}"
	# Priority 3: Bundled templates directory
	elif [ -n "$_script_dir" ] && [ -f "${_script_dir}/templates/${_js_filename}" ]; then
		_custom_js="${_script_dir}/templates/${_js_filename}"
	fi

	# Use external template if found, otherwise error
	if [ -n "$_custom_js" ]; then
		cat "$_custom_js"
	else
		echo "[shtracer_html_viewer.sh][error]: ${_js_filename} not found" >&2
		return 1
	fi
}

##
# @brief   Generate HTML table header with sortable columns dynamically from TAG_INFO_TABLE
# @param   $1 : TAG_INFO_TABLE (tag information with trace_target)
# @return  HTML <thead> element with sort buttons
_html_add_table_header() {
	_TAG_INFO_TABLE="$1"
	_sep="$SHTRACER_SEPARATOR"

	printf '%s\n' '<thead>'
	printf '%s\n' '  <tr>'

	# Extract unique trace_target types and generate header columns
	# Order follows appearance in TAG_INFO_TABLE (config.md trace target definition order)
	{
		if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
			cat "$_TAG_INFO_TABLE"
		else
			printf '%s\n' "$_TAG_INFO_TABLE"
		fi
	} | awk -F"$_sep" -v col_idx=0 '
		function get_last_segment(s,   n, parts) {
			n = split(s, parts, ":")
			return n > 0 ? parts[n] : s
		}
		{
			if (NF >= 4 && $4 != "") {
				trace_target = $4
				col_name = get_last_segment(trace_target)
				if (!(col_name in seen)) {
					seen[col_name] = 1
					cols[col_idx++] = col_name
				}
			}
		}
		END {
			for (i = 0; i < col_idx; i++) {
				printf "    <th>%s <a href=\"#\" onclick=\"sortTable(event, %d)\">sort</a></th>\n", cols[i], i
			}
		}
	'

	printf '%s\n' '  </tr>'
	printf '%s\n' '</thead>'
}

##
# @brief   Convert tag table rows to HTML table body
# @param   $1 : TAG_TABLE_FILENAME
# @return  HTML <tbody> element with table data
_html_convert_tag_table() {
	# Convert tag table rows into fixed layer columns based on tag->trace_target mapping.
	# $1: TAG_TABLE_FILENAME (space-separated tags per line)
	# $2: TAG_INFO_TABLE (tag<sep>line<sep>path<sep>trace_target)
	_TAG_TABLE_FILENAME="$1"
	_TAG_INFO_TABLE="$2"
	_sep="$SHTRACER_SEPARATOR"
	_nodata="$NODATA_STRING"

	printf '%s\n' '<tbody>'
	{
		if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
			cat "$_TAG_INFO_TABLE"
		else
			printf '%s\n' "$_TAG_INFO_TABLE"
		fi
		printf '%s\n' '__SHTRACER_TAG_INFO_END__'
		cat "$_TAG_TABLE_FILENAME"
	} | awk -v sep="$_sep" -v nodata="$_nodata" '
        BEGIN {
            ndims = 0
            mode = 0
        }
        function get_last_segment(s,   n, parts) {
            n = split(s, parts, ":")
            return n > 0 ? parts[n] : s
        }
        function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
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
            if (p3 <= 0) return rest
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
            if (p4 <= 0) return rest
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
            if (p5 <= 0) return rest
            rest = substr(rest, p5 + length(delim))
            p6 = index(rest, delim)
            if (p6 <= 0) return rest
            return substr(rest, 1, p6 - 1)
        }
        function type_from_trace_target(tt,   n, p, t) {
            if (tt == "") return "Unknown"
            n = split(tt, p, ":")
            t = trim(p[n])
            return t == "" ? "Unknown" : t
        }
        function escape_html(s,   t) {
            t = s
            gsub(/&/, "&amp;", t)
            gsub(/</, "&lt;", t)
            gsub(/>/, "&gt;", t)
            gsub(/"/, "&quot;", t)
            return t
        }
        function basename(path,   t) {
            t = path
            gsub(/.*\//, "", t)
            return t
        }
        function ext_from_basename(base) {
            if (match(base, /[.][^.]+$/)) return substr(base, RSTART + 1)
            return "sh"
        }
		function fileid_from_path(path,   t) {
			t = path
			gsub(/.*\//, "", t)  # Extract basename only
			gsub(/\./, "_", t)   # Replace dots with underscores
			return "Target_" t
		}
        function badge(tag, typ, line, fileId, ext,   safeTyp, safeTag, safeId, safeExt, safeDesc, safeFromTags, desc, from_tags) {
            safeTyp = escape_html(typ)
            safeTag = escape_html(tag)
            safeId = escape_html(fileId)
            safeExt = escape_html(ext)
            desc = tagDescription[tag]
            from_tags = tagFromTags[tag]
            safeDesc = escape_html(desc)
            gsub(/"/, "\\&quot;", safeDesc)
            safeFromTags = escape_html(from_tags)
            gsub(/"/, "\\&quot;", safeFromTags)
            return "<span class=\"matrix-tag-badge\" data-type=\"" safeTyp "\">" \
                "<a href=\"#\" onclick=\"showText(event, &quot;" safeId "&quot;, " line ", &quot;" safeExt "&quot;, &quot;" safeTag "&quot;, &quot;" safeDesc "&quot;, &quot;" safeTyp "&quot;, &quot;" safeFromTags "&quot;)\" " \
                "onmouseover=\"showTooltip(event, &quot;" safeId "&quot;)\" onmouseout=\"hideTooltip()\">" safeTag "</a></span>"
        }
        $0 == "__SHTRACER_TAG_INFO_END__" {
            mode = 1
            next
        }
        mode == 0 {
            if ($0 == "") next
            tag = trim(field1($0, sep))
            if (tag == "") next
            line = trim(field2($0, sep))
            path = trim(field3($0, sep))
            trace_target = trim(field4($0, sep))
            description = trim(field5($0, sep))
            from_tags_raw = trim(field6($0, sep))
            if (line == "" || line + 0 < 1) line = 1
            typ = type_from_trace_target(trace_target)
            tagType[tag] = typ
            tagLine[tag] = line
            tagDescription[tag] = description
            tagFromTags[tag] = from_tags_raw
			base = basename(path)
			tagExt[tag] = ext_from_basename(base)
			tagFileId[tag] = fileid_from_path(path)
            # Build dims array dynamically
            if (typ != "" && typ != "Unknown" && !(typ in dimIndex)) {
                dims[++ndims] = typ
                dimIndex[typ] = ndims
            }
            next
        }
        {
            for (i = 1; i <= ndims; i++) { cell[i] = nodata; html[i] = "" }
            nextSlot = 1
            nt = split($0, tags, /[[:space:]]+/)
            for (k = 1; k <= nt; k++) {
                t = trim(tags[k])
                if (t == "" || t == nodata) continue
                typ = tagType[t]
                if (typ == "") typ = "Unknown"
                if (typ in dimIndex) {
                    col = dimIndex[typ]
                } else {
                    while (nextSlot <= ndims && cell[nextSlot] != nodata) nextSlot++
                    col = (nextSlot <= ndims) ? nextSlot : ndims
                }
                frag = badge(t, typ, tagLine[t], tagFileId[t], tagExt[t])
                if (cell[col] == nodata) { cell[col] = t; html[col] = frag }
                else { cell[col] = cell[col] " " t; html[col] = html[col] "<br>" frag }
            }
            printf "\n  <tr>\n"
            for (i = 1; i <= ndims; i++) {
                if (cell[i] == nodata) printf "    <td><span class=\"matrix-tag-badge matrix-tag-badge-nodata\">%s</span></td>\n", nodata
                else printf "    <td>%s</td>\n", html[i]
            }
            printf "  </tr>"
        }
    '
	printf '%s\n' '</tbody>'
}

##
# @brief   Generate HTML cross-reference table from intermediate matrix file
# @param   $1 : Cross-reference matrix file path (e.g., 06_cross_ref_matrix_REQ_ARC)
# @param   $2 : HTML table ID (e.g., "tag-table-req-arc")
# @param   $3 : TAG_INFO_TABLE file path (for tag type mapping)
# @return  Complete HTML table with clickable badges
_html_generate_cross_ref_table() {
	_xref_file="$1"
	_table_id="$2"
	_tag_info_table="$3"
	_sep="$SHTRACER_SEPARATOR"
	_nodata="$NODATA_STRING"

	# Error handling: file not readable
	if [ ! -r "$_xref_file" ]; then
		printf '<table id="%s" class="matrix-table"><tbody><tr><td>Error: Cross-reference file not found</td></tr></tbody></table>\n' "$_table_id"
		return 1
	fi

	# Parse TAG_INFO_TABLE and intermediate file, then generate HTML table
	{
		# TAG_INFO_TABLE is a string containing the data, not a file path
		printf '%s\n' "$_tag_info_table"
		printf '%s\n' "__SHTRACER_TAG_INFO_END__"
		cat "$_xref_file"
	} | awk -v sep="$_sep" -v nodata="$_nodata" -v table_id="$_table_id" '
		BEGIN {
			mode = "tag_info"
			row_count = 0
			col_count = 0
			row_prefix = ""
			col_prefix = ""
		}
		function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
		function get_last_segment(s,   n, parts) {
			n = split(s, parts, ":")
			return n > 0 ? parts[n] : s
		}
		function type_from_trace_target(tt,   n, p, t) {
			if (tt == "") return "Unknown"
			n = split(tt, p, ":")
			t = trim(p[n])
			return t == "" ? "Unknown" : t
		}
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
		function escape_html(s,   t) {
			t = s
			gsub(/&/, "&amp;", t)
			gsub(/</, "&lt;", t)
			gsub(/>/, "&gt;", t)
			gsub(/"/, "&quot;", t)
			return t
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
			gsub(/.*\//, "", t)  # Extract basename only
			gsub(/\./, "_", t)   # Replace dots with underscores
			return "Target_" t
		}
		function badge(tag, typ, line, fileId, ext,   safeTyp, safeTag, safeId, safeExt, safeDesc, safeFromTags, desc, from_tags) {
			safeTyp = escape_html(typ)
			safeTag = escape_html(tag)
			safeId = escape_html(fileId)
			safeExt = escape_html(ext)
			desc = tagDescription[tag]
			from_tags = tagFromTags[tag]
			safeDesc = escape_html(desc)
			gsub(/"/, "\\&quot;", safeDesc)
			safeFromTags = escape_html(from_tags)
			gsub(/"/, "\\&quot;", safeFromTags)
			return "<span class=\"matrix-tag-badge\" data-type=\"" safeTyp "\">" \
				"<a href=\"#\" onclick=\"showText(event, &quot;" safeId "&quot;, " line ", &quot;" safeExt "&quot;, &quot;" safeTag "&quot;, &quot;" safeDesc "&quot;, &quot;" safeTyp "&quot;, &quot;" safeFromTags "&quot;)\" " \
				"onmouseover=\"showTooltip(event, &quot;" safeId "&quot;)\" onmouseout=\"hideTooltip()\">" safeTag "</a></span>"
		}

		# Read TAG_INFO_TABLE to build tag type mapping
		$0 == "__SHTRACER_TAG_INFO_END__" {
			mode = "xref_file"
			next
		}
		mode == "tag_info" {
			if ($0 == "") next
			tag = trim(field1($0, sep))
			if (tag == "") next
			trace_target = trim(field4($0, sep))
			description = trim(field5($0, sep))
			from_tags_raw = trim(field6($0, sep))
			typ = type_from_trace_target(trace_target)
			tagType[tag] = typ
			tagDescription[tag] = description
			tagFromTags[tag] = from_tags_raw
			next
		}

		# Section markers in cross-reference file
		/^\[METADATA\]/ { mode = "metadata"; next }
		/^\[ROW_TAGS\]/ { mode = "row_tags"; next }
		/^\[COL_TAGS\]/ { mode = "col_tags"; next }
		/^\[MATRIX\]/ { mode = "matrix"; next }

		# Parse metadata: row_prefix<sep>col_prefix<sep>timestamp
		mode == "metadata" {
			if ($0 == "") next
			row_prefix = trim(field1($0, sep))
			col_prefix = trim(field2($0, sep))
			next
		}

		# Parse row tags: @TAG@<sep>/path/to/file<sep>line_num
		mode == "row_tags" {
			if ($0 == "") next
			tag = trim(field1($0, sep))
			file = trim(field2($0, sep))
			line = trim(field3($0, sep))
			if (tag == "") next
			if (line == "" || line + 0 < 1) line = 1
			typ = (tag in tagType) ? tagType[tag] : "Unknown"
			row_tags[row_count] = tag
			row_files[tag] = file
			row_lines[tag] = line
			row_types[tag] = typ
			base = basename(file)
			row_exts[tag] = ext_from_basename(base)
			row_fileids[tag] = fileid_from_path(file)
			row_count++
			next
		}

		# Parse col tags: same format as row tags
		mode == "col_tags" {
			if ($0 == "") next
			tag = trim(field1($0, sep))
			file = trim(field2($0, sep))
			line = trim(field3($0, sep))
			if (tag == "") next
			if (line == "" || line + 0 < 1) line = 1
			typ = (tag in tagType) ? tagType[tag] : "Unknown"
			col_tags[col_count] = tag
			col_files[tag] = file
			col_lines[tag] = line
			col_types[tag] = typ
			base = basename(file)
			col_exts[tag] = ext_from_basename(base)
			col_fileids[tag] = fileid_from_path(file)
			col_count++
			next
		}

		# Parse matrix: @ROW_TAG@<sep>@COL_TAG@
		mode == "matrix" {
			if ($0 == "") next
			row_tag = trim(field1($0, sep))
			col_tag = trim(field2($0, sep))
			if (row_tag == "" || col_tag == "") next
			matrix[row_tag "," col_tag] = 1
			next
		}

		END {
			# Generate HTML table
			printf "<table id=\"%s\" class=\"matrix-table\">\n", table_id
			printf "<thead>\n  <tr>\n"

			# Header: first cell is empty (corner cell)
			printf "    <th>.</th>\n"

			# Column headers with badges
			for (c = 0; c < col_count; c++) {
				tag = col_tags[c]
				typ = col_types[tag]
				line = col_lines[tag]
				fileid = col_fileids[tag]
				ext = col_exts[tag]
				badge_html = badge(tag, typ, line, fileid, ext)
				printf "    <th>%s</th>\n", badge_html
			}
			printf "  </tr>\n</thead>\n"

			# Table body
			printf "<tbody>\n"
			for (r = 0; r < row_count; r++) {
				row_tag = row_tags[r]
				row_typ = row_types[row_tag]
				row_line = row_lines[row_tag]
				row_fileid = row_fileids[row_tag]
				row_ext = row_exts[row_tag]
				row_badge = badge(row_tag, row_typ, row_line, row_fileid, row_ext)

				printf "  <tr>\n"
				printf "    <td>%s</td>\n", row_badge

				# Data cells: "x" if link exists, empty otherwise
				for (c = 0; c < col_count; c++) {
					col_tag = col_tags[c]
					key = row_tag "," col_tag
					if (key in matrix) {
						printf "    <td class=\"xref-link\">x</td>\n"
					} else {
						printf "    <td class=\"xref-empty\"></td>\n"
					}
				}
				printf "  </tr>\n"
			}
			printf "</tbody>\n"
			printf "</table>\n"
		}
	'
}

##
# @brief   Generate HTML cross-reference table from JSON cross_reference object
# @param   $1 : JSON cross_reference object (single object from cross_references array)
# @param   $2 : table_id for HTML table element
# @param   $3 : TAG_INFO_TABLE string (tag<sep>line<sep>path<sep>trace_target per line)
# @return  Echoes HTML table to stdout
# @tag     @IMP2.6.2@ (FROM: @ARC2.6@)
_html_generate_cross_ref_table_from_json() {
	_json_xref="$1"
	_table_id="$2"
	_tag_info_table="$3"
	_sep="$SHTRACER_SEPARATOR"

	# Error handling: empty JSON
	if [ -z "$_json_xref" ]; then
		printf '<table id="%s" class="matrix-table"><tbody><tr><td>Error: Empty cross-reference data</td></tr></tbody></table>\n' "$_table_id"
		return 1
	fi

	# Parse JSON and TAG_INFO_TABLE, then generate HTML table
	{
		# TAG_INFO_TABLE is a string containing the data
		printf '%s\n' "$_tag_info_table"
		printf '%s\n' "__SHTRACER_TAG_INFO_END__"
		printf '%s' "$_json_xref"
	} | awk -v sep="$_sep" -v table_id="$_table_id" '
		BEGIN {
			mode = "tag_info"
			row_count = 0
			col_count = 0
			in_source_tags = 0
			in_target_tags = 0
			in_links = 0
			in_tag_obj = 0
			in_link_obj = 0
			in_source_section = 0
			in_target_section = 0
		}
		function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
		function get_last_segment(s,   n, parts) {
			n = split(s, parts, ":")
			return n > 0 ? parts[n] : s
		}
		function type_from_trace_target(tt,   n, p, t) {
			if (tt == "") return "Unknown"
			n = split(tt, p, ":")
			t = trim(p[n])
			return t == "" ? "Unknown" : t
		}
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
		function escape_html(s,   t) {
			t = s
			gsub(/&/, "&amp;", t)
			gsub(/</, "&lt;", t)
			gsub(/>/, "&gt;", t)
			gsub(/"/, "&quot;", t)
			return t
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
			gsub(/.*\//, "", t)  # Extract basename only
			gsub(/\./, "_", t)   # Replace dots with underscores
			return "Target_" t
		}
		function badge(tag, typ, line, fileId, ext,   safeTyp, safeTag, safeId, safeExt, safeDesc, safeFromTags, desc, from_tags) {
			safeTyp = escape_html(typ)
			safeTag = escape_html(tag)
			safeId = escape_html(fileId)
			safeExt = escape_html(ext)
			desc = tagDescription[tag]
			from_tags = tagFromTags[tag]
			safeDesc = escape_html(desc)
			gsub(/"/, "\\&quot;", safeDesc)
			safeFromTags = escape_html(from_tags)
			gsub(/"/, "\\&quot;", safeFromTags)
			return "<span class=\"matrix-tag-badge\" data-type=\"" safeTyp "\">" \
				"<a href=\"#\" onclick=\"showText(event, &quot;" safeId "&quot;, " line ", &quot;" safeExt "&quot;, &quot;" safeTag "&quot;, &quot;" safeDesc "&quot;, &quot;" safeTyp "&quot;, &quot;" safeFromTags "&quot;)\" " \
				"onmouseover=\"showTooltip(event, &quot;" safeId "&quot;)\" onmouseout=\"hideTooltip()\">" safeTag "</a></span>"
		}
		function extract_json_string(line, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*\""
			if (match(line, r)) {
				v = line
				sub(".*" r, "", v)
				# Handle escaped quotes and extract until unescaped quote
				gsub(/\\"/, "\x01", v)  # Temporarily replace escaped quotes
				sub(/".*/, "", v)
				gsub(/\x01/, "\\", v)   # Restore escaped quotes
				return v
			}
			return ""
		}
		function extract_json_int(line, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*"
			if (match(line, r)) {
				v = line
				sub(".*" r, "", v)
				sub(/[^0-9].*/, "", v)
				return v
			}
			return ""
		}

		# Read TAG_INFO_TABLE to build tag type mapping
		$0 == "__SHTRACER_TAG_INFO_END__" {
			mode = "json"
			next
		}
		mode == "tag_info" {
			if ($0 == "") next
			tag = trim(field1($0, sep))
			if (tag == "") next
			line_num = trim(field2($0, sep))
			file_path = trim(field3($0, sep))
			trace_target = trim(field4($0, sep))
			description = trim(field5($0, sep))
			from_tags_raw = trim(field6($0, sep))
			typ = type_from_trace_target(trace_target)
			tagType[tag] = typ
			tagLine[tag] = line_num
			tagFile[tag] = file_path
			tagDescription[tag] = description
			tagFromTags[tag] = from_tags_raw
			next
		}

		# Parse JSON cross_reference object
		mode == "json" {
			# Detect source_layer.tag_ids array
			if ($0 ~ /"source_layer"/) {
				in_source_section = 1
			}
			if (in_source_section && $0 ~ /"tag_ids"[[:space:]]*:[[:space:]]*\[/) {
				in_source_tags = 1
			}
			if (in_source_tags && $0 ~ /\]/) {
				in_source_tags = 0
				in_source_section = 0
			}

			# Detect target_layer.tag_ids array
			if ($0 ~ /"target_layer"/) {
				in_target_section = 1
			}
			if (in_target_section && $0 ~ /"tag_ids"[[:space:]]*:[[:space:]]*\[/) {
				in_target_tags = 1
			}
			if (in_target_tags && $0 ~ /\]/) {
				in_target_tags = 0
				in_target_section = 0
			}

			# Detect links array
			if ($0 ~ /"links"[[:space:]]*:[[:space:]]*\[/) {
				in_links = 1
			}
			if (in_links && $0 ~ /\]/) {
				in_links = 0
			}

			# Parse source_layer.tag_ids array (string values)
			if (in_source_tags && $0 ~ /"@[^"]+@"/) {
				v = extract_json_string($0, "")
				if (v !~ /^@.*@$/) {
					# Try another method - extract quoted string
					if (match($0, /"(@[^"]+@)"/)) {
						v = substr($0, RSTART+1, RLENGTH-2)
					}
				}
				if (v ~ /^@.*@$/) {
					tag = v
					file = tagFile[tag]
					line = tagLine[tag]
					if (file == "") file = "/unknown"
					if (line == "" || line + 0 < 1) line = 1
					typ = (tag in tagType) ? tagType[tag] : "Unknown"
					row_tags[row_count] = tag
					row_files[tag] = file
					row_lines[tag] = line
					row_types[tag] = typ
					base = basename(file)
					row_exts[tag] = ext_from_basename(base)
					row_fileids[tag] = fileid_from_path(file)
					row_count++
				}
			}

			# Parse target_layer.tag_ids array (string values)
			if (in_target_tags && $0 ~ /"@[^"]+@"/) {
				v = extract_json_string($0, "")
				if (v !~ /^@.*@$/) {
					# Try another method - extract quoted string
					if (match($0, /"(@[^"]+@)"/)) {
						v = substr($0, RSTART+1, RLENGTH-2)
					}
				}
				if (v ~ /^@.*@$/) {
					tag = v
					file = tagFile[tag]
					line = tagLine[tag]
					if (file == "") file = "/unknown"
					if (line == "" || line + 0 < 1) line = 1
					typ = (tag in tagType) ? tagType[tag] : "Unknown"
					col_tags[col_count] = tag
					col_files[tag] = file
					col_lines[tag] = line
					col_types[tag] = typ
					base = basename(file)
					col_exts[tag] = ext_from_basename(base)
					col_fileids[tag] = fileid_from_path(file)
					col_count++
				}
			}

			# Parse links objects
			if (in_links && $0 ~ /\{/) {
				in_link_obj = 1
				source = ""
				target = ""
			}
			if (in_links && in_link_obj) {
				v = extract_json_string($0, "source")
				if (v != "") source = v
				v = extract_json_string($0, "target")
				if (v != "") target = v

				if ($0 ~ /\}/) {
					if (source != "" && target != "") {
						matrix[source "," target] = 1
					}
					in_link_obj = 0
				}
			}
		}

		END {
			# Generate HTML table (same structure as _html_generate_cross_ref_table)
			printf "<table id=\"%s\" class=\"matrix-table\">\n", table_id
			printf "<thead>\n  <tr>\n"

			# Header: first cell is empty (corner cell)
			printf "    <th>.</th>\n"

			# Column headers with badges
			for (c = 0; c < col_count; c++) {
				tag = col_tags[c]
				typ = col_types[tag]
				line = col_lines[tag]
				fileid = col_fileids[tag]
				ext = col_exts[tag]
				badge_html = badge(tag, typ, line, fileid, ext)
				printf "    <th>%s</th>\n", badge_html
			}
			printf "  </tr>\n</thead>\n"

			# Table body
			printf "<tbody>\n"
			for (r = 0; r < row_count; r++) {
				row_tag = row_tags[r]
				row_typ = row_types[row_tag]
				row_line = row_lines[row_tag]
				row_fileid = row_fileids[row_tag]
				row_ext = row_exts[row_tag]
				row_badge = badge(row_tag, row_typ, row_line, row_fileid, row_ext)

				printf "  <tr>\n"
				printf "    <td>%s</td>\n", row_badge

				# Data cells: "x" if link exists, empty otherwise
				for (c = 0; c < col_count; c++) {
					col_tag = col_tags[c]
					key = row_tag "," col_tag
					if (key in matrix) {
						printf "    <td class=\"xref-link\">x</td>\n"
					} else {
						printf "    <td class=\"xref-empty\"></td>\n"
					}
				}
				printf "  </tr>\n"
			}
			printf "</tbody>\n"
			printf "</table>\n"
		}
	'
}

##
# @brief   Insert file information into HTML with proper indentation
# @param   $1 : HTML_CONTENT (template HTML to modify)
# @param   $2 : INFORMATION (file list HTML)
# @return  Modified HTML with inserted content and fixed indentation
_html_insert_content_with_indentation() {
	_html_insert_info_file="$(shtracer_tmpfile)" || {
		error_exit 1 "_html_insert_content_with_indentation" "Failed to create temporary file"
	}
	trap 'rm -f "$_html_insert_info_file" 2>/dev/null || true' EXIT INT TERM

	printf '%s' "$2" >"$_html_insert_info_file"

	_html_insert_result=$(echo "$1" \
		| awk -v info_file="$_html_insert_info_file" '
			BEGIN {
				idx = 0
				while ((getline line < info_file) > 0) {
					gsub(/\r$/, "", line)
					lines[idx++] = line
				}
				close(info_file)
			}
			{
				if (match($0, / *<!-- INSERT INFORMATION -->/)) {
					print "<!-- SHTRACER INSERTED -->"
					for (i = 0; i < idx; i++) {
						print lines[i]
					}
					print "<!-- SHTRACER INSERTED -->"
				} else {
					print
				}
			}' \
		| awk '
			BEGIN {
			    add_space = 0
			}

			/<!-- SHTRACER INSERTED -->/ {
				if (add_space == 0) {
					add_space = 1
					add_space_count = previous_space_count + (previous_space_count == space_count ? 2 : 4)
				} else {
					add_space = 0
					printf "%*s%s\n", add_space_count, "", $0
					next
				}
			}

			{
				previous_space_count = space_count
				match($0, /^[ \t]*/)
				space_count = RLENGTH

				if (add_space == 1) {
					printf "%*s%s\n", add_space_count, "", $0
				} else {
					print $0
				}
			}
		' \
		| remove_lines_with_pattern '<!-- SHTRACER INSERTED -->')

	rm -f "$_html_insert_info_file" 2>/dev/null || true
	trap - EXIT INT TERM
	echo "$_html_insert_result"
}

##
# @brief Convert a template html file for output.html
# @param $1 : TAG_TABLE_FILENAME
# @param $2 : TAG_INFO_TABLE
# @param $3 : JSON_FILE (optional)
# @details
#   Template HTML is obtained via _viewer_get_template_html() which supports
#   external override via SHTRACER_TEMPLATE_DIR or $HOME/.shtracer/ (optional)
# @tag    @IMP3.1.1@ (FROM: @ARC3.1@)
convert_template_html() {
	(
		profile_start "convert_template_html"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$2"
		_TEMPLATE_HTML_DIR="$3"
		_JSON_FILE="${4:-}"

		profile_start "convert_template_html_read_json"
		if [ -z "$_JSON_FILE" ]; then
			_JSON_FILE="${OUTPUT_DIR%/}/output.json"
		fi
		profile_end "convert_template_html_read_json"

		profile_start "convert_template_html_build_table"
		_TABLE_HTML="$(_html_add_table_header "$_TAG_INFO_TABLE")"
		_TABLE_HTML="$_TABLE_HTML$(_html_convert_tag_table "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE")"
		profile_end "convert_template_html_build_table"

		# @tag @IMP4.4@ (FROM: @ARC4@)
		# Generate cross-reference tables for tab UI
		profile_start "convert_template_html_build_xref_tables"

		# Generate tab structure
		_TABS_HTML=""
		_TABLES_HTML=""

		# First tab: "All" (existing RTM)
		_TABS_HTML='<button class="matrix-tab active" data-matrix="all" onclick="switchMatrixTab(event, '"'all'"')">All</button>'
		_TABLES_HTML='<table id="tag-table-all" class="matrix-table active">'
		_TABLES_HTML="$_TABLES_HTML$_TABLE_HTML"
		_TABLES_HTML="$_TABLES_HTML</table>"

		# Check if JSON has cross_references field (new format)
		_HAS_JSON_XREFS=0
		if [ -f "$_JSON_FILE" ] && grep -q '"cross_references"' "$_JSON_FILE" 2>/dev/null; then
			_HAS_JSON_XREFS=1
		fi

		if [ "$_HAS_JSON_XREFS" -eq 1 ]; then
			# JSON-based approach: extract cross_references from JSON
			# Extract each cross_reference object from JSON and generate tables
			_xref_objects_file=$(shtracer_tmpfile) || error_exit 1 "convert_template_html" "Failed to create temporary file"
			trap 'rm -f "$_xref_objects_file" 2>/dev/null || true' EXIT INT TERM

			awk '
				BEGIN {
					in_cross_refs = 0
					in_obj = 0
					brace_depth = 0
					obj_content = ""
				}
				# Detect cross_references array
				/"cross_references"[[:space:]]*:/ {
					seen_cross_refs_key = 1
				}
				seen_cross_refs_key && /\[/ {
					in_cross_refs = 1
					seen_cross_refs_key = 0
					next
				}
				in_cross_refs {
					# Track brace depth to detect object boundaries
					line = $0
					for (i = 1; i <= length(line); i++) {
						c = substr(line, i, 1)
						if (c == "{") {
							if (brace_depth == 0) {
								in_obj = 1
								obj_content = "{"
							} else {
								obj_content = obj_content c
							}
							brace_depth++
						} else if (c == "}") {
							brace_depth--
							if (brace_depth == 0 && in_obj) {
								obj_content = obj_content "}"
								# Output complete object with marker
								print "__XREF_OBJECT_START__"
								print obj_content
								print "__XREF_OBJECT_END__"
								obj_content = ""
								in_obj = 0
							} else {
								obj_content = obj_content c
							}
						} else if (in_obj) {
							obj_content = obj_content c
						}

						# Detect end of cross_references array
						if (c == "]" && brace_depth == 0 && in_cross_refs) {
							in_cross_refs = 0
							exit
						}
					}
					# Add newline at end of each line to preserve formatting
					if (in_obj) {
						obj_content = obj_content "\n"
					}
				}
			' <"$_JSON_FILE" >"$_xref_objects_file"

			# Process each cross_reference object
			_current_obj=""
			_in_obj=0
			while IFS= read -r _line; do
				if [ "$_line" = "__XREF_OBJECT_START__" ]; then
					_in_obj=1
					_current_obj=""
				elif [ "$_line" = "__XREF_OBJECT_END__" ]; then
					_in_obj=0

					# Extract layer names from JSON object (multi-line safe)
					_source_name=$(printf '%s\n' "$_current_obj" | awk '
						BEGIN { in_source = 0 }
						/"source_layer"/ { in_source = 1 }
						in_source && /"name"[[:space:]]*:/ {
							match($0, /"name"[[:space:]]*:[[:space:]]*"([^"]*)"/, arr)
							if (arr[1] != "") { print arr[1]; exit }
						}
					')
					_target_name=$(printf '%s\n' "$_current_obj" | awk '
						BEGIN { in_target = 0 }
						/"target_layer"/ { in_target = 1 }
						in_target && /"name"[[:space:]]*:/ {
							match($0, /"name"[[:space:]]*:[[:space:]]*"([^"]*)"/, arr)
							if (arr[1] != "") { print arr[1]; exit }
						}
					')

					# Generate tab ID and label
					_tab_id=$(printf '%s-%s' "$_source_name" "$_target_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
					_tab_label="$_source_name↔$_target_name"

					# Append tab button
					_TABS_HTML="$_TABS_HTML<button class=\"matrix-tab\" data-matrix=\"$_tab_id\" onclick=\"switchMatrixTab(event, '$_tab_id')\">$_tab_label</button>"

					# Generate table from JSON object
					_table_html=$(_html_generate_cross_ref_table_from_json "$_current_obj" "tag-table-$_tab_id" "$_TAG_INFO_TABLE")
					_TABLES_HTML="$_TABLES_HTML$_table_html"
				elif [ "$_in_obj" -eq 1 ]; then
					_current_obj="${_current_obj}${_line}
"
				fi
			done <"$_xref_objects_file"

			rm -f "$_xref_objects_file"
		else
			# Fallback: File-based approach (backward compatibility)
			_XREF_DIR="${OUTPUT_DIR%/}/tags/"
			_XREF_FILES=""
			if [ -d "$_XREF_DIR" ]; then
				for _f in "$_XREF_DIR"[0-9][0-9]_cross_ref_matrix_*; do
					[ -f "$_f" ] || continue
					_XREF_FILES="$_XREF_FILES$(basename "$_f")
"
				done
			fi

			# Generate tabs for each cross-reference file
			if [ -n "$_XREF_FILES" ]; then
				# Extract known layer names from TAG_INFO_TABLE
				_LAYER_MAP=$(
					{
						if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
							cat "$_TAG_INFO_TABLE"
						else
							printf '%s\n' "$_TAG_INFO_TABLE"
						fi
					} | awk -F"$SHTRACER_SEPARATOR" '
					function get_last_segment(s,   n, parts) {
						n = split(s, parts, ":")
						return n > 0 ? parts[n] : s
					}
					NF >= 4 && $4 != "" {
						display_name = get_last_segment($4)
						# Convert display name to filename pattern (spaces to underscores)
						pattern = display_name
						gsub(/ /, "_", pattern)
						if (pattern != "" && !seen[pattern]++) {
							# Output: filename_pattern => display_name
							print pattern "=>" display_name
						}
					}
				'
				)

				for _xref_file in $_XREF_FILES; do
					# Extract layer identifiers from filename: 06_cross_ref_matrix_LAYER1_LAYER2
					_base_name="${_xref_file#*_cross_ref_matrix_}"

					# Use AWK to find matching layer pair
					_layer_pair=$(printf '%s\n%s' "$_LAYER_MAP" "$_base_name" | awk -F'=>' '
					BEGIN { n_layers = 0 }
					/=>/ {
						# Store layer mappings: pattern => display_name
						layer_map[$1] = $2
						pattern_len[$1] = length($1)
						n_layers = n_layers + 1
						layers[n_layers] = $1
						next
					}
					{
						# This is the filename to parse
						filename = $0
						found = 0

						# Sort layers by length (descending) for longest match first
						for (i = 1; i < n_layers; i++) {
							for (j = i + 1; j <= n_layers; j++) {
								if (pattern_len[layers[i]] < pattern_len[layers[j]]) {
									tmp = layers[i]
									layers[i] = layers[j]
									layers[j] = tmp
								}
							}
						}

						# Try all possible split points with longest match first
						for (i = 1; i <= n_layers; i++) {
							pattern1 = layers[i]
							if (index(filename, pattern1 "_") == 1) {
								# filename starts with this pattern
								remaining = substr(filename, length(pattern1) + 2)
								# Check if remaining matches another pattern (try longest first)
								for (j = 1; j <= n_layers; j++) {
									pattern2 = layers[j]
									if (remaining == pattern2) {
										# Found a match!
										print layer_map[pattern1] "\t" layer_map[pattern2]
										found = 1
										exit
									}
								}
							}
						}

						# No match found - skip this file
						if (!found) {
							print "NOMATCH\tNOMATCH"
						}
					}
				')

					_row_layer=$(printf '%s' "$_layer_pair" | cut -f1)
					_col_layer=$(printf '%s' "$_layer_pair" | cut -f2)

					# Skip if no match was found
					if [ "$_row_layer" = "NOMATCH" ] || [ "$_col_layer" = "NOMATCH" ]; then
						continue
					fi

					# Generate tab ID and label
					_tab_id=$(printf '%s-%s' "$_row_layer" "$_col_layer" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
					_tab_label="$_row_layer↔$_col_layer"

					# Append tab button
					_TABS_HTML="$_TABS_HTML<button class=\"matrix-tab\" data-matrix=\"$_tab_id\" onclick=\"switchMatrixTab(event, '$_tab_id')\">$_tab_label</button>"

					# Generate table
					_table_html=$(_html_generate_cross_ref_table "${_XREF_DIR}${_xref_file}" "tag-table-$_tab_id" "$_TAG_INFO_TABLE")
					_TABLES_HTML="$_TABLES_HTML$_table_html"
				done
			fi
		fi # End of else block (file-based approach)

		# Combine into final structure
		# Check if we have cross-reference tables (count tabs)
		_HAS_XREF_TABS=0
		if printf '%s' "$_TABS_HTML" | grep -q -c 'matrix-tab' | awk '{if ($1 > 1) exit 0; else exit 1}'; then
			_HAS_XREF_TABS=1
		fi

		if [ "$_HAS_XREF_TABS" -eq 1 ]; then
			# Tab UI mode: wrap in container
			_MATRIX_CONTAINER_HTML="<div class=\"matrix-tabs-container\">"
			_MATRIX_CONTAINER_HTML="$_MATRIX_CONTAINER_HTML<div class=\"matrix-tabs\" id=\"matrix-tab-buttons\">$_TABS_HTML</div>"
			_MATRIX_CONTAINER_HTML="$_MATRIX_CONTAINER_HTML<div class=\"matrix-content\">$_TABLES_HTML</div>"
			_MATRIX_CONTAINER_HTML="$_MATRIX_CONTAINER_HTML</div>"
		else
			# Backward compatibility: no cross-ref tables, use old behavior
			_MATRIX_CONTAINER_HTML="<table id=\"tag-table\">$_TABLE_HTML</table>"
		fi
		profile_end "convert_template_html_build_xref_tables"

		# Extract trace target order from TAG_INFO_TABLE (same as table headers)
		profile_start "convert_template_html_extract_order"
		_TRACE_TARGET_ORDER="$(
			{
				if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
					cat "$_TAG_INFO_TABLE"
				else
					printf '%s\n' "$_TAG_INFO_TABLE"
				fi
			} | awk -F"$SHTRACER_SEPARATOR" -v col_idx=0 '
				function get_last_segment(s,   n, parts) {
					n = split(s, parts, ":")
					return n > 0 ? parts[n] : s
				}
				{
					if (NF >= 4 && $4 != "") {
						trace_target = $4
						col_name = get_last_segment(trace_target)
						if (!(col_name in seen)) {
							seen[col_name] = 1
							cols[col_idx++] = col_name
						}
					}
				}
				END {
					for (i = 0; i < col_idx; i++) {
						if (i > 0) printf ","
						printf "\n  \"%s\"", cols[i]
					}
					if (col_idx > 0) printf "\n"
				}
			'
		)"
		profile_end "convert_template_html_extract_order"

		profile_start "convert_template_html_insert_tag_table"
		_tmp_table_html_file="$(shtracer_tmpfile)" || {
			error_exit 1 "convert_template_html" "Failed to create temporary file"
		}
		printf '%s' "$_MATRIX_CONTAINER_HTML" >"$_tmp_table_html_file"
		_tmp_trace_order_file="$(shtracer_tmpfile)" || {
			error_exit 1 "convert_template_html" "Failed to create temporary file for trace order"
		}
		printf '%s' "$_TRACE_TARGET_ORDER" >"$_tmp_trace_order_file"
		_HTML_CONTENT="$(
			_viewer_get_template_html | sed -e "s/'\\n'/'\\\\n'/g" \
				| awk -v table_html_file="$_tmp_table_html_file" -v json_file="$_JSON_FILE" -v trace_order_file="$_tmp_trace_order_file" '
                    /^[ \t]*<!-- INSERT TABLE -->/ {
                        print "<!-- SHTRACER INSERTED -->"
                        while ((getline line < table_html_file) > 0) {
                            gsub(/\r$/, "", line)
                            print line
                        }
                        close(table_html_file)
                        print "<!-- SHTRACER INSERTED -->"
                        next
                    }
                    /^[ \t]*<!-- INSERT JSON DATA -->/ {
                        # Output trace target order
                        print "const traceTargetOrder = ["
                        while ((getline ord_line < trace_order_file) > 0) {
                            gsub(/\r$/, "", ord_line)
                            print ord_line
                        }
                        close(trace_order_file)
                        print "];"
                        # Output JSON data
                        print "const traceabilityData = "
                        while ((getline j < json_file) > 0) {
                            gsub(/\r$/, "", j)
                            gsub(/<\/script>/, "<\\/script>", j)
                            print j
                        }
                        close(json_file)
                        print ";"
                        next
                    }
                    { print }
                '
		)"
		rm -f "$_tmp_table_html_file" "$_tmp_trace_order_file"
		profile_end "convert_template_html_insert_tag_table" profile_start "_html_insert_content_with_indentation"
		_HTML_CONTENT="$(_html_insert_content_with_indentation "$_HTML_CONTENT" "$_INFORMATION")"
		profile_end "_html_insert_content_with_indentation"

		echo "$_HTML_CONTENT"

		profile_end "convert_template_html"
	)
}

##
# @brief   Build TAG_INFO_TABLE from shtracer JSON output
# @param   $1 : JSON_FILE
# @return  Echoes TAG_INFO_TABLE to stdout (tag<sep>line<sep>path per line)
tag_info_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_info_table_from_json_file" "JSON file not readable"
	fi
	_sep="${SHTRACER_SEPARATOR}"
	_tmp_file="$(shtracer_tmpfile)" || error_exit 1 "tag_info_table_from_json_file" "Failed to create temporary file"
	_tmp_sort="$(shtracer_tmpfile)" || error_exit 1 "tag_info_table_from_json_file" "Failed to create temporary file"
	_tmp_config_order="$(shtracer_tmpfile)" || error_exit 1 "tag_info_table_from_json_file" "Failed to create temporary file"
	trap 'rm -f "$_tmp_file" "$_tmp_sort" "$_tmp_config_order" 2>/dev/null || true' EXIT INT TERM

	# Extract trace target order from config.md (both ## and ### headings)
	_config_path="$(extract_json_string_field "$_JSON_FILE" "config_path")"
	if [ -n "$_config_path" ] && [ -r "$_config_path" ]; then
		awk '
			/^##+ / {
				heading = $0
				sub(/^##+ /, "", heading)
				sub(/[[:space:]]*$/, "", heading)
				if (heading !~ /^[[:space:]]*$/ && !(heading in seen)) {
					print ++order_idx, heading
					seen[heading] = 1
				}
			}
		' <"$_config_path" >"$_tmp_config_order"
	fi

	awk '
		BEGIN {
			in_files = 0
			in_file_obj = 0
			seen_files_key = 0
			in_layers = 0
			in_layer_obj = 0
			seen_layers_key = 0
			in_nodes = 0
			in_obj = 0
			seen_nodes_key = 0
		}
		function grab_str(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*\""
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("\".*", "", v)
				return v
			}
			return ""
		}
		function grab_int(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*"
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("[^0-9].*", "", v)
				return v
			}
			return ""
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)

			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				# Parse files array
				if (!in_files && t ~ /"files"[[:space:]]*:/) { seen_files_key = 1 }
				if (!in_files && seen_files_key && t ~ /\[/) { in_files = 1; seen_files_key = 0 }
				if (in_files && !in_file_obj && t ~ /\{/) { in_file_obj = 1; file_id = ""; file = "" }
				if (in_file_obj) {
					v = grab_int(t, "file_id"); if (v != "") { file_id = v }
					v = grab_str(t, "file"); if (v != "") { file = v }
					if (t ~ /\}/) {
						if (file_id != "" && file != "") { file_map[file_id] = file }
						in_file_obj = 0
					}
				}
				if (in_files && !in_file_obj && t ~ /\]/) { in_files = 0 }

				# Parse layers array
				if (!in_layers && t ~ /"layers"[[:space:]]*:/) { seen_layers_key = 1 }
				if (!in_layers && seen_layers_key && t ~ /\[/) { in_layers = 1; seen_layers_key = 0 }
				if (in_layers && !in_layer_obj && t ~ /\{/) { in_layer_obj = 1; layer_id = ""; layer_name = "" }
				if (in_layer_obj) {
					v = grab_int(t, "layer_id"); if (v != "") { layer_id = v }
					v = grab_str(t, "name"); if (v != "") { layer_name = v }
					if (t ~ /\}/) {
						if (layer_id != "" && layer_name != "") { layer_map[layer_id] = layer_name }
						in_layer_obj = 0
					}
				}
				if (in_layers && !in_layer_obj && t ~ /\]/) { in_layers = 0 }

				# Parse trace_tags array
				if (!in_nodes && t ~ /"trace_tags"[[:space:]]*:/) {
					seen_nodes_key = 1
				}
				if (!in_nodes && seen_nodes_key && t ~ /\[/) {
					in_nodes = 1
					seen_nodes_key = 0
				}

				if (in_nodes && !in_obj && t ~ /\{/) {
					in_obj = 1
					id = ""
					file_id = ""
					layer_id = ""
					ln = ""
					idx = ""
				}

				if (in_obj) {
					v = grab_str(t, "id"); if (v != "") { id = v }
					v = grab_int(t, "file_id"); if (v != "") { file_id = v }
					v = grab_int(t, "layer_id"); if (v != "") { layer_id = v }
					v = grab_int(t, "line"); if (v != "") { ln = v }
					v = grab_int(t, "index"); if (v != "") { idx = v }
					v = grab_str(t, "description"); if (v != "") { desc = v }

					# Collect from_tags array elements
					if (t ~ /"from_tags"[[:space:]]*:/) { in_from_tags = 1; from_tags = ""; from_tag_sep = "" }
					if (in_from_tags && t ~ /"@[^"]*@"/) {
						v = grab_str(t, "");
						if (v ~ /@[^@]*@/ && v != "NONE") {
							from_tags = from_tags from_tag_sep v
							from_tag_sep = ","
						}
					}
					if (in_from_tags && t ~ /\]/) { in_from_tags = 0 }

					if (t ~ /\}/) {
						if (idx == "") { idx = 999999999 }
						# Resolve file_id and layer_id to actual values
						file = file_map[file_id]
						trace_target = layer_map[layer_id]
						if (id != "" && file != "" && ln != "") {
							print idx "\t" id "\t" ln "\t" file "\t" trace_target "\t" desc "\t" from_tags
						}
						in_obj = 0
						desc = ""
						from_tags = ""
					}
				}

				if (in_nodes && !in_obj && t ~ /\]/) {
					in_nodes = 0
				}
			}
		}
	' <"$_JSON_FILE" \
		| sort -k1,1n \
			>"$_tmp_sort"

	# Assign trace target order based on config.md heading order
	awk -F '\t' -v sep="$_sep" -v config_order_file="$_tmp_config_order" '
		BEGIN {
			# Load config.md heading order
			old_fs = FS
			FS = " "
			while ((getline line < config_order_file) > 0) {
				split(line, parts, " ")
				order_num = parts[1]
				heading = parts[2]
				for (i = 3; i in parts; i++) heading = heading " " parts[i]
				config_order[heading] = order_num
			}
			close(config_order_file)
			FS = old_fs
		}
		function get_last_segment(s,   n, parts) {
			n = split(s, parts, ":")
			return n > 0 ? parts[n] : s
		}
		{
			tag = $2
			line = $3
			file = $4
			trace_target = $5
			desc = $6
			from_tags = $7

			# Extract type from trace_target (last segment)
			type = get_last_segment(trace_target)

			# Get order from config.md
			order = config_order[type]
			if (order == "") order = 999

			# Output with order prefix for sorting
			print order "\t" tag "\t" line "\t" file "\t" trace_target "\t" desc "\t" from_tags
		}
	' <"$_tmp_sort" \
		| sort -k1,1n \
		| awk -F '\t' -v sep="$_sep" -v OFS="" '
			!seen[$2]++ {
				print $2, sep, $3, sep, $4, sep, $5, sep, $6, sep, $7
			}
		' >"$_tmp_file"

	if [ -n "$_config_path" ]; then
		printf '%s%s%s%s%s%s%s\n' '@CONFIG@' "$_sep" '1' "$_sep" "$_config_path" "$_sep" '' >>"$_tmp_file"
	fi

	cat "$_tmp_file"
	rm -f "$_tmp_file" "$_tmp_sort" "$_tmp_config_order" 2>/dev/null || true
	trap - EXIT INT TERM
}

##
# @brief   Build TAG_TABLE from shtracer JSON output (chains)
# @param   $1 : JSON_FILE
# @return  Echoes TAG_TABLE rows to stdout (space-separated tags per line)
tag_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_table_from_json_file" "JSON file not readable"
	fi

	awk '
		BEGIN {
			in_chains = 0
			in_chain = 0
			seen_chains_key = 0
			out = ""
		}
		function grab_str(s,   v) {
			v = s
			sub(/^[[:space:]]*"/, "", v)
			sub(/".*$/, "", v)
			return v
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)
			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				if (!in_chains && t ~ /"chains"[[:space:]]*:/) {
					seen_chains_key = 1
				}
				if (!in_chains && seen_chains_key && t ~ /\[/) {
					in_chains = 1
					seen_chains_key = 0
					continue
				}

				if (in_chains && !in_chain && t ~ /\[/) {
					in_chain = 1
					out = ""
					continue
				}

				if (in_chain) {
					if (t ~ /^[[:space:]]*"/) {
						v = grab_str(t)
						if (v != "") {
							if (out == "") out = v
							else out = out " " v
						}
					}
					if (t ~ /\]/) {
						if (out != "") print out
						in_chain = 0
						out = ""
						continue
					}
				}

				if (in_chains && !in_chain && t ~ /\]/) {
					in_chains = 0
				}
			}
		}
	' <"$_JSON_FILE"
}

##
# @brief Convert template js file for tracing targets
# @param $1 : TAG_INFO_TABLE
# @details
#   Generates show_text.js with embedded source file contents
# @tag    @IMP3.1.2@ (FROM: @ARC3.1@)
convert_template_js() {
	(
		profile_start "convert_template_js"
		_TAG_INFO_TABLE="$1"

		_JS_CONTENTS="$(
			echo "$_TAG_INFO_TABLE" | awk -F"$SHTRACER_SEPARATOR" '{ print $3 }' | sort -u \
				| awk '
					function js_escape(s) {
						gsub(/\\/, "\\\\", s)
						gsub(/"/, "\\\"", s)
						gsub(/\t/, "\\t", s)
						gsub(/\r/, "\\r", s)
						gsub(/<\//, "<\\/", s)
						return s
					}
					function file_to_js_string(path,   line, out) {
						out = ""
						while ((getline line < path) > 0) {
							gsub(/\r$/, "", line)
							out = out js_escape(line) "\\n"
						}
						close(path)
						return out
					}
					function file_id_from_path(path,   t, n, parts) {
						# Extract basename only
						n = split(path, parts, "/")
						t = parts[n]
						# Replace dots with underscores
						gsub(/\./, "_", t)
						return "Target_" t
					}
					{
						path = $0
						n = split($0, parts, "/")
						raw_filename = parts[n]
						extension_pos = match(raw_filename, /[.][^.]+$/)
						if (extension_pos) extension = substr(raw_filename, extension_pos + 1)
						else extension = "txt"

						file_id = file_id_from_path(path)

						contents = file_to_js_string(path)
						print "\t\"" js_escape(file_id) "\": {"
						print "\t\tpath:\"" js_escape(path) "\","
						print "\t\tcontent:\"" contents "\","
						print "\t\textension:\"" js_escape(extension) "\""
						print "\t},"
					}'
		)"
		_viewer_get_template_js "show_text.js" | while read -r s; do
			case "$s" in
				*//\ js_contents*)
					printf "%s\n" "$_JS_CONTENTS"
					;;
				*)
					printf "%s\n" "$s"
					;;
			esac
		done
		profile_end "convert_template_js"
	)
}

##
# @brief  Make output files (html, js, css)
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
# @tag    @IMP3.1.3@ (FROM: @ARC3.1@)
make_html() {
	(
		_OUTPUT_ASSETS_DIR="${OUTPUT_DIR%/}/assets/"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" -v config_path="${CONFIG_PATH}" -v separator="$SHTRACER_SEPARATOR" '
			BEGIN {
				OFS = separator;
			}
			{
                trace_target = $1;
				tag = $2;
				path = $5
				line = $6
				description = ($7 != "" ? $7 : "")
				from_tags = ($8 != "" ? $8 : "")
                print tag, line, path, trace_target, description, from_tags
			}
			END {
                print "@CONFIG@", "1", config_path, "", "", ""
			}')"

		mkdir -p "${OUTPUT_DIR%/}/assets/"
		convert_template_html "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE" >"${OUTPUT_DIR%/}/output.html"
		convert_template_js "$_TAG_INFO_TABLE" >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"
		_viewer_get_template_css >"${_OUTPUT_ASSETS_DIR%/}/template.css"
		_viewer_get_template_js "traceability_diagrams.js" >"${_OUTPUT_ASSETS_DIR%/}/traceability_diagrams.js"
	)
}

print_usage() {
	cat <<-USAGE 1>&2
		Usage: shtracer_html_viewer.sh [--tag-table <tag_table_file>] [-i <json_file>]

		Reads shtracer JSON from stdin (default) or from -i <json_file>,
		and writes a single self-contained HTML document to stdout.

		Examples:
		  # JSON-only (viewer builds the tag table from JSON chains)
		  ./shtracer ./sample/config.md --json | ./scripts/main/shtracer_html_viewer.sh > output.html

		  # Explicit tag-table path
		    ./shtracer --debug ./sample/config.md --json | ./scripts/main/shtracer_html_viewer.sh --tag-table ./sample/shtracer_output/tags/04_tag_table > output.html

		  # JSON file input
		    ./scripts/main/shtracer_html_viewer.sh -i ./sample/shtracer_output/output.json > output.html
	USAGE
	exit 1
}

shtracer_viewer_main() {
	JSON_FILE=""
	TAG_TABLE_FILE=""

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				print_usage
				;;
			-i)
				shift
				[ $# -gt 0 ] || print_usage
				JSON_FILE="$1"
				;;
			--tag-table)
				shift
				[ $# -gt 0 ] || print_usage
				TAG_TABLE_FILE="$1"
				;;
			*)
				print_usage
				;;
		esac
		shift
	done

	# Determine repo root (SCRIPT_DIR in shtracer terminology)
	_REPO_DIR="$(
		unset CDPATH
		cd "$(dirname "$0")/../.." && pwd -P
	)"
	SCRIPT_DIR="$_REPO_DIR"
	export SCRIPT_DIR

	# Source shared functions (must be sourced, not executed)
	# shellcheck source=scripts/main/shtracer_util.sh
	. "${SCRIPT_DIR%/}/scripts/main/shtracer_util.sh"

	SHTRACER_SEPARATOR="${SHTRACER_SEPARATOR:=<shtracer_separator>}"
	export SHTRACER_SEPARATOR

	NODATA_STRING="${NODATA_STRING:=NONE}"
	export NODATA_STRING

	_tmp_dir="$(shtracer_tmpdir)" || {
		echo "[shtracer_html_viewer.sh][error]: failed to create temporary directory" 1>&2
		exit 1
	}
	_json_tmp="${_tmp_dir%/}/input.json"
	_html_tmp="${_tmp_dir%/}/base.html"
	_tag_table_tmp="${_tmp_dir%/}/tag_table"
	_show_text_tmp="${_tmp_dir%/}/show_text.js"
	_trace_js_tmp="${_tmp_dir%/}/traceability_diagrams.js"

	cleanup() {
		rm -rf "$_tmp_dir" 2>/dev/null || true
	}
	trap cleanup EXIT INT TERM

	if [ -n "$JSON_FILE" ]; then
		[ -r "$JSON_FILE" ] || {
			echo "[shtracer_html_viewer.sh][error]: json not readable: $JSON_FILE" 1>&2
			exit 1
		}
		cat "$JSON_FILE" >"$_json_tmp"
	else
		if [ -t 0 ]; then
			echo "[shtracer_html_viewer.sh][error]: no stdin; use -i <json_file>" 1>&2
			exit 1
		fi
		cat >"$_json_tmp"
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		_config_path="$(extract_json_string_field "$_json_tmp" "config_path")"
		if [ -n "$_config_path" ]; then
			_config_dir="$(dirname "$_config_path")"
			_inferred_table="${_config_dir%/}/shtracer_output/tags/04_tag_table"
			if [ -r "$_inferred_table" ]; then
				TAG_TABLE_FILE="$_inferred_table"
			fi
		fi
	fi

	if [ -n "$TAG_TABLE_FILE" ] && [ ! -r "$TAG_TABLE_FILE" ]; then
		echo "[shtracer_html_viewer.sh][error]: tag table not readable: $TAG_TABLE_FILE" 1>&2
		exit 1
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		tag_table_from_json_file "$_json_tmp" >"$_tag_table_tmp"
		if [ ! -s "$_tag_table_tmp" ]; then
			echo "[shtracer_html_viewer.sh][error]: cannot build tag table from JSON (missing/empty chains)" 1>&2
			exit 1
		fi
		TAG_TABLE_FILE="$_tag_table_tmp"
	fi

	_TAG_INFO_TABLE="$(tag_info_table_from_json_file "$_json_tmp")"

	convert_template_html "$TAG_TABLE_FILE" "$_TAG_INFO_TABLE" "$_json_tmp" >"$_html_tmp"
	convert_template_js "$_TAG_INFO_TABLE" >"$_show_text_tmp"
	_viewer_get_template_js "traceability_diagrams.js" >"$_trace_js_tmp"

	_css_tmp="$(shtracer_tmpfile)" || {
		error_exit 1 "shtracer_viewer_main" "Failed to create CSS temp file"
	}
	_viewer_get_template_css >"$_css_tmp"

	awk \
		-v css_file="$_css_tmp" \
		-v show_text_file="$_show_text_tmp" \
		-v trace_js_file="$_trace_js_tmp" \
		'
			function emit_file(path) {
				while ((getline line < path) > 0) {
					gsub(/\r$/, "", line)
					print line
				}
				close(path)
			}
			{
				if ($0 ~ /<link rel="stylesheet" href="\.\/assets\/template\.css">/) {
					print "  <style>"
					emit_file(css_file)
					print "  </style>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/show_text\.js"><\/script>/) {
					print "  <script>"
					emit_file(show_text_file)
					print "  </script>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/traceability_diagrams\.js"><\/script>/) {
					print "  <script>"
					emit_file(trace_js_file)
					print "  </script>"
					next
				}
				print
			}
		' <"$_html_tmp"
}

case "$0" in
	*shtracer_html_viewer.sh | *shtracer_viewer)
		shtracer_viewer_main "$@"
		;;
	*)
		: # sourced
		;;
esac
