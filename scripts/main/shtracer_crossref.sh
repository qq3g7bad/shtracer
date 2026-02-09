#!/bin/sh

# For unit test
_SHTRACER_CROSSREF_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*shtracer_crossref*)
		: # Successfully sourced (zsh sets $0 to sourced file).
		;;
	*)
		echo "This script should only be sourced, not executed directly."
		exit 1
		;;
esac

##
# @brief  Swap or rename tags across all trace target files
# @param  $1 : CONFIG_OUTPUT_DATA
# @param  $2 : BEFORE_TAG
# @param  $3 : AFTER_TAG
# @tag    @IMP2.6@ (FROM: @ARC2.4@)
swap_tags() {
	# Note: Using global escape_sed_pattern() and escape_sed_replacement()
	# functions from shtracer_util.sh instead of local definitions

	_list_target_files() {
		# $1: PATH (file or directory)
		# $2: extension regex (grep -E style), optional
		_target_path="$1"
		_ext_re="$2"
		if [ -f "$_target_path" ]; then
			printf '%s\n' "$_target_path"
			return 0
		fi
		if [ ! -d "$_target_path" ]; then
			return 0
		fi
		_ext_re=${_ext_re:-.*}
		find "$_target_path" -maxdepth 1 -type f -print 2>/dev/null \
			| while IFS= read -r _f; do
				_base=${_f##*/}
				printf '%s\n' "$_base" | grep -Eq "$_ext_re" || continue
				printf '%s\n' "$_f"
			done
	}

	if [ -e "$1" ]; then
		_ABSOLUTE_TAG_BASENAME="$(basename "$1")"
		_ABSOLUTE_TAG_DIRNAME="$(
			cd "$(dirname "$1")" || exit 1
			pwd
		)"
		_ABSOLUTE_TAG_PATH=${_ABSOLUTE_TAG_DIRNAME%/}/$_ABSOLUTE_TAG_BASENAME
	else
		error_exit 1 "swap_tags" "Cannot find a config output data."
		return
	fi

	(
		# Read config parse results (tag information are included in one line)
		_TARGET_DATA="$(cat "$_ABSOLUTE_TAG_PATH")"
		_TEMP_TAG="@SHTRACER___TEMP___TAG@"
		_TEMP_TAG="$(echo "$_TEMP_TAG" | sed 's/___/_/g')" # for preventing conversion

		_FILE_LIST="$(
			echo "$_TARGET_DATA" \
				| while read -r _DATA; do
					_PATH="$(extract_field_unquoted "$_DATA" 2 "$SHTRACER_SEPARATOR")"
					_EXTENSION="$(extract_field_unquoted "$_DATA" 3 "$SHTRACER_SEPARATOR")"
					cd "$CONFIG_DIR" || error_exit 1 "swap_tags" "Cannot change directory to config path"
					_list_target_files "$_PATH" "$_EXTENSION"
				done
		)"

		(
			cd "$CONFIG_DIR" || error_exit 1 "swap_tags" "Cannot change directory to config path"
			_before_pat="$(escape_sed_pattern "$2")"
			_after_pat="$(escape_sed_pattern "$3")"
			_tmp_pat="$(escape_sed_pattern "$_TEMP_TAG")"
			_before_rep="$(escape_sed_replacement "$2")"
			_after_rep="$(escape_sed_replacement "$3")"
			_tmp_rep="$(escape_sed_replacement "$_TEMP_TAG")"
			echo "$_FILE_LIST" \
				| sort -u \
				| while IFS= read -r t; do
					[ -n "$t" ] || continue
					_tmp_file="$(shtracer_tmpfile)" || exit 1
					sed \
						-e "s|${_before_pat}|${_tmp_rep}|g" \
						-e "s|${_after_pat}|${_before_rep}|g" \
						-e "s|${_tmp_pat}|${_after_rep}|g" \
						"$t" >"$_tmp_file" || {
						rm -f "$_tmp_file"
						exit 1
					}
					cat "$_tmp_file" >"$t" || {
						rm -f "$_tmp_file"
						exit 1
					}
					rm -f "$_tmp_file"
				done
		)
	)
}

##
# ============================================================================
# Cross-Reference Table Generation (Intermediate Files + Markdown/HTML)
# ============================================================================
##

