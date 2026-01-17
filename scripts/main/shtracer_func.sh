#!/bin/sh

# For unit test
_SHTRACER_FUNC_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*)
		echo "This script should only be sourced, not executed directly."
		exit 1
		;;
esac

##
# @brief   Remove comments from config markdown file
# @param   $1 : CONFIG_MARKDOWN_PATH
# @return  Echoes cleaned config content to stdout
_check_config_remove_comments() {
	_CONFIG_MARKDOWN_PATH="$1"

	# Delete comment blocks from the configuration markdown file
	# Using refactored helper functions for better maintainability
	remove_markdown_comments "$_CONFIG_MARKDOWN_PATH" \
		| remove_empty_lines \
		| remove_leading_bullets \
		| remove_trailing_whitespace \
		| convert_markdown_bold
}

##
# @brief   Convert cleaned config content to table format
# @param   $1 : Cleaned config content (from _check_config_remove_comments)
# @param   $2 : Output file path
# @return  None (writes to $2)
_check_config_convert_to_table() {
	_CONFIG_CONTENT="$1"
	_CONFIG_TABLE="$2"

	# Convert sections to lines
	echo "$_CONFIG_CONTENT" \
		| sed 's/:/'"$SHTRACER_SEPARATOR"'/;
					s/[[:space:]]*'"$SHTRACER_SEPARATOR"'[[:space:]]*/'"$SHTRACER_SEPARATOR"'/' \
		| awk -F "$SHTRACER_SEPARATOR" -v separator="$SHTRACER_SEPARATOR" '\
			function print_data() {
				print \
					a["TITLE"],
					a["PATH"],
					a["EXTENSION FILTER"],
					a["IGNORE FILTER"],
					a["BRIEF"],
					a["TAG FORMAT"],
					a["TAG LINE FORMAT"],
					a["TAG-TITLE OFFSET"];
			}

			BEGIN {
				precount = 1; count = 1;
				OFS = separator
			}

			# Set Markdown title hierarchy by separating with ":"
			# e.g. title = Heading1:Heading1.1:Heading1.1.1
			/^#/ {
				match($0, /^#+/)
				gsub(/^#+ */, "", $0)
				t[RLENGTH] = $0
				title="";
				for (i=2;i<=RLENGTH;i++){
					title = sprintf("%s:%s", title, t[i])
				}
			}

			$0 ~ ("^PATH" separator) {
				if (a["TITLE"] != "") {
					print_data()
				}
				for(i in a){a[i]=""}
				a["TITLE"]=title
			}

			{
				a[$1]=$2
			}

			END {
				print_data()
			}
		' >"$_CONFIG_TABLE"
}

##
# @brief  Parse config markdown file and convert to tab-separated table format
# @param  $1 : CONFIG_MARKDOWN_PATH
# @return CONFIG_OUTPUT_DATA
# @tag    @IMP2.1@ (FROM: @ARC2.1@)
check_configfile() {
	(
		profile_start "check_configfile"
		# Prepare the output directory and filenames
		_CONFIG_OUTPUT_DIR="${OUTPUT_DIR%/}/config/"
		_CONFIG_TABLE="${_CONFIG_OUTPUT_DIR%/}/01_config_table"

		mkdir -p "$_CONFIG_OUTPUT_DIR"

		# Remove comments from config markdown file
		_CONFIG_FILE_WITHOUT_COMMENT="$(_check_config_remove_comments "$1")"

		# Convert cleaned content to table format
		_check_config_convert_to_table "$_CONFIG_FILE_WITHOUT_COMMENT" "$_CONFIG_TABLE"

		# echo the output file location
		echo "$_CONFIG_TABLE"
		profile_end "check_configfile"
	)
}

##
# @brief   Validate config file and return absolute path
# @param   $1 : CONFIG_OUTPUT_DATA path (may be relative)
# @return  Echoes absolute path to stdout
# @exit    Calls error_exit if file doesn't exist
_extract_tags_validate_input() {
	if [ -e "$1" ]; then
		_ABSOLUTE_TAG_BASENAME="$(basename "$1")"
		_ABSOLUTE_TAG_DIRNAME="$(
			cd "$(dirname "$1")" || exit 1
			pwd
		)"
		_ABSOLUTE_TAG_PATH="${_ABSOLUTE_TAG_DIRNAME%/}/$_ABSOLUTE_TAG_BASENAME"
		echo "$_ABSOLUTE_TAG_PATH"
	else
		error_exit 1 "extract_tags" "Cannot find a config output data."
		return
	fi
}

##
# @brief   Parse config and discover target files
# @param   $1 : Absolute path to config file
# @return  Echoes separator-delimited file list to stdout (sorted, unique)
_extract_tags_discover_files() {
	awk <"$1" -F "$SHTRACER_SEPARATOR" -v separator="$SHTRACER_SEPARATOR" '
		function extract_from_doublequote(string) {
			sub(/^[[:space:]]*/, "", string)
			sub(/[[:space:]]*$/, "", string)
			if (string ~ /".*"/) {
				string = substr(string, index(string, "\"") + 1);
				string = substr(string, 1, length(string) - 1);
			}
			return string
		}
		function extract_from_backtick(string) {
			sub(/^[[:space:]]*/, "", string)
			sub(/[[:space:]]*$/, "", string)
			if (string ~ /`.*`/) {
				string = substr(string, index(string, "`") + 1);
				string = substr(string, 1, length(string) - 1);
			}
			return string
		}
		BEGIN {
			OFS=separator
		}
		{
			title = $1;
			path = extract_from_doublequote($2);
			extension = extract_from_doublequote($3);
			ignore = extract_from_doublequote($4);
			brief = $5;
			tag_format = extract_from_backtick($6)
			tag_line_format = extract_from_backtick($7)
			tag_title_offset = $8 == "" ? 1 : $8
			if (tag_title_offset + 0 < 0) { tag_title_offset = 0 }

			if (tag_format == "") { next }

			cmd = "test -f \""path"\"; echo $?"; cmd | getline is_file_exist; close(cmd);
			if (is_file_exist == 0) {
				print title, path, extension, ignore, brief, tag_format, tag_line_format, tag_title_offset
			}
			else {
				# for multiple extension filter
				n = split(extension, ext_arr, "|")
				ext_expr = ""
				for (i = 1; i <= n; i++) {
					if (i > 1) {
						ext_expr = ext_expr " -o"
					}
					ext_expr = ext_expr " -name \"" ext_arr[i] "\""
				}

				if (ignore != "") {
					split(ignore, ignore_exts, "|");
					ignore_ext_str = "";
					for (i in ignore_exts) {
						if (ignore_ext_str != "") {
							ignore_ext_str = ignore_ext_str " -o ";
						}
						ignore_ext_str = ignore_ext_str "-name \"" ignore_exts[i] "\"";
					}
					cmd = "find \"" path "\" \\( "ignore_ext_str" \\) -prune -o \\( -type f " ext_expr " \\) -print";
				}
				else {
					cmd = "find \"" path "\" -type f " ext_expr ""
				}
				while ((cmd | getline path) > 0) { print title, path, extension, ignore, brief, tag_format, tag_line_format, tag_title_offset; } close(cmd);
			}
		}' | sort -u
}

