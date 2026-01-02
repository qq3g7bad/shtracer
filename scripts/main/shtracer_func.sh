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
		| sort \
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
		| sort \
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
# @brief   Detect isolated FROM tags (tags not referenced anywhere)
# @param   $1 : TAG_PAIRS file path
# @param   $2 : Output file path for isolated tags
# @return  None (writes to file)
_detect_isolated_tags() {
	# Find tags that appear only once in the entire tag pairs list
	# Pipeline: print both columns (with $2 twice for weighting) → sort →
	#           uniq -u finds unique → add NONE prefix → remove empty → extract tag
	awk <"$1" '{print $1; print $2; print $2}' \
		| sort \
		| uniq -u \
		| sed 's/^/'"$NODATA_STRING"' /' \
		| sed '/^$/d' \
		| awk '{print $2}' >"$2"
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
		}' >"$_TAG_PAIRS"

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

		# Verify tag integrity (duplicates and isolated tags)
		_verify_duplicated_tags "$1" "$_TAG_TABLE_DUPLICATED"
		_detect_isolated_tags "$_TAG_PAIRS" "$_ISOLATED_FROM_TAG"

		echo "$_TAG_TABLE$SHTRACER_SEPARATOR$_ISOLATED_FROM_TAG$SHTRACER_SEPARATOR$_TAG_TABLE_DUPLICATED"
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
# @brief  Display tag verification results (isolated and duplicated tags)
# @param  $1 : filenames of verification output
# @return 0 if no issues, 1 if isolated tags only, 2 if duplicate tags only, 3 if both
# @tag    @IMP2.5@ (FROM: @ARC2.5@)
print_verification_result() {
	_TAG_TABLE_ISOLATED="$(extract_field "$1" 1 "$SHTRACER_SEPARATOR")"
	_TAG_TABLE_DUPLICATED="$(extract_field "$1" 2 "$SHTRACER_SEPARATOR")"

	_has_isolated="0"
	_has_duplicated="0"

	if [ "$(wc <"$_TAG_TABLE_ISOLATED" -l)" -ne 0 ] && [ "$(cat "$_TAG_TABLE_ISOLATED")" != "$NODATA_STRING" ]; then
		printf "1) Following tags are isolated.\n" 1>&2
		cat <"$_TAG_TABLE_ISOLATED" 1>&2
		_has_isolated="1"
	fi
	if [ "$(wc <"$_TAG_TABLE_DUPLICATED" -l)" -ne 0 ]; then
		printf "2) Following tags are duplicated.\n" 1>&2
		cat <"$_TAG_TABLE_DUPLICATED" 1>&2
		_has_duplicated="1"
	fi

	# Return specific codes:
	# 0 = no issues
	# 1 = isolated tags only
	# 2 = duplicate tags only
	# 3 = both isolated and duplicate tags
	if [ "$_has_isolated" = "1" ] && [ "$_has_duplicated" = "1" ]; then
		return 3
	elif [ "$_has_isolated" = "1" ]; then
		return 1
	elif [ "$_has_duplicated" = "1" ]; then
		return 2
	else
		return 0
	fi
}