##
# @brief   Extract traceability layer hierarchy from config table
# @param   $1 : 01_config_table file path
# @return  Echoes unique layer info (one per line: "identifier<tab>tag_format")
# @example _extract_layer_hierarchy "01_config_table" returns:
#          Requirement	@REQ[0-9\.]+@
#          Architecture	@ARC[0-9\.]+@
# @tag     @IMP2.7.3@ (FROM: @ARC2.7@)
_extract_layer_hierarchy() {
	_config_table="$1"

	if [ ! -r "$_config_table" ]; then
		return 1
	fi

	# Extract layer identifiers and TAG FORMAT from config table
	# Field 1: Section header (e.g., ":Requirement" or ":Main scripts:Implementation")
	# Field 6: TAG FORMAT (e.g., `@REQ[0-9\.]+@`)
	awk -F "$SHTRACER_SEPARATOR" '
	NF >= 6 {
		section_header = $1
		tag_format = $6

		# Skip if TAG FORMAT is empty
		if (tag_format == "") next

		# Remove surrounding backticks and quotes from tag_format
		gsub(/^`|`$|^"|"$/, "", tag_format)

		# Extract layer identifier from section header
		# Remove leading colon and use last segment for identifier
		gsub(/^:/, "", section_header)

		# Split by ":" and use the last non-empty segment
		n = split(section_header, segments, ":")
		identifier = ""
		for (i = n; i >= 1; i--) {
			if (segments[i] != "") {
				identifier = segments[i]
				break
			}
		}

		# Create unique key from tag_format to avoid duplicates
		if (identifier != "" && !seen[tag_format]++) {
			printf "%s\t%s\n", identifier, tag_format
		}
	}
	' "$_config_table"
}

##
# @brief   Generate a single cross-reference matrix intermediate file
# @param   $1 : 01_tags file path
# @param   $2 : 02_tag_pairs file path
# @param   $3 : Row tag pattern (TAG FORMAT regex, e.g., "@REQ[0-9\.]+@")
# @param   $4 : Column tag pattern (TAG FORMAT regex, e.g., "@ARC[0-9\.]+@")
# @param   $5 : Output file path
# @return  0 on success, 1 on error
# @tag     @IMP2.7.2@ (FROM: @ARC2.7@)
_generate_cross_reference_matrix() {
	_tags_file="$1"
	_tag_pairs_file="$2"
	_row_pattern="$3"
	_col_pattern="$4"
	_output_file="$5"

	if [ ! -r "$_tags_file" ] || [ ! -r "$_tag_pairs_file" ]; then
		return 1
	fi

	# Generate timestamp
	_timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')

	# Convert \. to . in patterns to avoid awk warnings on Windows
	# Inside character classes like [0-9\.], the dot is not a metacharacter
	_row_pattern=$(printf '%s' "$_row_pattern" | sed 's/\\[.]/./g')
	_col_pattern=$(printf '%s' "$_col_pattern" | sed 's/\\[.]/./g')

	# Use AWK to process both files and generate intermediate format
	awk -v row_pattern="$_row_pattern" -v col_pattern="$_col_pattern" \
		-v timestamp="$_timestamp" -v sep="$SHTRACER_SEPARATOR" \
		-v tags_sep="$SHTRACER_SEPARATOR" '
	BEGIN {
		row_count = 0
		col_count = 0
		matrix_count = 0
	}

	# First pass: Read 01_tags to build tag metadata
	# Field separator for this file is <shtracer_separator>
	ARGIND == 1 {
		# Manually split by separator
		n = split($0, fields, tags_sep)
		if (n >= 6) {
			tag_id = fields[2]
			file_path = fields[5]
			line_num = fields[6]

			# Store tag metadata
			tag_file[tag_id] = file_path
			tag_line[tag_id] = line_num

			# Collect row and column tags based on TAG FORMAT regex match
			if (tag_id ~ row_pattern) {
				if (!row_seen[tag_id]++) {
					rows[row_count++] = tag_id
				}
			}
			if (tag_id ~ col_pattern) {
				if (!col_seen[tag_id]++) {
					cols[col_count++] = tag_id
				}
			}
		}
	}

	# Second pass: Read 02_tag_pairs to build matrix
	# Field separator for this file is space
	ARGIND == 2 && NF >= 2 {
		# Space-separated: @REQ1.1@ @ARC2.1@
		parent_tag = $1
		child_tag = $2

		# Check if this pair matches our row/col patterns using regex
		parent_is_row = 0
		child_is_col = 0

		# Check if parent_tag matches row_pattern
		if (parent_tag ~ row_pattern) {
			parent_is_row = 1
		}

		# Check if child_tag matches col_pattern
		if (child_tag ~ col_pattern) {
			child_is_col = 1
		}

		# Store matrix entry if both match
		if (parent_is_row && child_is_col) {
			matrix_key = parent_tag sep child_tag
			if (!matrix_seen[matrix_key]++) {
				matrix[matrix_count++] = matrix_key
			}
		}
	}

	END {
		# Output intermediate file format

		# [METADATA]
		print "[METADATA]"
		print row_pattern sep col_pattern sep timestamp

		# [ROW_TAGS]
		print ""
		print "[ROW_TAGS]"
		for (i = 0; i < row_count; i++) {
			tag = rows[i]
			file = tag_file[tag]
			line = tag_line[tag]
			if (file == "") file = "unknown"
			if (line == "") line = "0"
			print tag sep file sep line
		}

		# [COL_TAGS]
		print ""
		print "[COL_TAGS]"
		for (i = 0; i < col_count; i++) {
			tag = cols[i]
			file = tag_file[tag]
			line = tag_line[tag]
			if (file == "") file = "unknown"
			if (line == "") line = "0"
			print tag sep file sep line
		}

		# [MATRIX]
		print ""
		print "[MATRIX]"
		for (i = 0; i < matrix_count; i++) {
			print matrix[i]
		}
	}
	' "$_tags_file" "$_tag_pairs_file" >"$_output_file"

	return 0
}

