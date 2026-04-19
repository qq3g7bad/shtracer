#!/bin/sh

# This script can be executed (JSON -> single HTML to stdout) or sourced (unit tests).

##
# @brief  Generic template loader with external override support
# @param  $1 : Filename (e.g., "template.html", "template.css", "show_text.js")
# @param  $2 : Subdirectory under SHTRACER_TEMPLATE_DIR (empty for root, "assets" for assets)
# @return Template content via stdout
# @details
#   Resolution priority:
#   1. $SHTRACER_TEMPLATE_DIR/<subdir>/<filename> (if set)
#   2. $HOME/.shtracer/<subdir>/<filename>
#   3. scripts/main/templates/<filename> (bundled)
#   Environment: SHTRACER_SCRIPT_DIR can be set to override script directory detection
# @tag    @IMP3.12@ (FROM: @ARC3.2@)
_viewer_get_template() {
	_filename="${1:-}"
	_subdir="${2:-}"
	_template_path=""

	[ -z "$_filename" ] && return 1

	# Determine script directory
	if [ -n "${SHTRACER_SCRIPT_DIR:-}" ]; then
		_script_dir="$SHTRACER_SCRIPT_DIR"
	elif [ -f "$0" ]; then
		_script_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
	else
		_script_dir=""
	fi

	# Build relative path (with optional subdir)
	if [ -n "$_subdir" ]; then
		_rel_path="${_subdir}/${_filename}"
	else
		_rel_path="$_filename"
	fi

	# Priority 1: SHTRACER_TEMPLATE_DIR environment variable
	if [ -n "${SHTRACER_TEMPLATE_DIR:-}" ] \
		&& [ -f "${SHTRACER_TEMPLATE_DIR%/}/${_rel_path}" ]; then
		_template_path="${SHTRACER_TEMPLATE_DIR%/}/${_rel_path}"
	# Priority 2: User home directory
	elif [ -n "${HOME:-}" ] && [ -f "${HOME}/.shtracer/${_rel_path}" ]; then
		_template_path="${HOME}/.shtracer/${_rel_path}"
	# Priority 3: Bundled templates directory
	elif [ -n "$_script_dir" ] && [ -f "${_script_dir}/templates/${_filename}" ]; then
		_template_path="${_script_dir}/templates/${_filename}"
	fi

	if [ -n "$_template_path" ]; then
		cat "$_template_path"
	else
		echo "[shtracer_html_viewer.sh][error]: ${_filename} not found" >&2
		return 1
	fi
}

##
# @brief  Get template HTML content with external override support
# @return Template HTML content via stdout
# @tag    @IMP3.10@ (FROM: @ARC3.2@)
_viewer_get_template_html() {
	_viewer_get_template "template.html" ""
}

##
# @brief  Get template CSS content with external override support
# @return Template CSS content via stdout
# @tag    @IMP3.11@ (FROM: @ARC3.2@)
_viewer_get_template_css() {
	_viewer_get_template "template.css" "assets"
}