##
# @brief   Extract tags from files and write to output
# @param   $1 : File list from _extract_tags_discover_files
# @param   $2 : Output file path
# @return  None (writes to file)
_extract_tags_process_files() {
	_FROM_TAG_START="FROM:"
	_FROM_TAG_REGEX="\(""$_FROM_TAG_START"".*\)"

	# Process each discovered file to extract tags and associated information
	# AWK: Parse config line by line, read each target file, extract tags with context
	# Process:
	#   1. Parse config fields (title, path, tag format, offset)
	#   3. Scan file line by line:
	#      - When tag pattern matches: extract tag ID and FROM tags
	#      - Count down from TAG_TITLE_OFFSET to find associated title
	#      - Capture file path and line number for reference
	# Output: Multi-column data (trace target, tag, from_tag, title, abs_path, line_num, file_num)
	echo "$1" \
		| awk -F "$SHTRACER_SEPARATOR" -v separator="$SHTRACER_SEPARATOR" -v util_script="$SCRIPT_DIR/scripts/main/shtracer_util.sh" '
			{
				title = $1
				path = $2
				tag_format = $6
				tag_line_format = $7
				tag_title_offset = ($8 == "" ? 1 : $8)
				if (tag_title_offset + 0 < 0) { tag_title_offset = 0 }

				# Calculate absolute path once per file (optimization for Windows/Git Bash)
				filename = path; gsub(".*/", "", filename);
				dirname = path; gsub("/[^/]*$", "", dirname)
				if (dirname == "") dirname = "."
				cmd = "cd \""dirname"\" 2>/dev/null && pwd";
				if ((cmd | getline absolute_path) > 0) {
					close(cmd)
					absolute_file_path = absolute_path "/" filename
				} else {
					close(cmd)
					# Fallback if cd fails
					absolute_file_path = path
				}


				# Get version info for this file (cache to avoid repeated calls)
				if (absolute_file_path in file_version_cache) {
					file_version = file_version_cache[absolute_file_path]
				} else {
					cmd = ". \"" util_script "\" && get_file_version_info \"" absolute_file_path "\""
					if ((cmd | getline file_version) > 0) {
						close(cmd)
						file_version_cache[absolute_file_path] = file_version
					} else {
						close(cmd)
						file_version = "unknown"
						file_version_cache[absolute_file_path] = file_version
					}
				}
				line_num = 0
				counter = -1
				while (getline line < path > 0) {
					line_num++

					# 1) Print tag column
					if (line ~ tag_format && line ~ tag_line_format) {
						counter=tag_title_offset;
						printf("%s%s", title, separator)                       # column 1: trace target

						match(line, tag_format)
						tag=substr(line, RSTART, RLENGTH)
						printf("%s%s", tag, separator)                         # column 2: tag

						match(line, /'"$_FROM_TAG_REGEX"'/)
						if (RSTART == 0) {                                     # no from tag
							from_tag="'"$NODATA_STRING"'"
						}
						else{
							from_tag=substr(line, RSTART+1, RLENGTH-2)
							sub(/'"$_FROM_TAG_START"'/, "", from_tag)
							sub(/^[[:space:]]*/, "", from_tag)
							sub(/[[:space:]]$/, "", from_tag)
						}
						printf("%s%s", from_tag, separator)                    # column 3: from tag
					}

					# 2) Print the offset line
					if (counter == 0) {
						sub(/^#+[[:space:]]*/, "", line)
						printf("%s%s", line, separator)                        # column 4: title
						printf("%s%s", absolute_file_path, separator)          # column 5: file absolute path
						printf("%s%s", line_num, separator)                    # column 6: line number including title
						printf("%s%s", NR, separator)                          # column 7: file num
						printf("%s\n", file_version)                          # column 8: file version
					}
					if (counter >= 0) {
						counter--;
					}

				}
				close(path)
			}
			' >"$2"
}

##
# @brief  Extract traceability tags and their relationships from all target files
# @param  $1 : CONFIG_OUTPUT_DATA
# @return TAG_OUTPUT_DATA
# @tag    @IMP2.2@ (FROM: @ARC2.2@)
extract_tags() {
	profile_start "extract_tags"

	# Validate input and get absolute path
	if [ -e "$1" ]; then
		_ABSOLUTE_TAG_BASENAME="$(basename "$1")"
		_ABSOLUTE_TAG_DIRNAME="$(
			cd "$(dirname "$1")" || exit 1
			pwd
		)"
		_ABSOLUTE_TAG_PATH="${_ABSOLUTE_TAG_DIRNAME%/}/$_ABSOLUTE_TAG_BASENAME"
	else
		error_exit 1 "extract_tags" "Cannot find a config output data."
		return
	fi

	(
		_TAG_OUTPUT_DIR="${OUTPUT_DIR%/}/tags/"
		_TAG_OUTPUT_LEVEL1="${_TAG_OUTPUT_DIR%/}/01_tags"

		mkdir -p "$_TAG_OUTPUT_DIR"
		cd "$CONFIG_DIR" || error_exit 1 "extract_tags" "Cannot change directory to config path"

		# Discover target files from config
		_FILES="$(_extract_tags_discover_files "$_ABSOLUTE_TAG_PATH")"

		# Extract tags from discovered files
		_extract_tags_process_files "$_FILES" "$_TAG_OUTPUT_LEVEL1"

		# Return output location
		echo "$_TAG_OUTPUT_LEVEL1"
		profile_end "extract_tags"
	)
}

##
# @brief   Prepare upstream tag table (starting points with no parents)
# @param   $1 : TAG_PAIRS file path
# @param   $2 : Output file path for TAG_TABLE
# @return  None (writes to file)
_prepare_upstream_table() {
	# Extract tags that have NODATA_STRING as parent (starting points)
	# Pipeline: grep for NONE tags → sort → remove NONE field → trim → remove empty lines
	grep "^$NODATA_STRING" "$1" \
		| sort -u \
		| awk '{$1=""; print $0}' \
		| sed 's/^[[:space:]]*//' \
		| sed '/^$/d' >"$2"
}

##
# @brief   Prepare downstream tag table (tags with parents)
# @param   $1 : TAG_PAIRS file path
# @param   $2 : Output file path for TAG_PAIRS_DOWNSTREAM
# @return  None (writes to file)
_prepare_downstream_table() {
	# Extract tags that have actual parents (not NONE)
	# Pipeline: grep -v to exclude NONE tags → sort → remove empty lines
	grep -v "^$NODATA_STRING" "$1" \
		| sort -u \
		| sed '/^$/d' >"$2"
}

##
# @brief   Verify and detect duplicated tags
# @param   $1 : TAG_OUTPUT_DATA file path
# @param   $2 : Output file path for duplicates
# @return  None (writes to file)
_verify_duplicated_tags() {
	# Extract all tag IDs, sort them, and find duplicates
	# AWK: Extract tag field ($2) → sort → uniq -d finds duplicates
	awk <"$1" \
		-F"$SHTRACER_SEPARATOR" \
		'{
			print $2
		 }' \
		| sort \
		| uniq -d >"$2"
}

##
# @brief   Verify and detect dangling FROM tag references (references to non-existent tags)
# @param   $1 : TAG_OUTPUT_DATA file path (01_tag_extracted_all)
# @param   $2 : Output file path for dangling references
# @return  None (writes to file with format: child_tag parent_tag file line)
_verify_dangling_fromtags() {
	# Create temporary files for tracking valid tags and references
	_valid_tags="$(shtracer_tmpfile)" || return 1
	_all_references="$(shtracer_tmpfile)" || return 1

	# Step 1: Extract all valid tag IDs (field 2) and sort them
	awk -F"$SHTRACER_SEPARATOR" '{print $2}' "$1" | sort -u >"$_valid_tags"

	# Step 2: Extract all FROM tag references (field 3, comma-separated)
	# Output format: child_tag parent_tag file line
	awk -F"$SHTRACER_SEPARATOR" '{
		tag_id = $2
		from_tags = $3
		file = $5
		line = $6

		# Remove leading/trailing whitespace from from_tags field
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", from_tags)

		# Split comma-separated FROM tags
		n = split(from_tags, arr, /[[:space:]]*,[[:space:]]*/)
		for (i = 1; i <= n; i++) {
			parent = arr[i]
			# Skip NONE and empty strings
			if (parent != "'"$NODATA_STRING"'" && parent != "") {
				print tag_id " " parent " " file " " line
			}
		}
	}' "$1" >"$_all_references"

	# Step 3: Check each parent reference against valid tags
	# Output dangling references to result file
	while read -r _child _parent _file _line; do
		if ! grep -qxF "$_parent" "$_valid_tags"; then
			printf "%s %s %s %s\n" "$_child" "$_parent" "$_file" "$_line"
		fi
	done <"$_all_references" >"$2"

	# Clean up temporary files
	rm -f "$_valid_tags" "$_all_references"
}

##
# @brief   Detect isolated tags (tags with no connections at all)
# @param   $1 : TAG_PAIRS file path
# @param   $2 : TAG_OUTPUT_DATA file path (all tags)
# @param   $3 : Output file path for isolated tags
# @return  None (writes to file)
_detect_isolated_tags() {
	# Get all tags that appear in tag pairs (both columns, excluding NONE)
	# A tag is isolated only if it has NO connections (not in FROM or TO column)
	_connected_tags="$(shtracer_tmpfile)" || return 1
	_all_tags="$(shtracer_tmpfile)" || return 1

	awk <"$1" '{
		if ($1 != "'"$NODATA_STRING"'") print $1
		if ($2 != "'"$NODATA_STRING"'") print $2
	}' | sort -u >"$_connected_tags"

	# Get all tags from tag extraction (second column is tag ID)
	awk <"$2" -F"$SHTRACER_SEPARATOR" '{print $2}' | sort -u >"$_all_tags"

	# Output tags NOT in connected_tags (truly isolated tags)
	# comm -23: lines only in file1 (all_tags) not in file2 (connected_tags)
	comm -23 "$_all_tags" "$_connected_tags" \
		| sed 's/^/'"$NODATA_STRING"' /' >"$3"

	rm -f "$_connected_tags" "$_all_tags"
}