##
# @brief   Generate cross-reference matrix intermediate files for all adjacent levels
# @param   $1 : 01_config_table file path
# @param   $2 : 01_tags file path
# @param   $3 : 02_tag_pairs file path
# @return  Echoes cross-reference output directory
# @tag     @IMP2.7.1@ (FROM: @ARC2.7@)
make_cross_reference_tables() {
	_config_table="$1"
	_tags_file="$2"
	_tag_pairs_file="$3"

	if [ ! -r "$_config_table" ] || [ ! -r "$_tags_file" ] || [ ! -r "$_tag_pairs_file" ]; then
		echo "[shtracer][error][make_cross_reference_tables]: Cannot read input files for cross-reference generation" >&2
		return 1
	fi

	_xref_output_dir="${OUTPUT_DIR%/}/tags/"

	# Extract layer hierarchy dynamically from config table (preserves config.md order)
	_layer_hierarchy=$(_extract_layer_hierarchy "$_config_table")

	if [ -z "$_layer_hierarchy" ]; then
		echo "[shtracer][warn][make_cross_reference_tables]: No traceability layers found in tags" >&2
		echo "$_xref_output_dir"
		return 0
	fi

	# Generate intermediate files for each adjacent level pair
	_file_num=6 # Start from 06 (after 01-05 are used for other files)
	_prev_identifier=""
	_prev_format=""

	# Process each layer (identifier<tab>tag_format)
	# Use temporary file to avoid subshell and preserve variable updates
	_layer_tmp="${OUTPUT_DIR%/}/layer_hierarchy.tmp"
	printf '%s\n' "$_layer_hierarchy" >"$_layer_tmp"

	while IFS="$(printf '\t')" read -r _current_identifier _current_format; do
		if [ -n "$_prev_identifier" ] && [ -n "$_prev_format" ]; then
			# Convert layer identifiers to filename-safe format (spaces to underscores)
			_prev_id_safe=$(printf '%s' "$_prev_identifier" | tr ' ' '_')
			_current_id_safe=$(printf '%s' "$_current_identifier" | tr ' ' '_')

			# Generate matrix for adjacent pair: prev_layer → current_layer
			_output_file="${_xref_output_dir}$(printf '%02d' $_file_num)_cross_ref_matrix_${_prev_id_safe}_${_current_id_safe}"

			if ! _generate_cross_reference_matrix "$_tags_file" "$_tag_pairs_file" \
				"$_prev_format" "$_current_format" "$_output_file"; then
				echo "[shtracer][warn][make_cross_reference_tables]: Failed to generate $_prev_identifier vs $_current_identifier matrix" >&2
			fi

			_file_num=$((_file_num + 1))
		fi
		_prev_identifier="$_current_identifier"
		_prev_format="$_current_format"
	done <"$_layer_tmp"

	rm -f "$_layer_tmp"

	echo "$_xref_output_dir"
	return 0
}

