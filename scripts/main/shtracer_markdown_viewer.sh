#!/bin/sh

# This script can be executed (JSON -> Markdown report to stdout) or sourced (unit tests).
# Reads JSON from stdin and outputs a unified print-friendly markdown report.

##
# @brief Generate markdown header section (title, metadata)
# @param $1 : JSON input string
# @tag @IMP4.3.1@ (FROM: @ARC4.1@)
_generate_markdown_header() {
	_json="$1"

	# Parse metadata
	_metadata=$(_parse_json_metadata "$_json")
	_version=$(printf '%s\n' "$_metadata" | grep '^version=' | cut -d= -f2-)
	_generated=$(printf '%s\n' "$_metadata" | grep '^generated=' | cut -d= -f2-)
	_config_path=$(printf '%s\n' "$_metadata" | grep '^config_path=' | cut -d= -f2-)

	# Generate header with actual values
	cat <<EOF
# Traceability Report

- **Generated**: $_generated
- **Config**: \`$_config_path\`
- **shtracer version**: $_version

---
EOF
}

##
# @brief Generate table of contents with anchor links
# @param $1 : JSON input string
# @tag @IMP4.3.2@ (FROM: @ARC4.1@)
_generate_markdown_toc() {
	_json="$1"

	# TODO: Generate dynamic TOC
	cat <<'EOF'

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Traceability Health](#traceability-health)
3. [Requirement traceability matrix](#requirement-traceability-matrix)
4. [Cross-Reference Details](#cross-reference-details)
5. [Tag Index](#tag-index)

---

EOF
}

##
# @brief Calculate coverage statistics from JSON
# @param $1 : JSON input string
# @return Prints statistics (total_tags, complete_chains, incomplete_chains, layer counts)
# @tag @IMP4.3.3.1@ (FROM: @ARC4.1@)
##
# @brief Generate executive summary with statistics tables
# @param $1 : JSON input string
# @tag @IMP4.3.3@ (FROM: @ARC4.1@)
_generate_markdown_summary() {
	_json="$1"

	# Parse coverage data from JSON
	_coverage_data=$(_parse_json_coverage "$_json")
	_health_data=$(_parse_json_health "$_json")

	# Extract health metrics
	_total_tags=$(printf '%s\n' "$_health_data" | grep '^total_tags=' | cut -d= -f2)
	_isolated_tags=$(printf '%s\n' "$_health_data" | grep '^isolated_tags=' | cut -d= -f2)

	# Determine health status
	if [ "$_isolated_tags" -eq 0 ]; then
		_health_status="✓ Healthy"
	elif [ "$_isolated_tags" -gt 10 ]; then
		_health_status="✗ Poor"
	else
		_health_status="⚠ Fair"
	fi

	# Generate summary header
	cat <<EOF

## Executive Summary

EOF

	# Generate layer-by-layer breakdown with file details
	# Extract unique layers in order from coverage data
	printf '%s\n' "$_coverage_data" | grep '^layer|' | while IFS='|' read -r _type _layer _total _up_count _down_count _up_pct _down_pct; do
		# Print layer header
		printf '### %s\n\n' "$_layer"

		# Use awk for float comparison (JSON)
		if awk "BEGIN {exit !($_up_pct > 0 || $_down_pct > 0)}"; then
			_up_str=""
			_down_str=""

			if awk "BEGIN {exit !($_up_pct > 0)}"; then
				_up_str="upstream $_up_pct%"
			fi
			if awk "BEGIN {exit !($_down_pct > 0)}"; then
				_down_str="downstream $_down_pct%"
			fi

			if [ -n "$_up_str" ] && [ -n "$_down_str" ]; then
				printf '%s / %s\n\n' "$_up_str" "$_down_str"
			elif [ -n "$_up_str" ]; then
				printf '%s\n\n' "$_up_str"
			elif [ -n "$_down_str" ]; then
				printf '%s\n\n' "$_down_str"
			fi
		fi

		# Print file-level details for this layer
		printf '%s\n' "$_coverage_data" | grep "^file|$_layer|" | while IFS='|' read -r _type _l _file _ftotal _fup _fdown _fup_pct _fdown_pct _fver; do
			# Format version display (handle mtime:, git:, or unknown)
			if [ -z "$_fver" ] || [ "$_fver" = "unknown" ]; then
				_ver_display="unknown"
			elif printf '%s' "$_fver" | grep -q '^mtime:'; then
				# mtime:2025-12-26T10:30:45Z → 2025-12-26 10:30
				_timestamp=$(printf '%s' "$_fver" | sed 's/^mtime://')
				_ver_display=$(printf '%s' "$_timestamp" | sed 's/T/ /' | sed 's/:[0-9][0-9]Z$//')
			elif printf '%s' "$_fver" | grep -q '^git:'; then
				# git:abc1234 → `abc1234` (with backticks)
				_hash=$(printf '%s' "$_fver" | sed 's/^git://')
				_ver_display="\`$_hash\`"
			else
				_ver_display="$_fver"
			fi

			# Extract basename from full path for better readability
			_file_basename=$(basename "$_file")
			# Use %s for float percent values (not %d)
			printf '%s %s (%s) upstream %s%% / downstream %s%%\n' "-" "$_file_basename" "$_ver_display" "$_fup_pct" "$_fdown_pct"
		done
		printf '\n'
	done

	printf -- '---\n\n'
}

##
# @brief Find isolated tags (tags with no outbound links)
# @param $1 : JSON input string
# @return Prints isolated tag IDs (one per line)
# @tag @IMP4.3.4.1@ (FROM: @ARC4.1@)
_find_isolated_tags() {
	_json="$1"

	_nodes=$(_parse_json_nodes "$_json")
	_links=$(_parse_json_links "$_json")

	# Get all tag IDs
	_all_tags=$(printf '%s\n' "$_nodes" | cut -d'|' -f1)

	# Get tags that have outbound links
	_tags_with_links=$(printf '%s\n' "$_links" | cut -d'|' -f1 | sort -u)

	# Find tags NOT in the links list (isolated)
	printf '%s\n' "$_all_tags" | while IFS= read -r _tag; do
		if ! printf '%s\n' "$_tags_with_links" | grep -qxF "$_tag"; then
			echo "$_tag"
		fi
	done
}

##
# @brief Generate traceability health analysis (coverage, isolated tags, issues)
# @param $1 : JSON input string
# @tag @IMP4.3.4@ (FROM: @ARC4.1@)
_generate_markdown_health() {
	_json="$1"

	# Parse health data from JSON
	_health_data=$(_parse_json_health "$_json")

	# Get stats
	_total_tags=$(printf '%s\n' "$_health_data" | grep '^total_tags=' | cut -d= -f2)
	_tags_with_links=$(printf '%s\n' "$_health_data" | grep '^tags_with_links=' | cut -d= -f2)
	_isolated_tags=$(printf '%s\n' "$_health_data" | grep '^isolated_tags=' | cut -d= -f2)
	_duplicate_tags=$(printf '%s\n' "$_health_data" | grep '^duplicate_tags=' | cut -d= -f2)
	_dangling_refs=$(printf '%s\n' "$_health_data" | grep '^dangling_references=' | cut -d= -f2)

	# Default to 0 if not found
	_duplicate_tags=${_duplicate_tags:-0}
	_dangling_refs=${_dangling_refs:-0}

	# Calculate percentages
	if [ "$_total_tags" -gt 0 ]; then
		_isolated_pct=$((100 * _isolated_tags / _total_tags))
	else
		_isolated_pct=0
	fi

	_tags_with_links_pct=$((100 - _isolated_pct))

	# Start output
	cat <<EOF
## Traceability Health

### Coverage Analysis

| Metric                | Value    |
| --------------------- | -------- |
| Total Tags            | $_total_tags      |
| Tags with Links       | $_tags_with_links ($_tags_with_links_pct%) |
| Isolated Tags         | $_isolated_tags ($_isolated_pct%) |
| Duplicate Tags        | $_duplicate_tags |
| Dangling References   | $_dangling_refs |

EOF

	# Isolated tags section
	_isolated_lines=$(printf '%s\n' "$_health_data" | grep '^isolated|')

	printf '### Isolated Tags\n\n'

	if [ "$_isolated_tags" -eq 0 ]; then
		printf '✓ No isolated tags found.\n\n'
	else
		printf '%s isolated tag(s) with no downstream traceability:\n\n' "$_isolated_tags"
		printf '%s\n' "$_isolated_lines" | while IFS='|' read -r _prefix _isolated_tag _file _line; do
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				# Extract basename from full path for better readability
				_file_basename=$(basename "$_file")
				printf "%s **%s** (%s:%s)\n" "-" "$_isolated_tag" "$_file_basename" "${_line:-1}"
			else
				printf "%s **%s**\n" "-" "$_isolated_tag"
			fi
		done

		printf '\n'
	fi

	# Dangling references section
	_dangling_lines=$(printf '%s\n' "$_health_data" | grep '^dangling|')

	# Duplicate tags section
	_duplicate_lines=$(printf '%s\n' "$_health_data" | grep '^duplicate|')

	printf '### Duplicate Tags\n\n'

	if [ "$_duplicate_tags" -eq 0 ]; then
		printf '✓ No duplicate tags found.\n\n'
	else
		printf '%s duplicate tag(s) detected (same tag ID appears multiple times):\n\n' "$_duplicate_tags"
		printf '%s\n' "$_duplicate_lines" | while IFS='|' read -r _prefix _dup_tag _file _line; do
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				_file_basename=$(basename "$_file")
				printf "%s **%s** (%s:%s)\n" "-" "$_dup_tag" "$_file_basename" "${_line:-1}"
			else
				printf "%s **%s**\n" "-" "$_dup_tag"
			fi
		done

		printf '\n'
	fi

	printf '### Dangling References\n\n'

	if [ "$_dangling_refs" -eq 0 ]; then
		printf '✓ No dangling references found.\n\n'
	else
		printf '%s dangling reference(s) - tags referencing non-existent parents:\n\n' "$_dangling_refs"
		printf '| Child Tag | Missing Parent | File | Line |\n'
		printf '|-----------|----------------|------|------|\n'
		printf '%s\n' "$_dangling_lines" | while IFS='|' read -r _prefix _child_tag _parent_tag _file _line; do
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				# Extract basename from full path for better readability
				_file_basename=$(basename "$_file")
				printf '| %s | %s | %s | %s |\n' "$_child_tag" "$_parent_tag" "$_file_basename" "${_line:-1}"
			else
				printf '| %s | %s | %s | %s |\n' "$_child_tag" "$_parent_tag" "unknown" "${_line:-1}"
			fi
		done

		printf '\n'
	fi

	printf -- '---\n\n'
}

##
# @brief Generate complete chains section (simplified vertical format)
# @param $1 : JSON input string
# @tag @IMP4.3.5@ (FROM: @ARC4.1@)
_generate_markdown_chains() {
	_json="$1"

	_chains=$(_parse_json_chains "$_json")
	_nodes=$(_parse_json_nodes "$_json")

	# Count total chains
	_total=$(printf '%s\n' "$_chains" | grep -c '^' || echo 0)

	printf '## Requirement traceability matrix\n\n'
	printf '%s total traceability chains.\n\n' "$_total"

	# Get dynamic layer order
	_order=$(_extract_layer_order "$_json")
	_col_count=$(printf '%s\n' "$_order" | grep -c '^' || echo 0)

	# Build table header (use sed to join with ' | ')
	_header=$(printf '%s\n' "$_order" | sed ':a;N;$!ba;s/\n/ | /g')
	printf '| %s |\n' "$_header"

	# Build separator row
	printf '|'
	_i=0
	while [ "$_i" -lt "$_col_count" ]; do
		printf '%s' '------|'
		_i=$((_i + 1))
	done
	printf '\n'

	# Build data rows (ALL chains, no truncation)
	printf '%s\n' "$_chains" | while IFS= read -r _chain; do
		[ -z "$_chain" ] && continue
		printf '| '
		printf '%s' "$_chain" | sed 's/|/ | /g'
		printf ' |\n'
	done

	printf '\n---\n\n<!-- PAGE BREAK -->\n'
}

##
# @brief Parse matrix file metadata section
# @param $1 : Matrix file path
# @return Prints row_layer|col_layer|timestamp (pipe-separated)
# @tag @IMP4.3.6.1@ (FROM: @ARC4.1@)
_parse_matrix_metadata() {
	_matrix_file="$1"
	_sep="${SHTRACER_SEPARATOR:-<shtracer_separator>}"

	awk -F"$_sep" '
		/^\[METADATA\]/ { mode = "meta"; next }
		/^\[ROW_TAGS\]/ { mode = ""; exit }
		mode == "meta" && NF >= 2 {
			# Extract row and col patterns (e.g., @REQ[0-9.]+@ and @ARC[0-9.]+@)
			row_pattern = $1
			col_pattern = $2
			timestamp = $3

			# Convert pattern to layer name (strip regex characters)
			# @REQ[0-9.]+@ -> REQ, @ARC[0-9.]+@ -> ARC
			gsub(/@|\[.*\]|\+/, "", row_pattern)
			gsub(/@|\[.*\]|\+/, "", col_pattern)

			print row_pattern "|" col_pattern "|" timestamp
			exit
		}
	' "$_matrix_file"
}

##
# @brief Parse matrix file row tags section
# @param $1 : Matrix file path
# @return Prints @TAG@|/path/file|line (one per line)
# @tag @IMP4.3.6.2@ (FROM: @ARC4.1@)
_parse_matrix_row_tags() {
	_matrix_file="$1"
	_sep="${SHTRACER_SEPARATOR:-<shtracer_separator>}"

	awk -F"$_sep" '
		/^\[ROW_TAGS\]/ { mode = "row"; next }
		/^\[COL_TAGS\]/ { mode = ""; exit }
		mode == "row" && $0 != "" && NF >= 3 {
			print $1 "|" $2 "|" $3
		}
	' "$_matrix_file"
}

##
# @brief Parse matrix file column tags section
# @param $1 : Matrix file path
# @return Prints @TAG@|/path/file|line (one per line)
# @tag @IMP4.3.6.3@ (FROM: @ARC4.1@)
_parse_matrix_col_tags() {
	_matrix_file="$1"
	_sep="${SHTRACER_SEPARATOR:-<shtracer_separator>}"

	awk -F"$_sep" '
		/^\[COL_TAGS\]/ { mode = "col"; next }
		/^\[MATRIX\]/ { mode = ""; exit }
		mode == "col" && $0 != "" && NF >= 3 {
			print $1 "|" $2 "|" $3
		}
	' "$_matrix_file"
}

##
# @brief Parse matrix file links section
# @param $1 : Matrix file path
# @return Prints @ROW_TAG@|@COL_TAG@ (one per line)
# @tag @IMP4.3.6.4@ (FROM: @ARC4.1@)
_parse_matrix_links() {
	_matrix_file="$1"
	_sep="${SHTRACER_SEPARATOR:-<shtracer_separator>}"

	awk -F"$_sep" '
		/^\[MATRIX\]/ { mode = "matrix"; next }
		mode == "matrix" && $0 != "" && NF >= 2 {
			print $1 "|" $2
		}
	' "$_matrix_file"
}

##
# @brief Generate markdown table for one cross-reference matrix (2-column format)
# @param $1 : Matrix file path
# @param $2 : JSON input (for layer name resolution)
# @return Prints complete markdown section with 2-column table (Source Tag | Target Tag)
# @tag @IMP4.3.6.5@ (FROM: @ARC4.1@)
_generate_markdown_matrix_table() {
	_matrix_file="$1"
	_json="$2"

	# Parse metadata
	_metadata=$(_parse_matrix_metadata "$_matrix_file")
	_row_layer=$(printf '%s' "$_metadata" | cut -d'|' -f1)
	_col_layer=$(printf '%s' "$_metadata" | cut -d'|' -f2)

	# Get full layer names from JSON (fallback to abbreviated if not found)
	_row_layer_full=$(_get_layer_display_name "$_json" "$_row_layer")
	_col_layer_full=$(_get_layer_display_name "$_json" "$_col_layer")

	# Parse links
	_links=$(_parse_matrix_links "$_matrix_file")

	# Count stats
	_link_count=$(printf '%s\n' "$_links" | grep -c '^' || echo 0)

	# Generate section header (directional: source → target)
	printf '### %s → %s\n\n' "$_row_layer_full" "$_col_layer_full"
	printf '**Summary**:\n\n'
	printf -- '- %s traceability links\n' "$_link_count"
	printf '\n'

	# Generate 2-column table header
	printf '| %s | %s |\n' "Source Tag" "Target Tag"
	printf '|------------|------------|\n'

	# Generate rows from links
	printf '%s\n' "$_links" | while IFS='|' read -r _source _target; do
		[ -z "$_source" ] && continue
		printf '| %s | %s |\n' "$_source" "$_target"
	done
	printf '\n'
}

##
# @brief Get display name for layer abbreviation
# @param $1 : JSON input string
# @param $2 : Layer abbreviation (e.g., REQ, ARC)
# @return Full layer name (e.g., Requirement, Architecture) or abbreviation if not found
# @tag @IMP4.3.6.6@ (FROM: @ARC4.1@)
_get_layer_display_name() {
	_json="$1"
	_abbrev="$2"

	# Extract layer name from JSON layers array
	# Returns first match or fallback to abbreviation
	printf '%s\n' "$_json" | awk -v abbrev="$_abbrev" '
		BEGIN { in_layers = 0; in_layer_obj = 0 }
		/"layers":/ && /\[/ { in_layers = 1; next }
		in_layers && /^\s*\]/ { in_layers = 0; next }
		in_layers && /^\s*\{/ { in_layer_obj = 1; layer_name = ""; next }
		in_layer_obj && /"name":/ {
		line = $0
		sub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line)
		sub(/".*$/, "", line)
			layer_name = line
		}
		in_layer_obj && /^\s*\}/ {
			in_layer_obj = 0
			if (layer_name != "") {
				# Check if this layer matches the abbreviation pattern
				# Handles case-insensitive prefix match
				if (tolower(layer_name) ~ "^" tolower(abbrev)) {
					# Store first match
					if (found == "") {
						found = layer_name
					}
				}
			}
		}
		END {
			if (found != "") {
				print found
			} else {
				print abbrev
			}
		}
	'
}

##
# @brief Generate markdown table from JSON cross_reference object (2-column format)
# @param $1 : JSON cross_reference object (single object from cross_references array)
# @return Prints complete markdown section with 2-column table (Source Tag | Target Tag)
# @tag @IMP4.3.6.7@ (FROM: @ARC4.1@)
_generate_markdown_matrix_table_from_json() {
	_json_xref="$1"

	# Extract layer names
	_row_layer=$(printf '%s' "$_json_xref" | sed -n 's/.*"source_layer"[[:space:]]*:[[:space:]]*{[^}]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
	_col_layer=$(printf '%s' "$_json_xref" | sed -n 's/.*"target_layer"[[:space:]]*:[[:space:]]*{[^}]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

	# Extract links using jq (simpler and more reliable)
	_links_tmp=$(mktemp) || return 1

	# Extract source|target pairs using jq
	printf '%s' "$_json_xref" | jq -r '.links[] | "\(.source)|\(.target)"' 2>/dev/null >"$_links_tmp" || {
		# Fallback: if jq fails, return empty
		printf '' >"$_links_tmp"
	}

	# Count stats
	_link_count=$(grep -c '^' "$_links_tmp" 2>/dev/null || echo 0)

	# Generate section header (directional: source → target)
	printf '### %s → %s\n\n' "$_row_layer" "$_col_layer"
	printf '**Summary**:\n\n'
	printf -- '- %s traceability links\n' "$_link_count"
	printf '\n'

	# Generate 2-column table header
	printf '| %s | %s |\n' "Source Tag" "Target Tag"
	printf '|------------|------------|\n'

	# Generate rows from links (read directly from file)
	while IFS='|' read -r _source _target; do
		[ -z "$_source" ] && continue
		printf '| %s | %s |\n' "$_source" "$_target"
	done <"$_links_tmp"
	printf '\n'

	# Cleanup temp files
	rm -f "$_links_tmp"
}

##
# @brief Generate cross-reference details from matrix files (layer-to-layer tables)
# @param $1 : JSON input string (used for layer name resolution)
# @details
#   Discovers all 06_cross_ref_matrix_* files in OUTPUT_DIR/tags/
#   Generates complete markdown tables for each layer pair
#   Shows ALL links without truncation
#   Format: Row headers (upstream layer), Column headers (downstream layer)
#   Cells contain ✓ if traceability link exists
# @tag @IMP4.3.6@ (FROM: @ARC4.1@)
_generate_markdown_cross_refs() {
	_json="$1"

	printf '## Cross-Reference Details\n\n'

	# Check if JSON has cross_references field (new format)
	_HAS_JSON_XREFS=0
	if printf '%s' "$_json" | grep -q '"cross_references"' 2>/dev/null; then
		_HAS_JSON_XREFS=1
	fi

	if [ "$_HAS_JSON_XREFS" -eq 1 ]; then
		# JSON-based approach: extract cross_references from JSON string
		# Extract and count cross_reference objects
		_xref_objects=$(printf '%s' "$_json" | awk '
			BEGIN {
				in_cross_refs = 0
				in_obj = 0
				brace_depth = 0
				obj_content = ""
			}
			/"cross_references"[[:space:]]*:/ { seen_cross_refs_key = 1 }
			seen_cross_refs_key && /\[/ { in_cross_refs = 1; seen_cross_refs_key = 0; next }
			in_cross_refs {
				line = $0
				for (i = 1; i <= length(line); i++) {
					c = substr(line, i, 1)
					if (c == "{") {
						if (brace_depth == 0) { in_obj = 1; obj_content = "{" } else { obj_content = obj_content c }
						brace_depth++
					} else if (c == "}") {
						brace_depth--
						if (brace_depth == 0 && in_obj) {
							obj_content = obj_content "}"
							print "__XREF_OBJECT_START__"
							print obj_content
							print "__XREF_OBJECT_END__"
							obj_content = ""
							in_obj = 0
						} else { obj_content = obj_content c }
					} else if (in_obj) { obj_content = obj_content c }
					if (c == "]" && brace_depth == 0 && in_cross_refs) { in_cross_refs = 0; exit }
				}
			}
		')

		if [ -z "$_xref_objects" ]; then
			printf 'No cross-reference data available.\n\n'
			printf -- '---\n\n<!-- PAGE BREAK -->\n'
			return 0
		fi

		# Count matrices
		_matrix_count=$(printf '%s' "$_xref_objects" | grep -c '__XREF_OBJECT_START__' || echo 0)
		printf 'Generated %s cross-reference matrix/matrices:\n\n' "$_matrix_count"

		# Process each cross_reference object
		_current_obj=""
		_in_obj=0
		printf '%s\n' "$_xref_objects" | while IFS= read -r _line; do
			if [ "$_line" = "__XREF_OBJECT_START__" ]; then
				_in_obj=1
				_current_obj=""
			elif [ "$_line" = "__XREF_OBJECT_END__" ]; then
				_in_obj=0
				_generate_markdown_matrix_table_from_json "$_current_obj"
				printf '\n'
			elif [ "$_in_obj" -eq 1 ]; then
				_current_obj="$_current_obj$_line"
			fi
		done
	else
		# Fallback: File-based approach (backward compatibility)
		_output_dir="${OUTPUT_DIR:-./shtracer_output}"
		_matrix_dir="${_output_dir%/}/tags"

		# Check if matrix files exist
		if [ ! -d "$_matrix_dir" ]; then
			printf 'No cross-reference data available.\n\n'
			printf -- '---\n\n<!-- PAGE BREAK -->\n'
			return 0
		fi

		# Find all matrix files (sorted by filename)
		_matrix_files=$(find "$_matrix_dir" -maxdepth 1 -name '[0-9][0-9]_cross_ref_matrix_*' -type f 2>/dev/null | sort)

		if [ -z "$_matrix_files" ]; then
			printf 'No cross-reference matrices found.\n\n'
			printf -- '---\n\n<!-- PAGE BREAK -->\n'
			return 0
		fi

		# Count total matrices
		_matrix_count=$(printf '%s\n' "$_matrix_files" | grep -c '^' || echo 0)
		printf 'Generated %s cross-reference matrix/matrices:\n\n' "$_matrix_count"

		# Generate table for each matrix file
		printf '%s\n' "$_matrix_files" | while IFS= read -r _matrix_file; do
			[ -z "$_matrix_file" ] && continue
			_generate_markdown_matrix_table "$_matrix_file" "$_json"
			printf '\n'
		done
	fi

	printf -- '---\n\n<!-- PAGE BREAK -->\n'
}

##
# @brief Generate tag index (alphabetically sorted by first letter)
# @param $1 : JSON input string
# @tag @IMP4.3.7@ (FROM: @ARC4.1@)
_generate_markdown_tag_index() {
	_json="$1"

	_nodes=$(_parse_json_nodes "$_json")
	_metadata=$(_parse_json_metadata "$_json")
	_version=$(printf '%s\n' "$_metadata" | grep '^version=' | cut -d= -f2)

	printf '## Tag Index\n\n'
	printf 'Alphabetical listing of all %s tags:\n\n' "$(printf '%s\n' "$_nodes" | grep -c '^' || echo 0)"

	# Group by first letter after @
	_sorted=$(printf '%s\n' "$_nodes" | sort -t'|' -k1)

	_current_letter=""
	printf '%s\n' "$_sorted" | while IFS='|' read -r _tag _desc _file _line _target _file_version; do
		# Extract first letter after @
		_first_char=$(printf '%s' "$_tag" | sed 's/^@//' | cut -c1)

		if [ "$_first_char" != "$_current_letter" ]; then
			_current_letter="$_first_char"
			printf '\n### %s\n\n' "$_first_char"
		fi

		# Truncate description if too long (keep under 60 chars for 80-col width)
		_short_desc=$(printf '%s' "$_desc" | cut -c1-50)
		if [ ${#_desc} -gt 50 ]; then
			_short_desc="${_short_desc}..."
		fi

		# Format version display (handle mtime:, git:, or unknown)
		if [ -z "$_file_version" ] || [ "$_file_version" = "unknown" ]; then
			_ver_display="unknown"
		elif printf '%s' "$_file_version" | grep -q '^mtime:'; then
			# mtime:2025-12-26T10:30:45Z → 2025-12-26 10:30
			_timestamp=$(printf '%s' "$_file_version" | sed 's/^mtime://')
			_ver_display=$(printf '%s' "$_timestamp" | sed 's/T/ /' | sed 's/:[0-9][0-9]Z$//')
		elif printf '%s' "$_file_version" | grep -q '^git:'; then
			# git:abc1234 → `abc1234` (with backticks)
			_hash=$(printf '%s' "$_file_version" | sed 's/^git://')
			_ver_display="\`$_hash\`"
		else
			_ver_display="$_file_version"
		fi

		printf '%s **%s** - %s\n' "-" "$_tag" "$_short_desc"
		printf '  - %s:%s (%s)\n' "$_file" "$_line" "$_ver_display"
	done
}

##
# @brief Parse metadata section from JSON
# @param $1 : JSON input string
# @return Prints metadata fields (version, timestamp, config_path)
# @tag @IMP4.3.8@ (FROM: @ARC4.1@)
_parse_json_metadata() {
	_json="$1"

	# AWK-based JSON metadata extraction
	printf '%s\n' "$_json" | awk '
		BEGIN { in_meta=0 }

		/"metadata":/ {
			in_meta=1
			next
		}

		in_meta && /^  \}/ {
			in_meta=0
			next
		}

		in_meta && /"version":/ {
			# Extract value between quotes after colon
			line = $0
			sub(/.*"version": *"/, "", line)
			sub(/".*$/, "", line)
			if (line != "") {
				print "version=" line
			}
		}

		in_meta && /"generated":/ {
			line = $0
			sub(/.*"generated": *"/, "", line)
			sub(/".*$/, "", line)
			if (line != "") {
				print "generated=" line
			}
		}

		in_meta && /"config_path":/ {
			line = $0
			sub(/.*"config_path": *"/, "", line)
			sub(/".*$/, "", line)
			if (line != "") {
				print "config_path=" line
			}
		}
	'
}

##
# @brief Parse files array from JSON
# @param $1 : JSON input string
# @return file_id|file|version (one per line)
# @tag @IMP4.3.8.1@ (FROM: @ARC4.1@)
_parse_json_files() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_files=0; in_file_obj=0 }

		/"files": \[/ { in_files=1; next }
		in_files && /^  \],?$/ { in_files=0; next }
		in_files && /^    \{/ {
			in_file_obj=1
			file_id=""; file=""; version=""
			next
		}
		in_files && in_file_obj && /^    \},?$/ {
			if (file_id != "") print file_id "|" file "|" version
			in_file_obj=0
			next
		}

		in_file_obj && /"file_id":/ {
		line = $0
		sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
		file_id = line
	}
		in_file_obj && /"file":/  {
		line = $0
		sub(/.*"file": *"/,  "", line)
		sub(/".*$/, "", line)
		file = line
	}
	in_file_obj && /"version":/ {
		line = $0
		sub(/.*"version": *"/, "", line)
		sub(/".*$/, "", line)
		version = line
	}
	'
}

##
# @brief Parse layers array from JSON
# @param $1 : JSON input string
# @return layer_id|name|pattern (one per line)
# @tag @IMP4.3.8.2@ (FROM: @ARC4.1@)
_parse_json_layers() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_layers=0; in_layer_obj=0 }

		/"layers": \[/ { in_layers=1; next }
		in_layers && /^  \],?$/ { in_layers=0; next }
		in_layers && /^    \{/ {
			in_layer_obj=1
			layer_id=""; name=""; pattern=""
			next
		}
		in_layers && in_layer_obj && /^    \},?$/ {
			if (layer_id != "") print layer_id "|" name "|" pattern
			in_layer_obj=0
			next
		}

		in_layer_obj && /"layer_id":/ {
		line = $0
		sub(/.*"layer_id": */, "", line)
		sub(/,.*$/, "", line)
		layer_id = line
	}
	in_layer_obj && /"name":/ {
		line = $0
		sub(/.*"name": *"/, "", line)
		sub(/".*$/, "", line)
		name = line
	}
	in_layer_obj && /"pattern":/ {
		line = $0
		sub(/.*"pattern": *"/, "", line)
		sub(/".*$/, "", line)
		pattern = line
	}
	'
}

##
# @brief Parse trace_tags array from JSON
# @param $1 : JSON input string
# @return Prints node information (id|description|file|line|trace_target|file_version) pipe-separated
# @tag @IMP4.3.9@ (FROM: @ARC4.1@)
_parse_json_nodes() {
	_json="$1"

	# Parse files and layers for lookups
	_files=$(_parse_json_files "$_json")
	_layers=$(_parse_json_layers "$_json")

	# AWK-based trace_tags extraction with lookup tables
	# Output format: id|description|file|line|trace_target|file_version (backward compatible)
	printf '%s\n' "$_json" | awk -v files="$_files" -v layers="$_layers" '
		BEGIN {
			# Build lookup maps
			split(files, file_lines, "\n")
			for (i in file_lines) {
				split(file_lines[i], parts, "|")
				file_map[parts[1]] = parts[2]    # file_id -> file
				ver_map[parts[1]] = parts[3]     # file_id -> version
			}

			split(layers, layer_lines, "\n")
			for (i in layer_lines) {
				split(layer_lines[i], parts, "|")
				layer_map[parts[1]] = parts[2]   # layer_id -> name
			}

			in_trace_tags=0; in_tag_obj=0
		}

		/"trace_tags": \[/ { in_trace_tags=1; next }
		in_trace_tags && /^  \],?$/ { in_trace_tags=0; next }

		in_trace_tags && /^    \{/ {
			in_tag_obj=1
			tag_id=""; desc=""; file_id=""; line=""; layer_id=""
			next
		}

		in_trace_tags && in_tag_obj && /^    \},?$/ {
			if (tag_id != "") {
				file = file_map[file_id]
				version = ver_map[file_id]
				target = layer_map[layer_id]
				print tag_id "|" desc "|" file "|" line "|" target "|" version
			}
			in_tag_obj=0
			next
		}

		# Extract fields
	in_tag_obj && /"id":/ {
		line = $0
		sub(/.*"id": *"/, "", line)
		sub(/".*$/, "", line)
		tag_id = line
	}
	in_tag_obj && /"description":/ {
		line = $0
		sub(/.*"description": *"/, "", line)
		sub(/".*$/, "", line)
		desc = line
	}
		in_tag_obj && /"file_id":/ {
		line = $0
		sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
		file_id = line
	}
		in_tag_obj && /"line":/ {
		line = $0
		sub(/.*"line": */, "", line)
		sub(/,.*$/, "", line)
		line = line
	}
		in_tag_obj && /"layer_id":/ {
		line = $0
		sub(/.*"layer_id": */, "", line)
		sub(/,.*$/, "", line)
		layer_id = line
	}
	'
}

##
# @brief Parse chains array from JSON
# @param $1 : JSON input string
# @return Prints chain data (tag1|tag2|tag3|tag4|tag5) pipe-separated per chain
# @tag @IMP4.3.10.2@ (FROM: @ARC4.1@)
_parse_json_chains() {
	_json="$1"

	# AWK-based JSON chains extraction
	# Output format: tag1|tag2|tag3|tag4|tag5 (one chain per line)
	printf '%s\n' "$_json" | awk '
		BEGIN {
			in_chains=0
		}

		/"chains": \[/ {
			in_chains=1
			next
		}

		in_chains && /^  \]/ {
			# End of chains array
			in_chains=0
			next
		}

		in_chains && /\["@/ {
			# Extract chain array elements
			# Example: ["@REQx.x@", "@ARCx.x@", "@IMPx.x@", "@UTx.x@", "NONE"],
			line = $0
			gsub(/^[[:space:]]*\[/, "", line)
			gsub(/\],?[[:space:]]*$/, "", line)
			gsub(/"/, "", line)
			gsub(/, /, "|", line)
			print line
		}
	'
}

##
# @brief Parse health section from JSON
# @param $1 : JSON input string
# @return Prints health statistics (total_tags, tags_with_links, isolated_tags, isolated_tag_list)
# @tag @IMP4.3.12@ (FROM: @ARC4.1@)
_parse_json_health() {
	_json="$1"

	# AWK-based JSON health extraction
	printf '%s\n' "$_json" | awk '
		BEGIN {
			in_files=0
			in_file_obj=0
			in_health=0
			in_isolated_list=0
			in_isolated_obj=0
			isolated_count=0
			in_dangling_list=0
			in_duplicate_list=0
		}

		# Parse top-level files array to map file_id -> file path
		/"files": \[/ {
			in_files=1
			next
		}

		in_files && /^  \],?/ {
			in_files=0
			next
		}

		in_files && /^    \{/ {
			in_file_obj=1
			file_id=""; file_path=""
			next
		}

		in_files && in_file_obj && /^    \},?/ {
			if (file_id != "") {
				file_map[file_id] = file_path
			}
			in_file_obj=0
			next
		}

		in_file_obj && /"file_id":/ {
		line = $0
		sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
			file_id = line
		}

		in_file_obj && /"file":/ {
		line = $0
		sub(/.*"file": *"/, "", line)
		sub(/".*$/, "", line)
			file_path = line
		}

		/"health": \{/ {
			in_health=1
			next
		}

		in_health && /^  \},?$/ {
			# End of health object
			in_health=0
			next
		}

		in_health && /"total_tags":/ {
		line = $0
		sub(/.*"total_tags": */, "", line)
		sub(/,.*$/, "", line)
			total_tags = line
			print "total_tags=" total_tags
		}

		in_health && /"tags_with_links":/ {
		line = $0
		sub(/.*"tags_with_links": */, "", line)
		sub(/,.*$/, "", line)
			tags_with_links = line
			print "tags_with_links=" tags_with_links
		}

		in_health && /"isolated_tags":/ {
		line = $0
		sub(/.*"isolated_tags": */, "", line)
		sub(/,.*$/, "", line)
			isolated_tags = line
			print "isolated_tags=" isolated_tags
		}

		in_health && /"duplicate_tags":/ {
		line = $0
		sub(/.*"duplicate_tags": */, "", line)
		sub(/,.*$/, "", line)
			duplicate_tags = line
			print "duplicate_tags=" duplicate_tags
		}

		in_health && /"isolated_tag_list": \[/ {
			in_isolated_list=1
			next
		}

		in_isolated_list && /^    \]/ {
			in_isolated_list=0
			next
		}

		in_health && /"duplicate_tag_list": \[/ {
			in_duplicate_list=1
			next
		}

		in_duplicate_list && /^    \]/ {
			in_duplicate_list=0
			next
		}

		# Parse single-line JSON objects in isolated_tag_list
		# Example: {"id": "@ARC1.3@", "file_id": 0, "line": 91},
		in_isolated_list && /\{"id":/ {
			iso_id=""; iso_file_id=""; iso_line=""

			# Extract id
		line = $0
		if (index(line, "\"id\"")) {
			sub(/.*"id": *"/, "", line)
			sub(/".*$/, "", line)
			iso_id = line
			}

			# Extract file_id
		line = $0
		if (index(line, "\"file_id\"")) {
			sub(/.*"file_id": */, "", line)
			sub(/,.*$/, "", line)
			iso_file_id = line
			}

			# Extract line
		line = $0
		if (index(line, "\"line\"")) {
			sub(/.*"line": */, "", line)
			sub(/[,}].*$/, "", line)
			iso_line = line
			}

			# Output immediately
			if (iso_id != "") {
				file_path_out = (iso_file_id in file_map) ? file_map[iso_file_id] : "unknown"
				print "isolated|" iso_id "|" file_path_out "|" iso_line
			}
		}

		# Parse single-line JSON objects in duplicate_tag_list
		# Example: {"id": "@TAG1@", "file_id": 0, "line": 1},
		in_duplicate_list && /\{"id":/ {
			dup_id=""; dup_file_id=""; dup_line=""

		line = $0
		if (index(line, "\"id\"")) {
			sub(/.*"id": *"/, "", line)
			sub(/".*$/, "", line)
			dup_id = line
			}

		line = $0
		if (index(line, "\"file_id\"")) {
			sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
			dup_file_id = line
			}

		line = $0
		if (index(line, "\"line\"")) {
			sub(/.*"line": */, "", line)
			sub(/[,}].*$/, "", line)
			dup_line = line
			}

			if (dup_id != "") {
				file_path_out = (dup_file_id in file_map) ? file_map[dup_file_id] : "unknown"
				print "duplicate|" dup_id "|" file_path_out "|" dup_line
			}
		}

		in_health && /"dangling_references":/ {
		line = $0
		sub(/.*"dangling_references": */, "", line)
		sub(/,.*$/, "", line)
			dangling_refs = line
			print "dangling_references=" dangling_refs
		}

		in_health && /"dangling_reference_list": \[/ {
			in_dangling_list=1
			next
		}

		in_dangling_list && /^    \]/ {
			in_dangling_list=0
			next
		}

		# Parse single-line JSON objects in dangling_reference_list
		# Example: {"child_tag": "@ARC1.1@", "missing_parent": "@REQ6.1@", "file_id": 1, "line": 64},
		in_dangling_list && /\{"child_tag":/ {
			dang_child=""; dang_parent=""; dang_file_id=""; dang_line=""

			# Extract child_tag
		line = $0
		if (index(line, "\"child_tag\"")) {
			sub(/.*"child_tag": *"/, "", line)
			sub(/".*$/, "", line)
			dang_child = line
			}

			# Extract missing_parent
		line = $0
		if (index(line, "\"missing_parent\"")) {
			sub(/.*"missing_parent": *"/, "", line)
			sub(/".*$/, "", line)
			dang_parent = line
			}

			# Extract file_id
		line = $0
		if (index(line, "\"file_id\"")) {
			sub(/.*"file_id": */, "", line)
			sub(/,.*$/, "", line)
			dang_file_id = line
			}

			# Extract line
		line = $0
		if (index(line, "\"line\"")) {
			sub(/.*"line": */, "", line)
			sub(/[,}].*$/, "", line)
			dang_line = line
			}

			# Output immediately
			if (dang_child != "" && dang_parent != "") {
				file_path_out = (dang_file_id in file_map) ? file_map[dang_file_id] : "unknown"
				print "dangling|" dang_child "|" dang_parent "|" file_path_out "|" dang_line
			}
		}
	'
}

##
# @brief Parse coverage data from JSON health section and top-level files array
# @param $1 : JSON input string
# @brief Parse coverage data from JSON (health.coverage.layers with nested files)
# @param $1 : JSON input string
# @return Prints coverage data in format: layer|total|up_count|down_count|up_pct|down_pct
#         AND file|layer|basename|total|up_count|down_count|up_pct|down_pct|version
# @tag @IMP4.3.11.1@ (FROM: @ARC4.1@)
_parse_json_coverage() {
	_json="$1"

	# AWK-based JSON coverage extraction
	printf '%s\n' "$_json" | awk '
		BEGIN {
			# Parse top-level files array first for file_id -> file mapping
			in_files=0
			in_file_entry=0
			in_coverage=0
			in_layers=0
			in_layer_obj=0
			in_upstream_obj=0
			in_downstream_obj=0
			in_layer_files=0
			in_file_obj=0
			in_file_upstream=0
			in_file_downstream=0
			current_layer_name=""
		}

		# Parse top-level files array
		/"files": \[/ && !in_coverage {
			in_files=1
			next
		}

		in_files && /^  \],?$/ {
			in_files=0
			next
		}

		in_files && /^    \{/ {
			in_file_entry=1
			file_id=""; file_path=""
			next
		}

		in_files && in_file_entry && /^    \},?$/ {
			if (file_id != "") {
				file_map[file_id] = file_path
			}
			in_file_entry=0
			next
		}

		in_file_entry && /"file_id":/ {
		line = $0
		sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
			file_id = line
		}

		in_file_entry && /"file":/ {
		line = $0
		sub(/.*"file": *"/, "", line)
		sub(/".*$/, "", line)
			file_path = line
		}

		# Parse coverage section
		/"coverage": \{/ {
			in_coverage=1
			next
		}

		in_coverage && /^    \}/ {
			# End of coverage object
			in_coverage=0
			next
		}

		in_coverage && /"layers": \[/ {
			in_layers=1
			next
		}

		in_layers && /^      \],?$/ {
			# End of layers array
			in_layers=0
			next
		}

		in_layers && /^        \{/ {
			# Start of layer object
			in_layer_obj=1
			name=""; total=""; up_count=""; down_count=""; up_pct=""; down_pct=""
			next
		}

		in_layers && in_layer_obj && /^        \},?$/ {
			# End of layer object - output
			if (name != "") {
				print "layer|" name "|" total "|" up_count "|" down_count "|" up_pct "|" down_pct
			}
			in_layer_obj=0
			current_layer_name=""
			next
		}

		in_layer_obj && /"name":/ {
		line = $0
		sub(/.*"name": *"/, "", line)
		sub(/".*$/, "", line)
			name = line
			current_layer_name = line
		}

		in_layer_obj && /"total":/ && !in_upstream_obj && !in_downstream_obj && !in_layer_files {
		line = $0
		sub(/.*"total": */, "", line)
		sub(/,.*$/, "", line)
			total = line
		}

		# Parse upstream object
		in_layer_obj && /"upstream": \{/ && !in_layer_files {
			in_upstream_obj=1
			next
		}

		in_upstream_obj && /^          \},?$/ {
			in_upstream_obj=0
			next
		}

		in_upstream_obj && /"count":/ {
		line = $0
		sub(/.*"count": */, "", line)
		sub(/,.*$/, "", line)
			up_count = line
		}

		in_upstream_obj && /"percent":/ {
		line = $0
		sub(/.*"percent": */, "", line)
		sub(/,.*$/, "", line)
			up_pct = line
		}

		# Parse downstream object
		in_layer_obj && /"downstream": \{/ && !in_layer_files {
			in_downstream_obj=1
			next
		}

		in_downstream_obj && /^          \},?$/ {
			in_downstream_obj=0
			next
		}

		in_downstream_obj && /"count":/ {
		line = $0
		sub(/.*"count": */, "", line)
		sub(/,.*$/, "", line)
			down_count = line
		}

		in_downstream_obj && /"percent":/ {
		line = $0
		sub(/.*"percent": */, "", line)
		sub(/,.*$/, "", line)
			down_pct = line
		}

		# Parse files array within layer
		in_layer_obj && /"files": \[/ {
			in_layer_files=1
			in_file_obj=0
			next
		}

		in_layer_files && /^          \],?$/ {
			# End of files array within layer
			in_layer_files=0
			next
		}

		in_layer_files && /^            \{/ {
			# Start of file object within layer
			in_file_obj=1
			file_id_local=""; file_total=""; file_up_count=""; file_down_count=""; file_up_pct=""; file_down_pct=""; version=""
			next
		}

		in_layer_files && in_file_obj && /^            \},?$/ {
			# End of file object - resolve file_id and output
			if (file_id_local != "") {
				file_path_resolved = (file_id_local in file_map) ? file_map[file_id_local] : "unknown"
				print "file|" current_layer_name "|" file_path_resolved "|" file_total "|" file_up_count "|" file_down_count "|" file_up_pct "|" file_down_pct "|" version
			}
			in_file_obj=0
			next
		}

		in_file_obj && /"file_id":/ {
		line = $0
		sub(/.*"file_id": */, "", line)
		sub(/,.*$/, "", line)
			file_id_local = line
		}

		in_file_obj && /"total":/ && !in_file_upstream && !in_file_downstream {
		line = $0
		sub(/.*"total": */, "", line)
		sub(/,.*$/, "", line)
			file_total = line
		}

		# Parse file-level upstream
		in_file_obj && /"upstream": \{/ {
			in_file_upstream=1
			next
		}

		in_file_upstream && /^              \},?$/ {
			in_file_upstream=0
			next
		}

		in_file_upstream && /"count":/ {
		line = $0
		sub(/.*"count": */, "", line)
		sub(/,.*$/, "", line)
			file_up_count = line
		}

		in_file_upstream && /"percent":/ {
		line = $0
		sub(/.*"percent": */, "", line)
		sub(/,.*$/, "", line)
			file_up_pct = line
		}

		# Parse file-level downstream
		in_file_obj && /"downstream": \{/ {
			in_file_downstream=1
			next
		}

		in_file_downstream && /^              \},?$/ {
			in_file_downstream=0
			next
		}

		in_file_downstream && /"count":/ {
		line = $0
		sub(/.*"count": */, "", line)
		sub(/,.*$/, "", line)
			file_down_count = line
		}

		in_file_downstream && /"percent":/ {
		line = $0
		sub(/.*"percent": */, "", line)
		sub(/,.*$/, "", line)
			file_down_pct = line
		}

		in_file_obj && /"version":/ {
			line = $0
			sub(/.*"version": *"/, "", line)
			sub(/".*$/, "", line)
			version = line
		}
	'
}

##
# @brief Parse links array from JSON
# @param $1 : JSON input string
# @return Prints link data (source|target|value) pipe-separated
# @tag @IMP4.3.11.2@ (FROM: @ARC4.1@)
_parse_json_links() {
	_json="$1"

	# AWK-based JSON links extraction
	# Output format: source|target|value (pipe-separated)
	printf '%s\n' "$_json" | awk '
		BEGIN {
			in_links=0
			in_link_obj=0
		}

		/"links": \[/ {
			in_links=1
			next
		}

		in_links && /^  \]/ {
			# End of links array
			in_links=0
			next
		}

		in_links && /^    \{/ {
			# Start of new link object
			in_link_obj=1
			link_source=""; link_target=""; link_value=""
			next
		}

		in_links && in_link_obj && /^    \},?$/ {
			# End of link object - output
			if (link_source != "" && link_target != "") {
				print link_source "|" link_target "|" link_value
			}
			in_link_obj=0
			next
		}

		in_link_obj && /"source":/ {
		line = $0
		sub(/.*"source": *"/, "", line)
		sub(/".*$/, "", line)
			link_source = line
		}

		in_link_obj && /"target":/ {
		line = $0
		sub(/.*"target": *"/, "", line)
		sub(/".*$/, "", line)
			link_target = line
		}

		in_link_obj && /"value":/ {
		line = $0
		sub(/.*"value": */, "", line)
		sub(/,.*$/, "", line)
			link_value = line
		}
	'
}

##
# @brief Extract layer order from layers array
# @param $1 : JSON input string
# @return Prints layer names in order, one per line
# @tag @IMP4.3.10.1@ (FROM: @ARC4.1@)
_extract_layer_order() {
	_json="$1"

	# Extract layers from top-level layers array in order
	printf '%s\n' "$_json" | awk '
	BEGIN {
		in_layers = 0
		in_layer_obj = 0
	}
	/"layers": \[/ && !in_layers {
		in_layers = 1
		next
	}
	in_layers && /^  \],?$/ {
		in_layers = 0
		exit
	}
	in_layers && /^    \{/ {
		in_layer_obj = 1
		next
	}
	in_layers && in_layer_obj && /^    \},?$/ {
		in_layer_obj = 0
		next
	}
	in_layer_obj && /"name":/ {
		# Extract layer name
		line = $0
		sub(/.*"name": *"/, "", line)
		sub(/".*$/, "", line)
		layer_name = line
		if (layer_name != "") {
			print layer_name
		}
	}
	'
}

##
# @brief Calculate upstream/downstream coverage for each file
# @param $1 : JSON input string
##
# @brief Main entry point - generates complete markdown report
# @tag @IMP4.3@ (FROM: @ARC4.1@)
shtracer_markdown_viewer_main() {
	# Read entire JSON from stdin
	_json_input=$(cat)

	# Validate JSON input
	if [ -z "$_json_input" ]; then
		printf 'Error: No JSON input received from stdin\n' >&2
		return 1
	fi

	# Generate all sections in order
	_generate_markdown_header "$_json_input"
	_generate_markdown_toc "$_json_input"
	_generate_markdown_summary "$_json_input"
	_generate_markdown_health "$_json_input"
	_generate_markdown_chains "$_json_input"
	_generate_markdown_cross_refs "$_json_input"
	_generate_markdown_tag_index "$_json_input"

	return 0
}

# Standalone execution vs sourcing pattern
case "$0" in
	*shtracer_markdown_viewer.sh | *shtracer_markdown_viewer)
		shtracer_markdown_viewer_main "$@"
		;;
	*)
		: # sourced for unit tests
		;;
esac