##
# @brief Create file version aggregation table
# @param $1 : TAG_OUTPUT_DATA (01_tags with 8 columns)
# @param $2 : Output file path (05_file_versions)
# @return Creates file with format: trace_target<SEP>file_path<SEP>version_info
create_file_versions_table() {
	_TAGS_FILE="$1"
	_OUTPUT="$2"

	if [ ! -r "$_TAGS_FILE" ]; then
		error_exit 1 "create_file_versions_table" "Cannot read tags file: $_TAGS_FILE"
	fi

	# Extract unique combinations of trace_target, file_path, and version
	awk -F"$SHTRACER_SEPARATOR" -v SEP="$SHTRACER_SEPARATOR" '
	NF >= 8 {
		trace_target = $1
		file_path = $5
		version = $8

		# Create unique key
		key = trace_target SEP file_path

		if (!(key in seen)) {
			seen[key] = 1
			versions[key] = version
		}
	}
	END {
		for (key in versions) {
			print key SEP versions[key]
		}
	}
	' "$_TAGS_FILE" | sort >"$_OUTPUT"
}
##
# @brief  Create tag relationship pairs and build complete traceability matrix
# @param  $1 : TAG_OUTPUT_DATA
# @return TAG_MATRIX
# @tag    @IMP2.3@ (FROM: @ARC2.2@)
make_tag_table() {
	if [ ! -r "$1" ] || [ $# -ne 1 ]; then
		error_exit 1 "make_tag_table" "incorrect argument."
	fi

	(
		_TAG_OUTPUT_DIR="${OUTPUT_DIR%/}/tags/"
		_TAG_OUTPUT_VERIFIED_DIR="${_TAG_OUTPUT_DIR%/}/verified/"
		_TAG_PAIRS="${_TAG_OUTPUT_DIR%/}/02_tag_pairs"
		_TAG_PAIRS_DOWNSTREAM="${_TAG_OUTPUT_DIR%/}/03_tag_pairs_downstream"
		_TAG_TABLE="${_TAG_OUTPUT_DIR%/}/04_tag_table"
		_ISOLATED_FROM_TAG="${_TAG_OUTPUT_VERIFIED_DIR%/}/10_isolated_fromtag"
		_TAG_TABLE_DUPLICATED="${_TAG_OUTPUT_VERIFIED_DIR%/}/11_duplicated"
		_TAG_TABLE_DANGLING="${_TAG_OUTPUT_VERIFIED_DIR%/}/12_dangling_fromtag"

		mkdir -p "$_TAG_OUTPUT_DIR"
		mkdir -p "$_TAG_OUTPUT_VERIFIED_DIR"

		# Parse tag relationships into pairs
		# AWK: Split FROM tags (field $3, comma-separated) and pair with TO tag (field $2)
		# Input: TAG_ID <sep> FROM_TAG1,FROM_TAG2 <sep> ...
		# Output: FROM_TAG1 TAG_ID\nFROM_TAG2 TAG_ID (space-separated pairs)
		awk <"$1" \
			-F"$SHTRACER_SEPARATOR" \
			'{
				# OFS="'"$SHTRACER_SEPARATOR"'"
				split($3, parent, /[ ]*,[ ]*/);
				for (i=1; i<=length(parent); i++){
					print(parent[i], $2);
				}
		}' \
			| awk '!seen[$0]++' >"$_TAG_PAIRS"

		# Prepare upstream and downstream tables

		# Create file version aggregation table (05_file_versions)
		_FILE_VERSIONS="${_TAG_OUTPUT_DIR%/}/05_file_versions"
		create_file_versions_table "$1" "$_FILE_VERSIONS"
		_prepare_upstream_table "$_TAG_PAIRS" "$_TAG_TABLE"
		_prepare_downstream_table "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM"

		# Make joined tag table (each row has a single trace tag chain)
		if [ "$(wc -l <"$_TAG_PAIRS_DOWNSTREAM")" -ge 1 ]; then
			if ! join_tag_pairs "$_TAG_TABLE" "$_TAG_PAIRS_DOWNSTREAM"; then
				error_exit 1 "make_tag_table" "Error in join_tag_pairs"
			fi
		else
			error_exit 1 "make_tag_table" "No linked tags found."
		fi
		sort -k1,1 <"$_TAG_TABLE" >"$_TAG_TABLE"TMP
		mv "$_TAG_TABLE"TMP "$_TAG_TABLE"

		# Verify tag integrity (duplicates, isolated tags, and dangling references)
		_verify_duplicated_tags "$1" "$_TAG_TABLE_DUPLICATED"
		_verify_dangling_fromtags "$1" "$_TAG_TABLE_DANGLING"
		_detect_isolated_tags "$_TAG_PAIRS" "$1" "$_ISOLATED_FROM_TAG"

		echo "$_TAG_TABLE$SHTRACER_SEPARATOR$_ISOLATED_FROM_TAG$SHTRACER_SEPARATOR$_TAG_TABLE_DUPLICATED$SHTRACER_SEPARATOR$_TAG_TABLE_DANGLING"
	)
}

##
# @brief  Recursively join tag pairs to build complete traceability chains
# @param  $1 : filename of the tag table
# @param  $2 : filename of tag pairs without starting points
# @param  $3 : (optional) current recursion depth (default: 0)
# @tag    @IMP2.4@ (FROM: @ARC2.3@)
join_tag_pairs() {
	(
		if [ ! -r "$1" ] || [ ! -r "$2" ]; then
			error_exit 1 "join_tag_pairs" "Incorrect argument."
		fi

		if [ $# -lt 2 ] || [ $# -gt 3 ]; then
			error_exit 1 "join_tag_pairs" "Incorrect argument."
		fi

		_TAG_TABLE="$1"
		_TAG_TABLE_DOWNSTREAM="$2"
		_DEPTH="${3:-0}"
		_MAX_DEPTH=100

		# Check for circular reference by depth limit
		if [ "$_DEPTH" -ge "$_MAX_DEPTH" ]; then
			error_exit 1 "join_tag_pairs" "Circular reference detected: Maximum recursion depth ($_MAX_DEPTH) exceeded. Please check your tag relationships for cycles (e.g., A -> B -> A)."
		fi

		_NF="$(count_fields "$_TAG_TABLE" " ")"
		_NF_PLUS1="$((_NF + 1))"

		if ! _JOINED_TMP="$(join -1 "$_NF" -2 1 -a 1 "$_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM")"; then
			error_exit 1 "join_tag_pairs" "Error in join command"
		fi

		_JOINED_TMP="$(echo "$_JOINED_TMP" \
			| awk '{if($'"$_NF_PLUS1"'=="") $'"$_NF_PLUS1"'="'"$NODATA_STRING"'"; print}' \
			| awk '{for (i=2; i<=(NF-1); i++){printf("%s ", $i)}; printf("%s %s\n", $1, $NF)}' \
			| sort -k$_NF_PLUS1,$_NF_PLUS1)"

		_IS_LAST="$(echo "$_JOINED_TMP" \
			| awk '{if($NF != "'"$NODATA_STRING"'"){a=1}}END{if(a==1){print 0}else{print 1}}')"

		if [ "$_IS_LAST" -eq 1 ]; then
			return
		else
			echo "$_JOINED_TMP" >"$_TAG_TABLE"
			_NEXT_DEPTH=$((_DEPTH + 1))
			join_tag_pairs "$_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM" "$_NEXT_DEPTH"
		fi
	)
}

##
# @brief  Print traceability summary based on direct links only (02_tag_pairs)
# @param  $1 : TAG_OUTPUT_DATA path (01_tags)
# @param  $2 : TAG_PAIRS path (02_tag_pairs)
# @return  Prints summary lines to stdout
print_summary_direct_links() {
	if [ $# -ne 3 ] || [ ! -r "$1" ] || [ ! -r "$2" ] || [ ! -r "$3" ]; then
		error_exit 1 "print_summary_direct_links" "incorrect argument."
	fi

	_TAGS_FILE="$1"
	_TAG_PAIRS_FILE="$2"
	_FILE_VERSIONS_FILE="$3"

	# Output format:
	#   <layer>
	#     upstream: <target layer> <pct>, ...
	#     downstream: <target layer> <pct>, ...
	# Notes:
	# - Uses direct links only.
	# - Treats links as undirected.
	# - Computes upstream/downstream projections independently (relative to layer order).
	# - For nodes connected to multiple target layers on a side, split 1 equally across distinct target layers.
	# - Percent formatting matches the Type diagram labels.
	awk \
		-v SEP="$SHTRACER_SEPARATOR" \
		-v TAGS_FILE="$_TAGS_FILE" \
		-v VERSIONS_FILE="$_FILE_VERSIONS_FILE" \
		'
		function trim(s) {
			gsub(/^[[:space:]]+/, "", s)
			gsub(/[[:space:]]+$/, "", s)
			return s
		}
		function layer_suffix(s,   n, a, t) {
			n = split(s, a, ":")
			t = a[n]
			return trim(t)
		}
		function fmt_pct(value, total,   p, s) {
			if (total <= 0) { return "" }
			p = (value / total) * 100
			if (p > 0 && p < 0.5) { return "<1%" }
			if (p >= 10) { s = sprintf("%.0f", p) }
			else { s = sprintf("%.1f", p) }
			sub(/[.]0$/, "", s)
			return s "%"
		}
		BEGIN {
			# First pass: load tag->layer from 01_tags
			while ((getline line < TAGS_FILE) > 0) {
				n = split(line, f, SEP)
				if (n < 2) { continue }
				tag = trim(f[2])
				if (tag == "" || tag == "NONE") { continue }
				layer = layer_suffix(f[1])
				if (layer == "") { continue }
				if (!(tag in tag2layer)) {
					tag2layer[tag] = layer
					layerN[layer]++
					layers[layer] = 1
				}
			}
			close(TAGS_FILE)

	# Load file versions and track unique files per layer
	while ((getline line < VERSIONS_FILE) > 0) {
		n = split(line, f, SEP)
		if (n < 3) { continue }
		trace_target = trim(f[1])
		file_path = trim(f[2])
		version = trim(f[3])
		key = trace_target SEP file_path
		file_versions[key] = version

		# Track unique files per layer
		layer = layer_suffix(trace_target)
		if (layer != "") {
			file_key = layer SEP file_path
			if (!(file_key in layer_files_seen)) {
				layer_files_seen[file_key] = 1
				idx = layer_file_count[layer]++
				layer_files[layer, idx] = file_path
				layer_trace_targets[layer, idx] = trace_target
			}
		}
	}
	close(VERSIONS_FILE)

			# Preferred stable order
			order[1] = "Requirement"
			order[2] = "Architecture"
			order[3] = "Implementation"
			order[4] = "Unit test"
			order[5] = "Integration test"
			for (i = 1; i <= 5; i++) {
				ord[order[i]] = i
			}
		}
		{
			# Second pass (main input): 02_tag_pairs (space separated)
			tagA = $1
			tagB = $2
			if (tagA == "" || tagB == "") { next }
			if (tagA == "NONE" || tagB == "NONE") { next }
			if (!(tagA in tag2layer) || !(tagB in tag2layer)) { next }
			la = tag2layer[tagA]
			lb = tag2layer[tagB]
			if (la == "" || lb == "") { next }
			if (la == lb) { next }
			if (!(la in ord) || !(lb in ord)) { next }

			# Undirected, but categorize per endpoint as upstream/downstream by layer order.
			# Endpoint A
			if (ord[lb] < ord[la]) {
				k = tagA SUBSEP lb
				if (!(k in hasUp)) { hasUp[k] = 1; upcnt[tagA]++ }
			} else if (ord[lb] > ord[la]) {
				k = tagA SUBSEP lb
				if (!(k in hasDown)) { hasDown[k] = 1; downcnt[tagA]++ }
			}
			# Endpoint B
			if (ord[la] < ord[lb]) {
				k = tagB SUBSEP la
				if (!(k in hasUp)) { hasUp[k] = 1; upcnt[tagB]++ }
			} else if (ord[la] > ord[lb]) {
				k = tagB SUBSEP la
				if (!(k in hasDown)) { hasDown[k] = 1; downcnt[tagB]++ }
			}
		}
		END {
			# Accumulate split-mass per layer side (up/down) and target layer
			for (k in hasUp) {
				split(k, parts, SUBSEP)
				tag = parts[1]
				tgt = parts[2]
				src = tag2layer[tag]
				if (src == "" || tgt == "") { continue }
				if (upcnt[tag] <= 0) { continue }
				accUp[src SUBSEP tgt] += (1.0 / upcnt[tag])
				hasAccUp[src SUBSEP tgt] = 1
			}
			for (k in hasDown) {
				split(k, parts, SUBSEP)
				tag = parts[1]
				tgt = parts[2]
				src = tag2layer[tag]
				if (src == "" || tgt == "") { continue }
				if (downcnt[tag] <= 0) { continue }
				accDown[src SUBSEP tgt] += (1.0 / downcnt[tag])
				hasAccDown[src SUBSEP tgt] = 1
			}

			# Emit summary per layer (no totals). Upstream and downstream in stable order.
			for (i = 1; i <= 5; i++) {
				src = order[i]
				N = layerN[src] + 0
				if (N <= 0) { continue }

				# Determine if this layer has any upstream/downstream targets
				hasLine = 0
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j >= i) { continue }
					if ((src SUBSEP tgt) in hasAccUp) { hasLine = 1 }
				}
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j <= i) { continue }
					if ((src SUBSEP tgt) in hasAccDown) { hasLine = 1 }
				}
				if (!hasLine) { continue }

				print src

				# Display file information for this layer
				if (layer_file_count[src] > 0) {
					print "  files:"
					for (file_idx = 0; file_idx < layer_file_count[src]; file_idx++) {
						file_path = layer_files[src, file_idx]
						trace_target = layer_trace_targets[src, file_idx]
						# Get basename for display
						n_slash = split(file_path, path_parts, "/")
						file_name = path_parts[n_slash]

						# Get version info
						key = trace_target SEP file_path
						version_raw = file_versions[key]

						# Format version for display
						if (version_raw ~ /^git:/) {
							version_display = substr(version_raw, 5)  # Remove "git:" prefix
						} else if (version_raw ~ /^mtime:/) {
							# Convert "mtime:2025-12-26T10:30:45Z" to "2025-12-26 10:30"
							timestamp = substr(version_raw, 7)  # Remove "mtime:" prefix
							sub(/T/, " ", timestamp)
							sub(/:[0-9][0-9]Z$/, "", timestamp)
							version_display = timestamp
						} else {
							version_display = version_raw
						}

						printf "    - %s (%s)\n", file_name, version_display
					}
				}

				# upstream: reverse order (closest previous layer first visually)
				upStr = ""
				for (j = 5; j >= 1; j--) {
					tgt = order[j]
					if (j >= i) { continue }
					key = src SUBSEP tgt
					if (!(key in hasAccUp)) { continue }
					part = tgt " " fmt_pct(accUp[key] + 0, N)
					if (upStr == "") upStr = part
					else upStr = upStr ", " part
				}
				if (upStr != "") {
					print "  upstream: " upStr
				}

				# downstream: forward order
				downStr = ""
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j <= i) { continue }
					key = src SUBSEP tgt
					if (!(key in hasAccDown)) { continue }
					part = tgt " " fmt_pct(accDown[key] + 0, N)
					if (downStr == "") downStr = part
					else downStr = downStr ", " part
				}
				if (downStr != "") {
					print "  downstream: " downStr
				}
			}
		}
		' <"$_TAG_PAIRS_FILE"
}