##
# @brief   Generate a single Markdown table from intermediate matrix file
# @param   $1 : Intermediate matrix file path
# @param   $2 : Config file path (for relative path calculation)
# @param   $3 : Output markdown file path
# @return  0 on success, 1 on error
# @tag     @IMP2.7.5@ (FROM: @ARC2.7@)
_generate_markdown_table() {
	_matrix_file="$1"
	_config_file="$2"
	_output_md="$3"

	if [ ! -r "$_matrix_file" ]; then
		return 1
	fi

	# Get absolute path of output directory for relative path calculation
	_output_dir=$(cd "$(dirname "$_output_md")" && pwd)

	# Use AWK to parse intermediate file and generate Markdown
	awk -v sep="<shtracer_separator>" -v output_dir="$_output_dir" '
	# Compute relative path in AWK
	function compute_relative_path(from_dir, to_file,    common, from_parts, to_parts, from_count, to_count, i, j, up_count, result) {
		# Normalize paths
		gsub(/\/$/, "", from_dir)
		gsub(/\/$/, "", to_file)

		# Split paths into parts
		from_count = split(from_dir, from_parts, "/")
		to_count = split(to_file, to_parts, "/")

		# Find common prefix
		common = 0
		for (i = 1; i <= from_count && i <= to_count; i++) {
			if (from_parts[i] == to_parts[i]) {
				common = i
			} else {
				break
			}
		}

		# Count how many levels to go up
		up_count = from_count - common

		# Build relative path
		result = ""
		for (i = 0; i < up_count; i++) {
			result = result "../"
		}

		# Add remaining path from to_file
		for (i = common + 1; i <= to_count; i++) {
			if (i > common + 1) result = result "/"
			result = result to_parts[i]
		}

		return result
	}

	BEGIN {
		section = ""
		row_count = 0
		col_count = 0
		matrix_count = 0
		row_label = ""
		col_label = ""
	}

	# Parse sections
	/^\[METADATA\]/ { section = "metadata"; next }
	/^\[ROW_TAGS\]/ { section = "row_tags"; next }
	/^\[COL_TAGS\]/ { section = "col_tags"; next }
	/^\[MATRIX\]/ { section = "matrix"; next }
	/^[[:space:]]*$/ { next }

	section == "metadata" {
		split($0, meta, sep)
		row_label = meta[1]
		col_label = meta[2]
		timestamp = meta[3]
	}

	section == "row_tags" {
		split($0, fields, sep)
		tag = fields[1]
		file = fields[2]
		line = fields[3]
		rows[row_count] = tag
		row_file[tag] = file
		row_line[tag] = line

		# Compute relative path
		if (file != "unknown") {
			row_rel_path[tag] = compute_relative_path(output_dir, file)
		} else {
			row_rel_path[tag] = file
		}
		row_count++
	}

	section == "col_tags" {
		split($0, fields, sep)
		tag = fields[1]
		file = fields[2]
		line = fields[3]
		cols[col_count] = tag
		col_file[tag] = file
		col_line[tag] = line

		# Compute relative path
		if (file != "unknown") {
			col_rel_path[tag] = compute_relative_path(output_dir, file)
		} else {
			col_rel_path[tag] = file
		}
		col_count++
	}

	section == "matrix" {
		split($0, fields, sep)
		row_tag = fields[1]
		col_tag = fields[2]
		matrix[row_tag, col_tag] = 1
		matrix_count++
	}

	END {
		# Generate Markdown output

		# Title
		printf "# Cross-Reference Table: %s vs %s\n\n", row_label, col_label

		# Legend
		print "**Legend**:"
		printf "- Row headers: %s tags\n", row_label
		printf "- Column headers: %s tags\n", col_label
		print "- `x` indicates a traceability link exists"
		print "- Click tag IDs to navigate to source location"
		print ""
		printf "Generated: %s\n\n", timestamp
		print "---"
		print ""

		# Build table header
		# First column: "."
		printf "."
		# Column headers with hyperlinks
		for (i = 0; i < col_count; i++) {
			if (col_rel_path[cols[i]] != "unknown") {
				printf " | [%s](%s#L%s)", cols[i], col_rel_path[cols[i]], col_line[cols[i]]
			} else {
				printf " | %s", cols[i]
			}
		}
		printf "\n"

		# Separator row
		printf "---"
		for (i = 0; i < col_count; i++) {
			printf " | ---"
		}
		printf "\n"

		# Data rows
		isolated_count = 0
		for (i = 0; i < row_count; i++) {
			row = rows[i]
			has_link = 0

			# Row header with hyperlink
			if (row_rel_path[row] != "unknown") {
				printf "[%s](%s#L%s)", row, row_rel_path[row], row_line[row]
			} else {
				printf "%s", row
			}

			# Cells
			for (j = 0; j < col_count; j++) {
				col = cols[j]
				if (matrix[row, col] == 1) {
					printf " | x"
					has_link = 1
				} else {
					printf " |  "
				}
			}
			printf "\n"

			if (!has_link) isolated_count++
		}

		# Statistics footer
		print ""
		print "---"
		print ""
		print "**Statistics**:"
		printf "- Total %s tags: %d\n", row_label, row_count
		printf "- Total %s tags: %d\n", col_label, col_count
		printf "- Total links: %d\n", matrix_count

		# Calculate coverage (% of column tags that have at least one link)
		col_with_links = 0
		for (j = 0; j < col_count; j++) {
			col = cols[j]
			for (i = 0; i < row_count; i++) {
				row = rows[i]
				if (matrix[row, col] == 1) {
					col_with_links++
					break
				}
			}
		}
		if (col_count > 0) {
			coverage = (col_with_links * 100.0) / col_count
			printf "- Coverage: %.1f%% (%d/%d %s tags have upstream links)\n", \
				coverage, col_with_links, col_count, col_label
		}

		if (isolated_count > 0) {
			printf "- Isolated %s tags: %d (no links)\n", row_label, isolated_count
		}
	}
	' "$_matrix_file" >"$_output_md"

	return 0
}