##
# @brief  Generate JSON output for traceability data
# @param  $1 : TAG_OUTPUT_DATA (01_tags file path)
# @param  $2 : TAG_PAIRS (02_tag_pairs file path)
# @param  $3 : TAG_PAIRS_DOWNSTREAM (03_tag_pairs_downstream file path)
# @param  $4 : TAG_TABLE (04_tag_table file path)
# @param  $5 : CONFIG_TABLE (01_config_table file path)
# @param  $6 : CONFIG_PATH (config file path)
# @return JSON_OUTPUT_FILENAME
make_json() {
	_TAG_OUTPUT_DATA="$1"
	_TAG_PAIRS="$2"
	_TAG_PAIRS_DOWNSTREAM="$3"
	_TAG_TABLE="$4"
	_CONFIG_TABLE="$5"
	_CONFIG_PATH="$6"

	_JSON_OUTPUT_FILENAME="${OUTPUT_DIR%/}/output.json"

	# Generate timestamp
	_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

	# Start JSON structure
	{
		printf '{\n'
		printf '  "metadata": {\n'
		printf '    "version": "0.1.2",\n'
		printf '    "generated": "%s",\n' "$_TIMESTAMP"
		printf '    "config_path": "%s"\n' "$_CONFIG_PATH"
		printf '  },\n'

		# Generate nodes array from 01_tags
		printf '  "nodes": [\n'
		awk -F"$SHTRACER_SEPARATOR" '
		BEGIN { first=1 }
		NF >= 8 {
			if (!first) printf ",\n"
			first=0
			# Escape quotes and backslashes in description
			desc = $4
			# First escape backslashes, then other special characters
			gsub(/\\/, "\\\\", desc)
			gsub(/"/, "\\\"", desc)
			# Use octal notation for control characters
			gsub(/\015/, "\\r", desc)  # \r (CR)
			gsub(/\012/, "\\n", desc)  # \n (LF)
			gsub(/\011/, "\\t", desc)  # \t (TAB)
			printf "    {\n"
			printf "      \"id\": \"%s\",\n", $2
			printf "      \"label\": \"%s\",\n", $2
			printf "      \"description\": \"%s\",\n", desc
			printf "      \"file\": \"%s\",\n", $5
			printf "      \"line\": %d,\n", $6
			printf "      \"trace_target\": \"%s\",\n", $1
			printf "      \"file_version\": \"%s\"\n", $8
			printf "    }"
		}
		END { printf "\n" }
		' "$_TAG_OUTPUT_DATA"
		printf '  ],\n'

		# Generate links array from tag pairs (exclude NONE and validate nodes exist)
		printf '  "links": [\n'
		# Create temporary file with node list
		_NODE_TEMP_FILE="${OUTPUT_DIR%/}/nodes.tmp"
		awk -F'<shtracer_separator>' '
		NF >= 6 {
			print $2
		}
		' "$_TAG_OUTPUT_DATA" >"$_NODE_TEMP_FILE"

		# Generate links using node validation
		awk '
		BEGIN { first=1 }
		# Read nodes into array
		ARGIND == 1 {
			nodes[$1] = 1
			next
		}
		# Process tag pairs
		ARGIND >= 2 && $1 != "NONE" && $2 != "NONE" {
			if ($1 in nodes && $2 in nodes) {
				key = $1 "," $2
				if (!seen[key]++) {
					if (!first) printf ",\n"
					first=0
					printf "    {\n"
					printf "      \"source\": \"%s\",\n", $1
					printf "      \"target\": \"%s\",\n", $2
					printf "      \"value\": 1\n"
					printf "    }"
				}
			}
		}
		' "$_NODE_TEMP_FILE" "$_TAG_PAIRS" "$_TAG_PAIRS_DOWNSTREAM"

		# Clean up temp file
		rm -f "$_NODE_TEMP_FILE"
		printf '\n  ],\n'

		# Generate chains array from tag table
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
		printf '\n  ]\n'

		printf '}\n'
	} >"$_JSON_OUTPUT_FILENAME"

	echo "$_JSON_OUTPUT_FILENAME"
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
# @tag     @IMP3.3.2.3@ (FROM: @ARC3.3.2@)
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
# @tag     @IMP3.3.2.2@ (FROM: @ARC3.3.2@)
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
# @tag     @IMP3.3.2.1@ (FROM: @ARC3.3.2@)
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
		echo "[shtracer][warning]: No traceability layers found in tags" >&2
		echo "$_xref_output_dir"
		return 0
	fi

	# Generate intermediate files for each adjacent level pair
	_file_num=6 # Start from 06 (after 01-05 are used for other files)
	_prev_identifier=""
	_prev_format=""

	# Process each layer (identifier<tab>tag_format)
	echo "$_layer_hierarchy" | while IFS="$(printf '\t')" read -r _current_identifier _current_format; do
		if [ -n "$_prev_identifier" ] && [ -n "$_prev_format" ]; then
			# Generate matrix for adjacent pair: prev_layer → current_layer
			_output_file="${_xref_output_dir}$(printf '%02d' $_file_num)_cross_ref_matrix_${_prev_identifier}_${_current_identifier}"

			if ! _generate_cross_reference_matrix "$_tags_file" "$_tag_pairs_file" \
				"$_prev_format" "$_current_format" "$_output_file"; then
				echo "[shtracer][warning]: Failed to generate $_prev_identifier vs $_current_identifier matrix" >&2
			fi

			_file_num=$((_file_num + 1))
		fi
		_prev_identifier="$_current_identifier"
		_prev_format="$_current_format"
	done

	echo "$_xref_output_dir"
	return 0
}

##
# @brief   Generate a single Markdown table from intermediate matrix file
# @param   $1 : Intermediate matrix file path
# @param   $2 : Config file path (for relative path calculation)
# @param   $3 : Output markdown file path
# @return  0 on success, 1 on error
# @tag     @IMP3.3.2.5@ (FROM: @ARC3.3.2@)
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
		orphaned_count = 0
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
			
			if (!has_link) orphaned_count++
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
		
		if (orphaned_count > 0) {
			printf "- Orphaned %s tags: %d (no links)\n", row_label, orphaned_count
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
# @tag     @IMP3.3.2.4@ (FROM: @ARC3.3.2@)
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
		echo "[shtracer][warning]: No cross-reference matrix files found" >&2
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
			echo "[shtracer][warning]: Failed to generate markdown for $_layer_pair" >&2
		fi

		_file_num=$((_file_num + 1))
	done

	echo "$_md_output_dir"
	return 0
}