##
# @brief  Get JavaScript template content with external override support
# @param  $1 : JavaScript template filename (e.g., "show_text.js", "traceability_diagrams.js")
# @return Template JavaScript content via stdout
_viewer_get_template_js() {
	_js_filename="${1:-}"
	[ -z "$_js_filename" ] && return 1
	_viewer_get_template "$_js_filename" "assets"
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
	} | awk -F"$_sep" -v col_idx=0 \
		"$AWK_FN_GET_LAST_SEGMENT"'
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
	} | awk -v sep="$_sep" -v nodata="$_nodata" \
		"$AWK_FN_COMMON"'
		'"$AWK_FN_FIELD_EXTRACTORS"'
        BEGIN {
            ndims = 0
            mode = 0
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
                "onmouseover=\"showTooltip(event, &quot;" safeId "&quot;, &quot;" safeTag "&quot;, " line ", &quot;" safeTyp "&quot;, &quot;" safeDesc "&quot;)\" onmouseout=\"hideTooltip()\">" safeTag "</a></span>"
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
	} | awk -v sep="$_sep" -v nodata="$_nodata" -v table_id="$_table_id" \
		"$AWK_FN_COMMON"'
		'"$AWK_FN_FIELD_EXTRACTORS"'
		BEGIN {
			mode = "tag_info"
			row_count = 0
			col_count = 0
			row_prefix = ""
			col_prefix = ""
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
		_JSON_FILE="${3:-}"

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

		# Cross-reference tables are always built from intermediate files
		# (tags/[0-9][0-9]_cross_ref_matrix_*). The internal matrix file format
		# is the source of truth; JSON's cross_references field is a derivative.
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
				} | awk -F"$SHTRACER_SEPARATOR" \
					"$AWK_FN_GET_LAST_SEGMENT"'
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
			} | awk -F"$SHTRACER_SEPARATOR" -v col_idx=0 \
				"$AWK_FN_GET_LAST_SEGMENT"'
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
# @brief   Build TAG_INFO_TABLE from shtracer intermediate files
# @param   $1 : TAGS_FILE  (tags/01_tags)
# @param   $2 : CONFIG_TABLE_FILE  (config/01_config_table)
# @param   $3 : CONFIG_PATH  (used for synthetic @CONFIG@ row; empty to omit)
# @return  Echoes TAG_INFO_TABLE to stdout
#          Each row: tag<sep>line<sep>path<sep>trace_target<sep>desc<sep>from_tags
#          Rows are ordered by trace-target appearance in CONFIG_TABLE.
# @details
#   Reads 01_tags (fields: trace_target, tag, from_tags, description,
#   file_path, line, ...) and emits the same 6-field SEP-delimited layout
#   previously produced from JSON. An optional synthetic @CONFIG@ row
#   appended at the end carries the config_path for downstream consumers.
tag_info_table_from_files() {
	_tags_file="$1"
	_config_table_file="$2"
	_config_path="${3:-}"

	if [ -z "$_tags_file" ] || [ ! -r "$_tags_file" ]; then
		error_exit 1 "tag_info_table_from_files" "01_tags not readable"
	fi
	if [ -z "$_config_table_file" ] || [ ! -r "$_config_table_file" ]; then
		error_exit 1 "tag_info_table_from_files" "01_config_table not readable"
	fi

	_sep="${SHTRACER_SEPARATOR}"

	# Emit rows sorted by config-table layer appearance order. The last
	# segment of `trace_target` (after the trailing ":") is the "type" label
	# that viewers use for sorting (e.g. "Requirement", "Architecture").
	awk -F"$_sep" \
		-v sep="$_sep" \
		-v config_table="$_config_table_file" \
		"$AWK_FN_GET_LAST_SEGMENT"'
		BEGIN {
			# Build layer-order map from the config table. First appearance
			# of each distinct layer name wins.
			order_idx = 0
			while ((getline line < config_table) > 0) {
				n = split(line, f, sep)
				if (n < 1 || f[1] == "") continue
				name = get_last_segment(f[1])
				if (name != "" && !(name in seen_layer)) {
					seen_layer[name] = 1
					layer_order[name] = ++order_idx
				}
			}
			close(config_table)
		}
		NF >= 6 && $2 != "" {
			trace_target = $1
			tag = $2
			from_tags = $3
			desc = $4
			path = $5
			line = $6
			if (line == "" || line + 0 < 1) line = 1
			# Root-layer tags have from_tags == "NONE"; flatten to empty so
			# consumers do not render "NONE" as a parent tag.
			if (from_tags == "NONE") from_tags = ""
			type = get_last_segment(trace_target)
			order = (type in layer_order) ? layer_order[type] : 999
			# Dedupe by tag (first row wins); preserve layer order.
			if (!(tag in seen_tag)) {
				seen_tag[tag] = 1
				printf "%d\t%s%s%s%s%s%s%s%s%s%s\n", order, tag, sep, line, sep, path, sep, trace_target, sep, desc, sep from_tags
			}
		}
	' "$_tags_file" \
		| sort -k1,1n \
		| cut -f2-

	# Optional synthetic @CONFIG@ row so consumers can discover the config
	# file from TAG_INFO_TABLE alone (mirrors the legacy JSON-based format).
	if [ -n "$_config_path" ]; then
		printf '%s%s%s%s%s%s%s\n' '@CONFIG@' "$_sep" '1' "$_sep" "$_config_path" "$_sep" ''
	fi
}