##
# @brief  Display tag verification results (isolated, duplicated, and dangling tags)
# @param  $1 : filenames of verification output
# @return 0-7 based on which issues are found (bitmask: 1=isolated, 2=duplicate, 4=dangling)
# @tag    @IMP2.5@ (FROM: @ARC2.5@)
print_verification_result() {
	_TAG_TABLE_ISOLATED="$(extract_field "$1" 1 "$SHTRACER_SEPARATOR")"
	_TAG_TABLE_DUPLICATED="$(extract_field "$1" 2 "$SHTRACER_SEPARATOR")"
	_TAG_TABLE_DANGLING="$(extract_field "$1" 3 "$SHTRACER_SEPARATOR")"

	_has_isolated="0"
	_has_duplicated="0"
	_has_dangling="0"

	if [ "$(wc <"$_TAG_TABLE_ISOLATED" -l)" -ne 0 ] && [ "$(cat "$_TAG_TABLE_ISOLATED")" != "$NODATA_STRING" ]; then
		printf "[shtracer][error][print_verification_result]: Following tags are isolated\n" 1>&2
		cat <"$_TAG_TABLE_ISOLATED" 1>&2
		_has_isolated="1"
	fi
	if [ "$(wc <"$_TAG_TABLE_DUPLICATED" -l)" -ne 0 ]; then
		printf "[shtracer][error][print_verification_result]: Following tags are duplicated\n" 1>&2
		cat <"$_TAG_TABLE_DUPLICATED" 1>&2
		_has_duplicated="1"
	fi
	if [ "$(wc <"$_TAG_TABLE_DANGLING" -l)" -ne 0 ]; then
		printf "[shtracer][error][print_verification_result]: Following tags have non-existent FROM tags\n" 1>&2
		printf "Format: child_tag dangling_parent_tag file line\n" 1>&2
		cat <"$_TAG_TABLE_DANGLING" 1>&2
		_has_dangling="1"
	fi

	# Return specific codes using bitmask:
	# 0 = no issues
	# 1 = isolated tags only
	# 2 = duplicate tags only
	# 3 = isolated + duplicate
	# 4 = dangling only
	# 5 = isolated + dangling
	# 6 = duplicate + dangling
	# 7 = all three issues
	_code=0
	if [ "$_has_isolated" = "1" ]; then
		_code=$((_code + 1))
	fi
	if [ "$_has_duplicated" = "1" ]; then
		_code=$((_code + 2))
	fi
	if [ "$_has_dangling" = "1" ]; then
		_code=$((_code + 4))
	fi

	return "$_code"
}

