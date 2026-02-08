#!/bin/sh

# For unit test
_SHTRACER_EXTRACT_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*shtracer_extract*)
		: # Successfully sourced (zsh sets $0 to sourced file).
		;;
	*)
		echo "This script should only be sourced, not executed directly."
		exit 1
		;;
esac

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
		function shell_escape(string) {
			# Escape special characters for shell command execution
			gsub(/\\/, "\\\\", string)  # Backslash first
			gsub(/\$/, "\\$", string)   # Dollar sign
			gsub(/`/, "\\`", string)    # Backtick
			gsub(/"/, "\\\"", string)   # Double quote
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

			escaped_path = shell_escape(path)
			cmd = "test -f \""escaped_path"\"; echo $?"; cmd | getline is_file_exist; close(cmd);
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
					cmd = "find \"" escaped_path "\" \\( "ignore_ext_str" \\) -prune -o \\( -type f " ext_expr " \\) -print";
				}
				else {
					cmd = "find \"" escaped_path "\" -type f " ext_expr ""
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
				last_tag_line = 0
				last_tag_text = ""
				pending_tag = 0
				while (getline line < path > 0) {
					line_num++

					# 1) Print tag column
					if (line ~ tag_format && line ~ tag_line_format) {
						# If there is a pending tag from previous iteration, complete it first
						if (pending_tag && counter >= 0) {
							title_text = last_tag_text
							sub(/^#+[[:space:]]*/, "", title_text)
							printf("%s%s", title_text, separator)                        # column 4: title
							printf("%s%s", absolute_file_path, separator)          # column 5: file absolute path
							printf("%s%s", last_tag_line, separator)               # column 6: line number
							printf("%s%s", NR, separator)                          # column 7: file num
							printf("%s\n", file_version)                          # column 8: file version
						}

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
						last_tag_line = line_num
						last_tag_text = line
						pending_tag = 1
					}

					# 2) Print the offset line
					if (counter == 0) {
						sub(/^#+[[:space:]]*/, "", line)
						printf("%s%s", line, separator)                        # column 4: title
						printf("%s%s", absolute_file_path, separator)          # column 5: file absolute path
						printf("%s%s", line_num, separator)                    # column 6: line number including title
						printf("%s%s", NR, separator)                          # column 7: file num
						printf("%s\n", file_version)                          # column 8: file version
						counter = -1
						pending_tag = 0
					}
					if (counter >= 0) {
						counter--;
					}

				}
				# Handle tag at end of file (counter >= 0 means tag was found but title not printed)
				if (pending_tag && counter >= 0) {
					title_text = last_tag_text
					sub(/^#+[[:space:]]*/, "", title_text)
					printf("%s%s", title_text, separator)                        # column 4: title
					printf("%s%s", absolute_file_path, separator)          # column 5: file absolute path
					printf("%s%s", last_tag_line, separator)               # column 6: line number
					printf("%s%s", NR, separator)                          # column 7: file num
					printf("%s\n", file_version)                          # column 8: file version
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
	# Pipeline: grep for NONE tags -> sort -> remove NONE field -> trim -> remove empty lines
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
	# Pipeline: grep -v to exclude NONE tags -> sort -> remove empty lines
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
	# AWK: Extract tag field ($2) -> sort -> uniq -d finds duplicates
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
# @tag     @IMP2.5.1@ (FROM: @ARC2.5@)
_verify_dangling_fromtags() {
	# Single AWK pass over the tag data to avoid temp file/grep mismatches
	# Output format: child_tag parent_tag file line
	awk -F"$SHTRACER_SEPARATOR" -v nodata="${NODATA_STRING}" '
		NR==FNR { tags[$2]=1; next }
		{
			tag_id = $2
			from_tags = $3
			file = $5
			line = $6

			gsub(/^[[:space:]]+|[[:space:]]+$/, "", from_tags)
			n = split(from_tags, arr, /[[:space:]]*,[[:space:]]*/)
			for (i = 1; i <= n; i++) {
				parent = arr[i]
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", parent)
				if (parent != nodata && parent != "" && !(parent in tags)) {
					print tag_id " " parent " " file " " line
				}
			}
		}
	' "$1" "$1" >"$2"
}

##
# @brief   Detect isolated tags (tags with no connections at all)
# @param   $1 : TAG_PAIRS file path
# @param   $2 : TAG_OUTPUT_DATA file path (all tags)
# @param   $3 : Output file path for isolated tags
# @return  None (writes to file)
_detect_isolated_tags() {
	# Get all tags that appear in valid tag pairs (both FROM and TO must be non-NONE)
	# A tag is isolated only if it has NO valid bidirectional connections
	# Tags with only "NONE -> tag" connections are considered isolated
	_connected_tags="$(shtracer_tmpfile)" || return 1
	_all_tags="$(shtracer_tmpfile)" || return 1
	_isolated_ids="$(shtracer_tmpfile)" || return 1

	awk <"$1" '{
		if ($1 != "'"$NODATA_STRING"'" && $2 != "'"$NODATA_STRING"'") {
			print $1
			print $2
		}
	}' | sort -u >"$_connected_tags"

	# Get all tags from tag extraction (second column is tag ID)
	awk <"$2" -F"$SHTRACER_SEPARATOR" '{print $2}' | sort -u >"$_all_tags"

	# Output tags NOT in connected_tags (truly isolated tags)
	# comm -23: lines only in file1 (all_tags) not in file2 (connected_tags)
	comm -23 "$_all_tags" "$_connected_tags" >"$_isolated_ids"

	# Enrich isolated tags with file and line info from tag output data
	awk -F"$SHTRACER_SEPARATOR" -v nodata="$NODATA_STRING" '
		NR==FNR {
			tag = $2
			if (tag != "" && !(tag in file_path)) {
				file_path[tag] = $5
				line_num[tag] = $6
			}
			next
		}
		{
			tag = $1
			if (tag != "") {
				file = (tag in file_path) ? file_path[tag] : "unknown"
				line = (tag in line_num) ? line_num[tag] : 1
				if (line == "" || line + 0 < 1) line = 1
				print nodata " " tag " " file " " line
			}
		}
	' "$2" "$_isolated_ids" >"$3"

	rm -f "$_connected_tags" "$_all_tags" "$_isolated_ids"
}

##
# @brief Create file version aggregation table
# @param $1 : TAG_OUTPUT_DATA (01_tags with 8 columns)
# @param $2 : Output file path (05_file_versions)
# @return Creates file with format: trace_target<SEP>file_path<SEP>version_info
# @tag   @IMP2.2.1@ (FROM: @ARC2.2@)
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
				_np = split($3, parent, /[ ]*,[ ]*/);
				for (i=1; i<=_np; i++){
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

		# Verify that at least one tag was extracted (skip in VERIFY mode)
		# In VERIFY mode, we allow empty tag tables so verification can report proper error codes
		if [ ! -s "$_TAG_TABLE" ] && [ "${SHTRACER_MODE:-NORMAL}" != "VERIFY" ]; then
			error_exit 1 "make_tag_table" "No tags found. Check config file paths and tag patterns."
		fi

		# Make joined tag table (each row has a single trace tag chain)
		# Only join tags if there are downstream relationships (multi-level configs)
		if [ "$(wc -l <"$_TAG_PAIRS_DOWNSTREAM" | tr -d ' \t')" -ge 1 ]; then
			if ! join_tag_pairs "$_TAG_TABLE" "$_TAG_PAIRS_DOWNSTREAM"; then
				error_exit 1 "make_tag_table" "Error in join_tag_pairs"
			fi
		fi
		# Note: Single-level configurations (no downstream pairs) are valid and allowed
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