##
# @brief   Build TAG_TABLE (traceability chains) from intermediate file
# @param   $1 : TAG_TABLE_FILE  (tags/04_tag_table)
# @return  Echoes TAG_TABLE rows to stdout verbatim.
# @details
#   The 04_tag_table intermediate file already has the exact format the
#   viewer expects (space-separated tags per chain, trailing "NONE" padding).
#   This is a thin passthrough kept for symmetry with tag_info_table_from_files.
tag_table_from_file() {
	_tag_table="$1"
	if [ -z "$_tag_table" ] || [ ! -r "$_tag_table" ]; then
		error_exit 1 "tag_table_from_file" "04_tag_table not readable"
	fi
	cat "$_tag_table"
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

		mkdir -p "${OUTPUT_DIR%/}/assets/" || error_exit 1 "html_viewer" "Cannot create assets directory"
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
	_show_text_tmp="${_tmp_dir%/}/show_text.js"
	_trace_js_tmp="${_tmp_dir%/}/traceability_diagrams.js"

	cleanup() {
		rm -rf "$_tmp_dir" 2>/dev/null || true
	}
	trap cleanup EXIT INT TERM

	if [ ! -t 0 ]; then
		cat >"$_json_tmp"
	elif [ -n "$JSON_FILE" ]; then
		[ -r "$JSON_FILE" ] || {
			echo "[shtracer_html_viewer.sh][error]: json not readable: $JSON_FILE" 1>&2
			exit 1
		}
		cat "$JSON_FILE" >"$_json_tmp"
	else
		echo "[shtracer_html_viewer.sh][error]: no stdin; use -i <json_file>" 1>&2
		exit 1
	fi

	# Resolve OUTPUT_DIR from stdin JSON's metadata.config_path (Option B).
	# The HTML viewer now reads everything but metadata from intermediate
	# files; JSON is only used for (a) this lookup and (b) client-side
	# embedding into the final HTML (traceabilityData).
	_config_path="$(extract_json_string_field "$_json_tmp" "config_path")"
	if [ -n "${OUTPUT_DIR:-}" ]; then
		_HV_OUTPUT_DIR="${OUTPUT_DIR%/}"
	elif [ -n "$_config_path" ]; then
		_HV_OUTPUT_DIR="$(dirname "$_config_path")/shtracer_output"
	else
		_HV_OUTPUT_DIR="./shtracer_output"
	fi
	OUTPUT_DIR="$_HV_OUTPUT_DIR"
	export OUTPUT_DIR

	_HV_TAGS_FILE="${_HV_OUTPUT_DIR}/tags/01_tags"
	_HV_CONFIG_TABLE="${_HV_OUTPUT_DIR}/config/01_config_table"
	_HV_TAG_TABLE="${_HV_OUTPUT_DIR}/tags/04_tag_table"

	# Sanity-check required intermediate files
	for _f in "$_HV_TAGS_FILE" "$_HV_CONFIG_TABLE" "$_HV_TAG_TABLE"; do
		if [ ! -r "$_f" ]; then
			echo "[shtracer_html_viewer.sh][error]: required intermediate file missing: $_f" 1>&2
			exit 1
		fi
	done

	# --tag-table override still honored for debugging / custom layouts.
	if [ -z "$TAG_TABLE_FILE" ]; then
		TAG_TABLE_FILE="$_HV_TAG_TABLE"
	fi

	if [ ! -r "$TAG_TABLE_FILE" ]; then
		echo "[shtracer_html_viewer.sh][error]: tag table not readable: $TAG_TABLE_FILE" 1>&2
		exit 1
	fi

	_TAG_INFO_TABLE="$(tag_info_table_from_files "$_HV_TAGS_FILE" "$_HV_CONFIG_TABLE" "$_config_path")"

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