##
# @brief  Generate JSON output for traceability data
# @param  $1 : TAG_OUTPUT_DATA (01_tags file path)
# @param  $2 : TAG_PAIRS (02_tag_pairs file path)
# @param  $3 : TAG_PAIRS_DOWNSTREAM (03_tag_pairs_downstream file path)
# @param  $4 : TAG_TABLE (04_tag_table file path)
# @param  $5 : CONFIG_TABLE (01_config_table file path)
# @param  $6 : CONFIG_PATH (config file path)
# @param  $7 : XREF_DIR (cross-reference directory path, optional)
# @return JSON_OUTPUT_FILENAME
make_json() {
	_TAG_OUTPUT_DATA="$1"
	_TAG_PAIRS="$2"
	_TAG_PAIRS_DOWNSTREAM="$3"
	_TAG_TABLE="$4"
	_CONFIG_TABLE="$5"
	_CONFIG_PATH="$6"
	_XREF_DIR="${7:-}"

	_JSON_OUTPUT_FILENAME="${OUTPUT_DIR%/}/output.json"

	# Generate timestamp
	_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

	# Start JSON structure
	{
		printf '{\n'
		printf '  "metadata": {\n'
		printf '    "version": "%s",\n' "$SHTRACER_VERSION"
		printf '    "generated": "%s",\n' "$_TIMESTAMP"
		printf '    "config_path": "%s"\n' "$_CONFIG_PATH"
		printf '  },\n'

		# NEW: Generate files array and layers array first, then collect stats
		# This requires reading all data upfront in one AWK pass

		# Calculate all data (files, layers, trace_tags, health) in one AWK pass
		awk -v tag_output_data="$_TAG_OUTPUT_DATA" \
			-v tag_pairs="$_TAG_PAIRS" \
			-v tag_pairs_downstream="$_TAG_PAIRS_DOWNSTREAM" \
			-v config_table="$_CONFIG_TABLE" \
			-v sep="$SHTRACER_SEPARATOR" \
			-v output_dir="${OUTPUT_DIR%/}" '
	# JSON escape function (defined outside BEGIN for use throughout)
	function json_escape(s,   result) {
		result = s
		gsub(/\\/, "\\\\", result)
		gsub(/"/, "\\\"", result)
		gsub(/\n/, "\\n", result)
		gsub(/\r/, "\\r", result)
		gsub(/\t/, "\\t", result)
		return result
	}

BEGIN {
	# STEP 1: Read layer order AND patterns from config table
	n_layers = 0
	while ((getline line < config_table) > 0) {
		split(line, fields, sep)
		if (length(fields) >= 6 && fields[1] != "") {
			# Extract layer name: last component after last colon
			layer = fields[1]
			sub(/^:/, "", layer)
			sub(/.*:/, "", layer)

			# Extract TAG FORMAT pattern (field 6)
			tag_pattern = fields[6]
			gsub(/^`|`$|^"|"$/, "", tag_pattern)  # Remove backticks/quotes

			# Record layer order and pattern (skip duplicates)
			if (layer != "" && tag_pattern != "" && !(layer in layer_order)) {
				layer_order[layer] = n_layers
				layer_pattern[layer] = tag_pattern
				ordered_layers[n_layers] = layer
				n_layers++
			}
		}
	}
	close(config_table)

		# STEP 2: Read all tags AND build global file mapping
		global_file_id = 0
		while ((getline line < tag_output_data) > 0) {
			split(line, fields, sep)
			if (length(fields) >= 8) {
				tag_id = fields[2]
				all_tags[tag_id] = 1
				tag_from[tag_id] = fields[3]  # NEW: Store from_tag
				tag_desc[tag_id] = fields[4]
				tag_file[tag_id] = fields[5]
				tag_line[tag_id] = fields[6]
				tag_target[tag_id] = fields[1]
				tag_version[tag_id] = fields[8]
				total_tags++

				# Build global file mapping (use full path to avoid basename collisions)
				file_path = fields[5]
				n_slash = split(file_path, path_parts, "/")
				basename = path_parts[n_slash]

				if (!(file_path in file_mapping)) {
					file_mapping[file_path] = global_file_id
					file_id_to_path[global_file_id] = file_path
					file_id_to_version[global_file_id] = fields[8]
					global_file_id++
				}
			}
		}
		close(tag_output_data)

			# STEP 3: Build layer-to-files relationship
			for (tag in all_tags) {
				target = tag_target[tag]
				# Extract layer from target (remove leading ":", take last segment)
				layer = target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)

				file_path = tag_file[tag]
				file_id = file_mapping[file_path]

				# Add to layer_files mapping (unique)
				key = layer SUBSEP file_id
				if (!(key in layer_has_file)) {
					layer_has_file[key] = 1
					if (layer_files[layer] == "") {
						layer_files[layer] = file_id
					} else {
						layer_files[layer] = layer_files[layer] "," file_id
					}
				}
			}

			# Read tags with links (source tags from pairs)
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE" && fields[2] != "NONE") {
					tags_with_links[fields[1]] = 1
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE" && fields[2] != "NONE") {
					tags_with_links[fields[1]] = 1
				}
			}
			close(tag_pairs_downstream)

			# Read dangling FROM tag references (file format: child_tag parent_tag file line)
			dangling_file = output_dir "/tags/verified/12_dangling_fromtag"
			dangling_count = 0
			while ((getline line < dangling_file) > 0) {
				split(line, fields, " ")
				if (length(fields) >= 4) {
					dangling_child[dangling_count] = fields[1]
					dangling_parent[dangling_count] = fields[2]
					dangling_file_path[dangling_count] = fields[3]
					dangling_line[dangling_count] = fields[4]
					dangling_count++
				}
			}
			close(dangling_file)

			# Count tags with links
			tags_with_links_count = 0
			for (tag in tags_with_links) {
				tags_with_links_count++
			}

			# Calculate isolated tags
			isolated_count = 0
			for (tag in all_tags) {
				if (!(tag in tags_with_links)) {
					isolated_tags[isolated_count++] = tag
				}
			}

			# Build tag-to-layer mapping
			for (tag in all_tags) {
				trace_target = tag_target[tag]
				# Extract layer name (last component after colon)
				layer = trace_target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)
				tag_to_layer[tag] = layer

				# Track full file path (needed for unique IDs)
				file_path = tag_file[tag]
				tag_to_file[tag] = file_path
			}

			# Build directed reference tracking
			# Tag pair format: "src tgt" means "tgt references src" (tgt has FROM: src)
			# references[tag] = tags this tag references (outgoing: this tag -> other tags)
			# referenced_by[tag] = tags that reference this tag (incoming: other tags -> this tag)

			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					# tgt references src (tgt has FROM: src)
					# So: tgt -> src (outgoing from tgt)
					#     src <- tgt (incoming to src)

					# Add to tgt references list (tgt references src)
					if (references[tgt] == "") {
						references[tgt] = src
					} else {
						if (index(references[tgt], src) == 0) {
							references[tgt] = references[tgt] ";" src
						}
					}

					# Add to src referenced_by list (src is referenced by tgt)
					if (referenced_by[src] == "") {
						referenced_by[src] = tgt
					} else {
						if (index(referenced_by[src], tgt) == 0) {
							referenced_by[src] = referenced_by[src] ";" tgt
						}
					}
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					# tgt references src (same semantics as above)

					# Add to tgt references list (avoid duplicates)
					if (references[tgt] == "") {
						references[tgt] = src
					} else {
						if (index(references[tgt], src) == 0) {
							references[tgt] = references[tgt] ";" src
						}
					}

					# Add to src referenced_by list (avoid duplicates)
					if (referenced_by[src] == "") {
						referenced_by[src] = tgt
					} else {
						if (index(referenced_by[src], tgt) == 0) {
							referenced_by[src] = referenced_by[src] ";" tgt
						}
					}
				}
			}
			close(tag_pairs_downstream)

			# Calculate coverage for each tag
			for (tag in all_tags) {
				layer = tag_to_layer[tag]
				file_path = tag_to_file[tag]
				n_slash = split(file_path, path_parts, "/")
				file_basename = path_parts[n_slash]

				# Skip if layer not in order or if config.md
				if (!(layer in layer_order) || file_basename == "config.md") continue

				my_order = layer_order[layer]

				# Count nodes per layer
				layer_total[layer]++

				# Count nodes per file (use full path as key to avoid collisions)
				file_key = layer "|" file_path
				file_total[file_key]++

				# Store version on first encounter
				if (file_version[file_key] == "") {
					file_version[file_key] = tag_version[tag]
				}

				# Find connected layers for this tag
				up_layers_str = ""
				down_layers_str = ""
				has_up = 0
				has_down = 0

				# Upstream coverage: tags in earlier layers that I reference
				# (I have FROM: pointing to them)
				if (references[tag] != "") {
					n_refs = split(references[tag], ref_arr, ";")
					for (j = 1; j <= n_refs; j++) {
						ref_tag = ref_arr[j]
						ref_layer = tag_to_layer[ref_tag]

						if (ref_layer == "" || ref_layer == layer) continue
						if (!(ref_layer in layer_order)) continue

						ref_order = layer_order[ref_layer]

						# Only count if reference is to an earlier layer
						if (ref_order < my_order) {
							has_up = 1
							if (index(up_layers_str, ref_layer) == 0) {
								up_layers_str = up_layers_str (up_layers_str ? "," : "") ref_layer
							}
						}
					}
				}

				# Downstream coverage: tags in later layers that reference me
				# (later tags have FROM: pointing to me)
				if (referenced_by[tag] != "") {
					n_refby = split(referenced_by[tag], refby_arr, ";")
					for (j = 1; j <= n_refby; j++) {
						refby_tag = refby_arr[j]
						refby_layer = tag_to_layer[refby_tag]

						if (refby_layer == "" || refby_layer == layer) continue
						if (!(refby_layer in layer_order)) continue

						refby_order = layer_order[refby_layer]

						# Only count if referencer is in a later layer
						if (refby_order > my_order) {
							has_down = 1
							if (index(down_layers_str, refby_layer) == 0) {
								down_layers_str = down_layers_str (down_layers_str ? "," : "") refby_layer
							}
						}
					}
				}

				# Track upstream/downstream connections for layers
				if (up_layers_str != "") {
					n_up = split(up_layers_str, up_arr, ",")
					layer_up_count[layer]++

					# Track connected target layers
					for (k = 1; k <= n_up; k++) {
						target_layer = up_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_up_targets)) {
							layer_up_targets[key] = 1
						}
					}
				}

				if (down_layers_str != "") {
					n_down = split(down_layers_str, down_arr, ",")
					layer_down_count[layer]++

					# Track connected target layers
					for (k = 1; k <= n_down; k++) {
						target_layer = down_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_down_targets)) {
							layer_down_targets[key] = 1
						}
					}
				}

				# Count files with upstream/downstream connections
				if (has_up) file_up[file_key] = (file_up[file_key] + 0) + 1
				if (has_down) file_down[file_key] = (file_down[file_key] + 0) + 1
		}

		# STEP 4: Output files array (top-level, globally unique file_id)
		printf "  \"files\": [\n"
		for (fid = 0; fid < global_file_id; fid++) {
			if (fid > 0) printf ",\n"
			printf "    {\n"
			printf "      \"file_id\": %d,\n", fid
			printf "      \"file\": \"%s\",\n", json_escape(file_id_to_path[fid])
			printf "      \"version\": \"%s\"\n", json_escape(file_id_to_version[fid])
			printf "    }"
		}
		printf "\n  ],\n"

		# STEP 5: Output layers array
		printf "  \"layers\": [\n"
		layer_id = 0
		layer_printed = 0
		for (layer_idx = 0; layer_idx < n_layers; layer_idx++) {
			layer = ordered_layers[layer_idx]
			if (!(layer in layer_total)) continue

			total = layer_total[layer]

			# Build upstream_layers array
			up_layers_arr = ""
			for (j = 0; j < n_layers; j++) {
				target = ordered_layers[j]
				key = layer SUBSEP target
				if (key in layer_up_targets) {
					if (up_layers_arr != "") up_layers_arr = up_layers_arr ", "
					up_layers_arr = up_layers_arr "\"" target "\""
				}
			}

			# Build downstream_layers array
			down_layers_arr = ""
			for (j = 0; j < n_layers; j++) {
				target = ordered_layers[j]
				key = layer SUBSEP target
				if (key in layer_down_targets) {
					if (down_layers_arr != "") down_layers_arr = down_layers_arr ", "
					down_layers_arr = down_layers_arr "\"" target "\""
				}
			}

			if (layer_printed) printf ",\n"
			layer_printed = 1

			printf "    {\n"
			printf "      \"layer_id\": %d,\n", layer_id
			printf "      \"name\": \"%s\",\n", json_escape(layer)
			printf "      \"pattern\": \"%s\",\n", json_escape(layer_pattern[layer])

			# Output file_ids array
			printf "      \"file_ids\": ["
			if (layer_files[layer] != "") {
				n_fids = split(layer_files[layer], fids, ",")
				for (fid_idx = 1; fid_idx <= n_fids; fid_idx++) {
					if (fid_idx > 1) printf ", "
					printf "%d", fids[fid_idx]
				}
			}
			printf "],\n"

			printf "      \"total_tags\": %d,\n", total
			printf "      \"upstream_layers\": [%s],\n", up_layers_arr
			printf "      \"downstream_layers\": [%s]\n", down_layers_arr
			printf "    }"

			layer_id++
		}
		printf "\n  ],\n"

		# Write file mapping to temp file for trace_tags generation
		mapping_file = output_dir "/file_mapping.tmp"
		for (file_path in file_mapping) {
			print file_path "|" file_mapping[file_path] > mapping_file
		}
		close(mapping_file)

		# Also write layer_order mapping for trace_tags
		layer_mapping_file = output_dir "/layer_mapping.tmp"
		for (layer in layer_order) {
			print layer "|" layer_order[layer] > layer_mapping_file
		}
		close(layer_mapping_file)
}'

		# STEP 6: Generate trace_tags array (renamed from nodes, with from_tag field)
		_FILE_MAPPING_TEMP="${OUTPUT_DIR%/}/file_mapping.tmp"
		_LAYER_MAPPING_TEMP="${OUTPUT_DIR%/}/layer_mapping.tmp"
		printf '  "trace_tags": [\n'
		awk -F"$SHTRACER_SEPARATOR" -v file_mapping="$_FILE_MAPPING_TEMP" -v layer_mapping="$_LAYER_MAPPING_TEMP" '