##
# @brief   Generate Markdown cross-reference tables from all intermediate files
# @param   $1 : Tags output directory (contains *_cross_ref_matrix_* files)
# @param   $2 : Config file path (for relative path calculation)
# @return  Echoes markdown output directory
# @tag     @IMP2.7.4@ (FROM: @ARC2.7@)
markdown_cross_reference() {
	_tags_dir="$1"
	_config_path="$2"

	if [ ! -d "$_tags_dir" ]; then
		echo "[shtracer][error][markdown_cross_reference]: Tags directory not found: $_tags_dir" >&2
		return 1
	fi

	_md_output_dir="${OUTPUT_DIR%/}/cross_reference/"
	mkdir -p "$_md_output_dir" || {
		echo "[shtracer][error][markdown_cross_reference]: Failed to create output directory: $_md_output_dir" >&2
		return 1
	}

	# Find all cross-reference matrix intermediate files
	_matrix_files=$(find "$_tags_dir" -maxdepth 1 -type f -name '*_cross_ref_matrix_*' 2>/dev/null | sort)

	if [ -z "$_matrix_files" ]; then
		echo "[shtracer][warn][markdown_cross_reference]: No cross-reference matrix files found" >&2
		echo "$_md_output_dir"
		return 0
	fi

	# Generate markdown for each matrix file
	_file_num=1
	for _matrix_file in $_matrix_files; do
		# Extract layer names from filename
		# Format: NN_cross_ref_matrix_LAYER1_LAYER2
		_basename=$(basename "$_matrix_file")
		_layer_pair=$(echo "$_basename" | sed 's/^[0-9]*_cross_ref_matrix_//')

		# Generate output filename
		_output_md="${_md_output_dir}$(printf '%02d' $_file_num)_${_layer_pair}.md"

		# Generate markdown table
		if ! _generate_markdown_table "$_matrix_file" "$_config_path" "$_output_md"; then
			echo "[shtracer][warn][markdown_cross_reference]: Failed to generate markdown for $_layer_pair" >&2
		fi

		_file_num=$((_file_num + 1))
	done

	echo "$_md_output_dir"
	return 0
}