BEGIN {
	first=1
	# Load file path to global file_id mapping
	while ((getline line < file_mapping) > 0) {
		split(line, parts, "|")
		# parts[1] = file path, parts[2] = global file_id
		file_to_id[parts[1]] = parts[2]
	}
	close(file_mapping)

	# Load layer to layer_id mapping
	while ((getline line < layer_mapping) > 0) {
		split(line, parts, "|")
		# parts[1] = layer name, parts[2] = layer_id
		layer_to_id[parts[1]] = parts[2]
	}
	close(layer_mapping)
}
NF >= 8 {
	# Look up global file_id from mapping using full path
	file_path = $5
	file_id = file_to_id[file_path]
	if (file_id == "") file_id = -1

	# Extract layer from trace_target (field 1)
	target = $1
	sub(/^:/, "", target)
	sub(/.*:/, "", target)
	layer_id = layer_to_id[target]
	if (layer_id == "") layer_id = -1

	# Normalize upstream tags into an array (handles comma/semicolon/space separated lists)
	raw_from = $3
	gsub(/^ +| +$/, "", raw_from)
	gsub(/[;,]/, " ", raw_from)
	from_tags_json = "[]"

	if (raw_from != "" && raw_from != "NONE" && raw_from != "null") {
		n_from = split(raw_from, from_arr, /[ \t]+/)
		from_tags_json = "["
		sep = ""
		for (i = 1; i <= n_from; i++) {
			tag = from_arr[i]
			if (tag == "" || tag == "NONE" || tag == "null") continue
			from_tags_json = from_tags_json sep "\"" tag "\""
			sep = ", "
		}
		from_tags_json = from_tags_json "]"
	}

	# Escape quotes and backslashes in description
	desc = $4
	gsub(/\\/, "\\\\", desc)
	gsub(/"/, "\\\"", desc)
	gsub(/\015/, "\\r", desc)  # \r (CR)
	gsub(/\012/, "\\n", desc)  # \n (LF)
	gsub(/\011/, "\\t", desc)  # \t (TAB)

	if (!first) printf ",\n"
	first=0

	printf "    {\n"
	printf "      \"id\": \"%s\",\n", $2
	printf "      \"from_tags\": %s,\n", from_tags_json
	printf "      \"description\": \"%s\",\n", desc
	printf "      \"file_id\": %d,\n", file_id
	printf "      \"line\": %d,\n", $6
	printf "      \"layer_id\": %d\n", layer_id
	printf "    }"
}
END { printf "\n" }
' "$_TAG_OUTPUT_DATA"

		# Clean up layer mapping (file mapping still needed for health section)
		rm -f "$_LAYER_MAPPING_TEMP"

		printf '  ],\n'

		# STEP 7: Links array REMOVED (can be derived from trace_tags[].from_tags)

		# Generate chains array from tag table (unchanged)
		printf '  "chains": [\n'
		awk '
		BEGIN { first=1 }
		{
			if (!first) printf ",\n"
			first=0
			printf "    ["
			for (i=1; i<=NF; i++) {
				if (i > 1) printf ", "
				printf "\"%s\"", $i
			}
			printf "]"
		}
		' "$_TAG_TABLE"
		printf '\n  ],\n'

		# STEP 8: Generate cross-reference matrix files for backward compatibility
		# Note: Cross_references removed from JSON schema, but matrix files still
		#       needed by HTML/Markdown viewers for cross-reference tables

		# STEP 9: Generate health section with restructured coverage
		_FILE_MAPPING_TEMP2="${OUTPUT_DIR%/}/file_mapping.tmp"
		awk -v tag_output_data="$_TAG_OUTPUT_DATA" \
			-v tag_pairs="$_TAG_PAIRS" \
			-v tag_pairs_downstream="$_TAG_PAIRS_DOWNSTREAM" \
			-v config_table="$_CONFIG_TABLE" \
			-v file_mapping="$_FILE_MAPPING_TEMP2" \
			-v sep="$SHTRACER_SEPARATOR" '
	# JSON escape function (defined outside BEGIN)
	function json_escape(s,   result) {
		result = s
		gsub(/\\/, "\\\\", result)
		gsub(/"/, "\\\"", result)
		gsub(/\n/, "\\n", result)
		gsub(/\r/, "\\r", result)
		gsub(/\t/, "\\t", result)
		return result
	}

		# Selection sort to keep isolated tags and their metadata aligned alphabetically
		function sort_isolated(n, tags, files, lines,    i, j, min, tmpTag, tmpFile, tmpLine) {
			if (n <= 1) return
			for (i = 0; i < n - 1; i++) {
				min = i
				for (j = i + 1; j < n; j++) {
					if (tags[j] < tags[min]) {
						min = j
					}
				}
				if (min != i) {
					tmpTag = tags[i]; tags[i] = tags[min]; tags[min] = tmpTag
					tmpFile = files[i]; files[i] = files[min]; files[min] = tmpFile
					tmpLine = lines[i]; lines[i] = lines[min]; lines[min] = tmpLine
				}
			}
		}

	BEGIN {
		# Load global file_id mapping (full path -> file_id) generated earlier
		while ((getline line < file_mapping) > 0) {
			split(line, parts, "|")
			if (length(parts) >= 2) {
				file_global_id[parts[1]] = parts[2]
			}
		}
		close(file_mapping)

			n_layers = 0
			while ((getline line < config_table) > 0) {
				split(line, fields, sep)
				if (length(fields) >= 1 && fields[1] != "") {
					layer = fields[1]
					sub(/^:/, "", layer)
					sub(/.*:/, "", layer)
					if (layer != "" && !(layer in layer_order)) {
						layer_order[layer] = n_layers
						ordered_layers[n_layers] = layer
						n_layers++
					}
				}
			}
			close(config_table)

			# Read all tags
			while ((getline line < tag_output_data) > 0) {
				split(line, fields, sep)
				if (length(fields) >= 8) {
					tag_id = fields[2]
					all_tags[tag_id] = 1
					tag_target[tag_id] = fields[1]
					tag_file[tag_id] = fields[5]
					tag_line[tag_id] = fields[6]
					tag_version[tag_id] = fields[8]
					total_tags++
				}
			}
			close(tag_output_data)

			# Read tags with links - track tags appearing in EITHER column
			# A tag is considered "connected" if it appears as FROM or TO (excluding NONE)
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				# Mark both FROM and TO tags as having connections
				if (fields[1] != "NONE") {
					tags_with_links[fields[1]] = 1
				}
				if (fields[2] != "NONE") {
					tags_with_links[fields[2]] = 1
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE") {
					tags_with_links[fields[1]] = 1
				}
				if (fields[2] != "NONE") {
					tags_with_links[fields[2]] = 1
				}
			}
			close(tag_pairs_downstream)

			tags_with_links_count = 0
			for (tag in tags_with_links) {
				tags_with_links_count++
			}

			isolated_count = 0
			for (tag in all_tags) {
				if (!(tag in tags_with_links)) {
					isolated_tags[isolated_count] = tag
					file_path = tag_file[tag]
					isolated_file_id[isolated_count] = file_global_id[file_path]
					isolated_line[isolated_count] = tag_line[tag]
					isolated_count++
				}
			}

			# Sort isolated tags alphabetically for deterministic output
			sort_isolated(isolated_count, isolated_tags, isolated_file_id, isolated_line)

			# Build tag-to-layer mapping
			for (tag in all_tags) {
				target = tag_target[tag]
				layer = target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)
				tag_to_layer[tag] = layer

				file_path = tag_file[tag]
				tag_to_file[tag] = file_path
			}

			# Build adjacency list (same as before)
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					if (adj_list[src] == "") {
						adj_list[src] = tgt
					} else {
						adj_list[src] = adj_list[src] ";" tgt
					}
					if (adj_list[tgt] == "") {
						adj_list[tgt] = src
					} else {
						adj_list[tgt] = adj_list[tgt] ";" src
					}
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					if (index(adj_list[src], tgt) == 0) {
						if (adj_list[src] == "") {
							adj_list[src] = tgt
						} else {
							adj_list[src] = adj_list[src] ";" tgt
						}
					}
					if (index(adj_list[tgt], src) == 0) {
						if (adj_list[tgt] == "") {
							adj_list[tgt] = src
						} else {
							adj_list[tgt] = adj_list[tgt] ";" src
						}
					}
				}
			}
			close(tag_pairs_downstream)

			# Calculate coverage (same logic as before)
			for (tag in all_tags) {
				layer = tag_to_layer[tag]
				file_path = tag_to_file[tag]
				n_slash = split(file_path, path_parts, "/")
				file_basename = path_parts[n_slash]

				if (!(layer in layer_order) || file_basename == "config.md") continue

				my_order = layer_order[layer]
				layer_total[layer]++

				file_key = layer "|" file_path
				file_total[file_key]++

				if (file_version[file_key] == "") {
					file_version[file_key] = tag_version[tag]
				}

				up_layers_str = ""
				down_layers_str = ""
				has_up = 0
				has_down = 0

				if (adj_list[tag] != "") {
					n_neighbors = split(adj_list[tag], neighbor_arr, ";")
					for (j = 1; j <= n_neighbors; j++) {
						neighbor = neighbor_arr[j]
						neighbor_layer = tag_to_layer[neighbor]

						if (neighbor_layer == "" || neighbor_layer == layer) continue
						if (!(neighbor_layer in layer_order)) continue

						neighbor_order = layer_order[neighbor_layer]

						if (neighbor_order < my_order) {
							has_up = 1
							if (index(up_layers_str, neighbor_layer) == 0) {
								up_layers_str = up_layers_str (up_layers_str ? "," : "") neighbor_layer
							}
						}
						else if (neighbor_order > my_order) {
							has_down = 1
							if (index(down_layers_str, neighbor_layer) == 0) {
								down_layers_str = down_layers_str (down_layers_str ? "," : "") neighbor_layer
							}
						}
					}
				}

				if (up_layers_str != "") {
					n_up = split(up_layers_str, up_arr, ",")
					layer_up_count[layer]++
					for (k = 1; k <= n_up; k++) {
						target_layer = up_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_up_targets)) {
							layer_up_targets[key] = 1
						}
					}
				}

				if (down_layers_str != "") {
					n_down = split(down_layers_str, down_arr, ",")
					layer_down_count[layer]++
					for (k = 1; k <= n_down; k++) {
						target_layer = down_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_down_targets)) {
							layer_down_targets[key] = 1
						}
					}
				}

				if (has_up) file_up[file_key] = (file_up[file_key] + 0) + 1
				if (has_down) file_down[file_key] = (file_down[file_key] + 0) + 1
			}

			# Output health section
			printf "  \"health\": {\n"
			printf "    \"total_tags\": %d,\n", total_tags
			printf "    \"tags_with_links\": %d,\n", tags_with_links_count
			printf "    \"isolated_tags\": %d,\n", isolated_count
			printf "    \"isolated_tag_list\": [\n"
			for (i = 0; i < isolated_count; i++) {
				if (i > 0) printf ",\n"
				tag_id = json_escape(isolated_tags[i])
				fid = isolated_file_id[i]
				line_num = isolated_line[i]
				if (fid == "") fid = -1
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"id\": \"%s\", \"file_id\": %d, \"line\": %d}", tag_id, fid, line_num
			}
			printf "\n    ],\n"

			# Output dangling reference information
			printf "    \"dangling_references\": %d,\n", dangling_count
			printf "    \"dangling_reference_list\": [\n"
			for (i = 0; i < dangling_count; i++) {
				if (i > 0) printf ",\n"
				child_tag = json_escape(dangling_child[i])
				parent_tag = json_escape(dangling_parent[i])
				file_path = dangling_file_path[i]
				fid = file_global_id[file_path]
				if (fid == "") fid = -1
				line_num = dangling_line[i]
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"child_tag\": \"%s\", \"missing_parent\": \"%s\", \"file_id\": %d, \"line\": %d}", child_tag, parent_tag, fid, line_num
			}
			printf "\n    ],\n"

			printf "    \"coverage\": {\n"
			printf "      \"layers\": [\n"

			# Output coverage layers with NEW nested upstream/downstream structure
			layer_id = 0
			layer_printed = 0
			for (i = 0; i < n_layers; i++) {
				layer = ordered_layers[i]
				if (!(layer in layer_total)) continue

				total = layer_total[layer]
				up_count = layer_up_count[layer] + 0
				down_count = layer_down_count[layer] + 0
				# NEW: Float percentages with 1 decimal
				up_pct = (total > 0) ? (up_count * 100.0 / total) : 0.0
				down_pct = (total > 0) ? (down_count * 100.0 / total) : 0.0

				if (layer_printed) printf ",\n"
				layer_printed = 1

				printf "        {\n"
				printf "          \"layer_id\": %d,\n", layer_id
				printf "          \"name\": \"%s\",\n", layer
				printf "          \"total\": %d,\n", total

				# NEW: Nested upstream object
				printf "          \"upstream\": {\n"
				printf "            \"count\": %d,\n", up_count
				printf "            \"percent\": %.1f\n", up_pct
				printf "          },\n"

				# NEW: Nested downstream object
				printf "          \"downstream\": {\n"
				printf "            \"count\": %d,\n", down_count
				printf "            \"percent\": %.1f\n", down_pct
				printf "          },\n"

				# Output files with NEW structure
				printf "          \"files\": [\n"
				first_file = 1

				# Need to map file path to global file_id
				# We'\''ll reuse the file_mapping we created earlier
				for (file_key in file_total) {
					split(file_key, parts, "|")
					if (parts[1] != layer) continue

					file_path = parts[2]
					file_tag_total = file_total[file_key]
					file_up_count = file_up[file_key] + 0
					file_down_count = file_down[file_key] + 0

					# NEW: Float percentages with 1 decimal
					file_up_pct = (file_tag_total > 0) ? (file_up_count * 100.0 / file_tag_total) : 0.0
					file_down_pct = (file_tag_total > 0) ? (file_down_count * 100.0 / file_tag_total) : 0.0

					# Get global file_id from mapping
					fid = file_global_id[file_path]
					if (fid == "") fid = -1

					# Get version from file_version
					file_ver = file_version[file_key]
					if (file_ver == "") file_ver = "unknown"

					if (!first_file) printf ",\n"
					first_file = 0

					printf "            {\n"
					printf "              \"file_id\": %d,\n", fid
					printf "              \"total\": %d,\n", file_tag_total

					# NEW: Nested upstream object
					printf "              \"upstream\": {\n"
					printf "                \"count\": %d,\n", file_up_count
					printf "                \"percent\": %.1f\n", file_up_pct
					printf "              },\n"

					# NEW: Nested downstream object
					printf "              \"downstream\": {\n"
					printf "                \"count\": %d,\n", file_down_count
					printf "                \"percent\": %.1f\n", file_down_pct
					printf "              },\n"

					# Escape version string for JSON
					printf "              \"version\": \"%s\"\n", json_escape(file_ver)
					printf "            }"
				}
				printf "\n          ]\n"
				printf "        }"
				layer_id++
			}

			printf "\n      ]\n"
			printf "    }\n"
			printf "  }\n"
		}'

		printf '}\n'
	} >"$_JSON_OUTPUT_FILENAME"

	# Clean up temp file
	rm -f "${OUTPUT_DIR%/}/file_mapping.tmp"

	# Generate cross-reference matrix files for backward compatibility with viewers
	_generate_cross_reference_matrix_files "$_JSON_OUTPUT_FILENAME" "$OUTPUT_DIR"

	echo "$_JSON_OUTPUT_FILENAME"
}

##
# @brief Generate cross-reference matrix files from JSON trace_tags
# @details Creates 06_cross_ref_matrix_* files in OUTPUT_DIR/tags/ directory
#          by parsing trace_tags[].from_tags field for backward compatibility
#          with HTML and Markdown viewers
# @param $1 : JSON file path
# @param $2 : OUTPUT_DIR
# @return 0 on success, 1 on failure
# @tag @IMP2.8@ (FROM: @ARC2.4@)
_generate_cross_reference_matrix_files() {
	_json_file="$1"
	_output_dir="${2%/}"
	_tags_dir="${_output_dir}/tags"

	[ -f "$_json_file" ] || return 1
	[ -d "$_tags_dir" ] || mkdir -p "$_tags_dir"

	# Remove stale matrices to avoid duplicate tabs
	rm -f "${_tags_dir}"/[0-9][0-9]_cross_ref_matrix_* 2>/dev/null || true

	# Parse files, layers, and trace_tags arrays from JSON, then emit adjacent-layer matrices
	printf '%s\n' "$(cat "$_json_file")" | awk -v tags_dir="$_tags_dir" '
		function safe_path(p) { return (p == "") ? "/unknown" : p }
		function safe_line(l) { return (l == "" || l + 0 < 1) ? 1 : l }
		BEGIN {
			in_files=0; in_file_obj=0;
			in_layers=0; in_layer_obj=0;
			in_trace_tags=0; in_tag_obj=0;
			layer_count=0; link_count=0;
		}

		/"files": \[/ { in_files=1; next }
		in_files && /^  \],?$/ { in_files=0; next }
		in_files && /^    \{/ { in_file_obj=1; file_id=""; file=""; next }
		in_files && in_file_obj && /^    \},?$/ { if (file_id != "") file_map[file_id]=file; in_file_obj=0; next }
		in_file_obj && /"file_id":/ { match($0, /"file_id": ([0-9]+)/, arr); file_id = arr[1] }
		in_file_obj && /"file":/ { match($0, /"file": "([^"]+)"/, arr); file = arr[1] }

		/"layers": \[/ { in_layers=1; next }
		in_layers && /^  \],?$/ { in_layers=0; next }
		in_layers && /^    \{/ { in_layer_obj=1; layer_id=""; name=""; pattern=""; next }
		in_layers && in_layer_obj && /^    \},?$/ {
			if (layer_id != "") {
				layer_ids[++layer_count] = layer_id
				layer_map[layer_id] = name
				pattern_map[layer_id] = pattern
			}
			in_layer_obj=0; next
		}
		in_layer_obj && /"layer_id":/ { match($0, /"layer_id": ([0-9]+)/, arr); layer_id = arr[1] }
		in_layer_obj && /"name":/ { match($0, /"name": "([^"]+)"/, arr); name = arr[1] }
		in_layer_obj && /"pattern":/ { match($0, /"pattern": "([^"]+)"/, arr); pattern = arr[1] }

		/"trace_tags": \[/ { in_trace_tags=1; next }
		in_trace_tags && /^  \],?$/ { in_trace_tags=0; next }
		in_trace_tags && /^    \{/ { in_tag_obj=1; tag_id=""; layer_id=""; file_id=""; line=""; from_tags_count=0; delete from_tags; next }
		in_trace_tags && in_tag_obj && /^    \},?$/ {
			if (tag_id != "" && layer_id != "" && file_id != "") {
				tag_layer[tag_id] = layer_id
				tag_file[tag_id] = file_map[file_id]
				tag_line[tag_id] = safe_line(line)
				tags_in_layer_count[layer_id]++
				tags_in_layer[layer_id, tags_in_layer_count[layer_id]] = tag_id

				# Collect upstream sources from from_tags array
				n_up = 0
				if (from_tags_count > 0) {
					for (u = 1; u <= from_tags_count; u++) upstream[u] = from_tags[u]
					n_up = from_tags_count
				}

				for (u = 1; u <= n_up; u++) {
					src_tag = upstream[u]
					if (src_tag == "" || src_tag == "null" || src_tag == "NONE") continue
					key = src_tag SUBSEP tag_id
					if (!link_seen[key]++) {
						links[link_count,0] = src_tag
						links[link_count,1] = tag_id
						link_count++
					}
				}
			}
			in_tag_obj=0; next
		}
		in_tag_obj && /"id":/ { match($0, /"id": "([^"]+)"/, arr); tag_id = arr[1] }
		in_tag_obj && /"from_tags":/ {
			from_tags_count = 0
			delete from_tags
			if (match($0, /\[(.*)\]/, arr)) {
				raw = arr[1]
				n_ft = split(raw, ft_arr, ",")
				for (k = 1; k <= n_ft; k++) {
					t = ft_arr[k]
					gsub(/^[ \t"]+|[ \t"]+$/, "", t)
					if (t != "" && t != "NONE" && t != "null") {
						from_tags[++from_tags_count] = t
					}
				}
			}
		}
		in_tag_obj && /"layer_id":/ { match($0, /"layer_id": ([0-9]+)/, arr); layer_id = arr[1] }
		in_tag_obj && /"file_id":/ { match($0, /"file_id": ([0-9]+)/, arr); file_id = arr[1] }
		in_tag_obj && /"line":/ { match($0, /"line": ([0-9]+)/, arr); line = arr[1] }

		END {
			if (layer_count < 2) exit
			file_num = 6
			for (i = 1; i < layer_count; i++) {
				src_id = layer_ids[i]
				tgt_id = layer_ids[i+1]
				src_name = layer_map[src_id]
				tgt_name = layer_map[tgt_id]
				src_pattern = pattern_map[src_id]
				tgt_pattern = pattern_map[tgt_id]
				src_safe = src_name; tgt_safe = tgt_name
				gsub(/ /, "_", src_safe); gsub(/ /, "_", tgt_safe)
				filename = sprintf("%s/%02d_cross_ref_matrix_%s_%s", tags_dir, file_num, src_safe, tgt_safe)
				file_num++

				print "[METADATA]" > filename
				print src_pattern "<shtracer_separator>" tgt_pattern >> filename
				print "[ROW_TAGS]" >> filename
				row_n = tags_in_layer_count[src_id]
				for (r = 1; r <= row_n; r++) {
					tag = tags_in_layer[src_id, r]
					print tag "<shtracer_separator>" safe_path(tag_file[tag]) "<shtracer_separator>" safe_line(tag_line[tag]) >> filename
				}

				print "[COL_TAGS]" >> filename
				col_n = tags_in_layer_count[tgt_id]
				for (c = 1; c <= col_n; c++) {
					tag = tags_in_layer[tgt_id, c]
					print tag "<shtracer_separator>" safe_path(tag_file[tag]) "<shtracer_separator>" safe_line(tag_line[tag]) >> filename
				}

				print "[MATRIX]" >> filename
				for (l = 0; l < link_count; l++) {
					src_tag = links[l,0]
					tgt_tag = links[l,1]
					if (tag_layer[src_tag] == src_id && tag_layer[tgt_tag] == tgt_id) {
						mkey = src_tag "<shtracer_separator>" tgt_tag
						if (!matrix_seen[mkey]++) print mkey >> filename
					}
				}
				close(filename)
			}
		}
	'

	return 0
}

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
		echo "[shtracer][error]: Cannot read input files for cross-reference generation" >&2
		return 1
	fi

	_xref_output_dir="${OUTPUT_DIR%/}/tags/"

	# Extract layer hierarchy dynamically from config table (preserves config.md order)
	_layer_hierarchy=$(_extract_layer_hierarchy "$_config_table")

	if [ -z "$_layer_hierarchy" ]; then
		echo "[shtracer][warn]: No traceability layers found in tags" >&2
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
				echo "[shtracer][warn]: Failed to generate $_prev_identifier vs $_current_identifier matrix" >&2
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
		echo "[shtracer][error]: Tags directory not found: $_tags_dir" >&2
		return 1
	fi

	_md_output_dir="${OUTPUT_DIR%/}/cross_reference/"
	mkdir -p "$_md_output_dir" || {
		echo "[shtracer][error]: Failed to create output directory: $_md_output_dir" >&2
		return 1
	}

	# Find all cross-reference matrix intermediate files
	_matrix_files=$(find "$_tags_dir" -maxdepth 1 -type f -name '*_cross_ref_matrix_*' 2>/dev/null | sort)

	if [ -z "$_matrix_files" ]; then
		echo "[shtracer][warn]: No cross-reference matrix files found" >&2
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
			echo "[shtracer][warn]: Failed to generate markdown for $_layer_pair" >&2
		fi

		_file_num=$((_file_num + 1))
	done

	echo "$_md_output_dir"
	return 0
}
