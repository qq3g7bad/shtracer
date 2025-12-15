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
# @brief
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

		# Delete comment blocks from the confiuration markdown file
		_CONFIG_FILE_WITHOUT_COMMENT="$(awk <"$1" \
			'
			/`.*<!--.*-->.*`/   {
				match($0, /`.*<!--.*-->.*`/);               # Exception for comment blocks that is surrounded by backquotes.
				print(substr($0, 1, RSTART + RLENGTH - 1)); # Delete comments
				next;
			}
			{
				sub(/<!--.*-->/, "")
			}
			/<!--/ { in_comment=1 }
			/-->/ && in_comment { in_comment=0; next }
			/<!--/,/-->/ { if (in_comment) next }
			!in_comment { print }
			' |
			sed '/^[[:space:]]*$/d' |    # Delete empty lines
			sed 's/^[[:space:]]*\* //' | # Delete start spaces
			sed 's/[[:space:]]*$//' |    # Delete end spaces
			sed 's/\*\*\(.*\)\*\*:/\1:/')"

		# Convert sections to lines
		echo "$_CONFIG_FILE_WITHOUT_COMMENT" |
			sed 's/:/'"$SHTRACER_SEPARATOR"'/;
						s/[[:space:]]*'"$SHTRACER_SEPARATOR"'[[:space:]]*/'"$SHTRACER_SEPARATOR"'/' |
			awk -F "$SHTRACER_SEPARATOR" -v separator="$SHTRACER_SEPARATOR" '\
				function print_data() {
					print \
						a["TITLE"],
						a["PATH"],
						a["EXTENSION FILTER"],
						a["IGNORE FILTER"],
						a["BRIEF"],
						a["TAG FORMAT"],
						a["TAG LINE FORMAT"],
						a["TAG-TITLE OFFSET"],
						a["PRE-EXTRA-SCRIPT"],
						a["POST-EXTRA-SCRIPT"];
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
# @tag     @IMP2.2.1@ (FROM: @IMP2.2@)
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
# @tag     @IMP2.2.2@ (FROM: @IMP2.2@)
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
			pre_extra_script = extract_from_backtick($9)
			post_extra_script = extract_from_backtick($10)

			if (tag_format == "") { next }

			cmd = "test -f \""path"\"; echo $?"; cmd | getline is_file_exist; close(cmd);
			if (is_file_exist == 0) {
				print title, path, extension, ignore, brief, tag_format, tag_line_format, tag_title_offset, pre_extra_script, post_extra_script, ""
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
				while ((cmd | getline path) > 0) { print title, path, extension, ignore, brief, tag_format, tag_line_format, tag_title_offset, pre_extra_script, post_extra_script, ""; } close(cmd);
			}
		}' | sort -u
}

##
# @brief   Extract tags from files and write to output
# @param   $1 : File list from _extract_tags_discover_files
# @param   $2 : Output file path
# @return  None (writes to file)
# @tag     @IMP2.2.3@ (FROM: @IMP2.2@)
_extract_tags_process_files() {
	_FROM_TAG_START="FROM:"
	_FROM_TAG_REGEX="\(""$_FROM_TAG_START"".*\)"

	echo "$1" |
		awk -F "$SHTRACER_SEPARATOR" -v separator="$SHTRACER_SEPARATOR" '
			# For title offset, extract only the offset line
			{
				title = $1
				path = $2
				tag_format = $6
				tag_line_format = $7
				tag_title_offset = $8 ? $8 > 0 : 0
				pre_extra_script = $9
				post_extra_script = $10

				# Execute pre_extra_script
				system(pre_extra_script)

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

						filename = path; gsub(".*/", "", filename);
						dirname = path; gsub("/[^/]*$", "", dirname)
						cmd = "cd "dirname";PWD=\"$(pwd)\"; \
							echo \"${PWD%/}/\""; \
							cmd | getline absolute_path; close(cmd)
						printf("%s%s%s", absolute_path, filename, separator)   # column 5: file absolute path
						printf("%s%s", line_num, separator)                    # column 6: line number including title
						printf("%s\n", NR, separator)                          # column 7: file num
					}
					if (counter >= 0) {
						counter--;
					}

				}
				# Execute post_extra_script
				system(post_extra_script)
			}
			' >"$2"
}

##
# @brief
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
# @brief
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

		awk <"$1" \
			-F"$SHTRACER_SEPARATOR" \
			'{
				# OFS="'"$SHTRACER_SEPARATOR"'"
				split($3, parent, /[ ]*,[ ]*/);
				for (i=1; i<=length(parent); i++){
					print(parent[i], $2);
				}
		}' >"$_TAG_PAIRS"

		# Prepare upstream table (starting point)
		grep "^$NODATA_STRING" "$_TAG_PAIRS" |
			sort |
			awk '{$1=""; print $0}' |
			sed 's/^[[:space:]]*//' |
			sed '/^$/d' >"$_TAG_TABLE"

		# Prepare downstream tag table
		grep -v "^$NODATA_STRING" "$_TAG_PAIRS" |
			sort |
			sed '/^$/d' >"$_TAG_PAIRS_DOWNSTREAM"

		# Make joined tag table (each row has a single trace tag chain)
		if [ "$(wc -l <"$_TAG_PAIRS_DOWNSTREAM")" -ge 1 ]; then
			join_tag_pairs "$_TAG_TABLE" "$_TAG_PAIRS_DOWNSTREAM"
		  if [ $? -ne 0 ]; then
		  	error_exit 1 "make_tag_table" "Error in joine_tag_pairs"
		  fi
		else
			error_exit 1 "make_tag_table" "No linked tags found."
		fi
		sort -k1,1 <"$_TAG_TABLE" >"$_TAG_TABLE"TMP
		mv "$_TAG_TABLE"TMP "$_TAG_TABLE"

		# [Verify] Duplicated tags
		awk <"$1" \
			-F"$SHTRACER_SEPARATOR" \
			'{
				print $2
			 }' |
			sort |
			uniq -d >"$_TAG_TABLE_DUPLICATED"

		# [Verify] Detect isolated FROM_TAG
		awk <"$_TAG_PAIRS" '{print $1; print $2; print $2}' |
			sort |
			uniq -u |
			sed 's/^/'"$NODATA_STRING"' /' |
			sed '/^$/d' |
			awk '{print $2}' >"$_ISOLATED_FROM_TAG"

		echo "$_TAG_TABLE$SHTRACER_SEPARATOR$_ISOLATED_FROM_TAG$SHTRACER_SEPARATOR$_TAG_TABLE_DUPLICATED"
	)
}

##
# @brief
# @param  $1 : filename of the tag table
# @param  $2 : filename of tag pairs without starting points
# @tag    @IMP2.4@ (FROM: @ARC2.3@)
join_tag_pairs() {
	(
		if [ ! -r "$1" ] || [ ! -r "$2" ] || [ $# -ne 2 ]; then
			error_exit 1 "join_tag_pairs" "Incorrect argument."
		fi

		_TAG_TABLE="$1"
		_TAG_TABLE_DOWNSTREAM="$2"

		_NF="$(awk <"$_TAG_TABLE" 'BEGIN{a=0}{if(a<NF){a=NF}}END{print a}')"
		_NF_PLUS1="$((_NF + 1))"

		_JOINED_TMP="$(join -1 "$_NF" -2 1 -a 1 "$_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM")"
		if [ $? -ne 0 ]; then
			error_exit 1 "join_tag_pairs" "Error in join command"
		fi

		_JOINED_TMP="$(echo "$_JOINED_TMP" |
			awk '{if($'"$_NF_PLUS1"'=="") $'"$_NF_PLUS1"'="'"$NODATA_STRING"'"; print}' |
			awk '{for (i=2; i<=(NF-1); i++){printf("%s ", $i)}; printf("%s %s\n", $1, $NF)}' |
			sort -k$_NF_PLUS1,$_NF_PLUS1)"

		_IS_LAST="$(echo "$_JOINED_TMP" |
			awk '{if($NF != "'"$NODATA_STRING"'"){a=1}}END{if(a==1){print 0}else{print 1}}')"

		if [ "$_IS_LAST" -eq 1 ]; then
			return
		else
			echo "$_JOINED_TMP" >"$_TAG_TABLE"
			join_tag_pairs "$_TAG_TABLE" "$_TAG_TABLE_DOWNSTREAM"
		fi
	)
}

##
# @brief
# @param  $1 : filenames of verification output
# @tag    @IMP2.5@ (FROM: @ARC2.5@)
print_verification_result() {
	_TAG_TABLE_ISOLATED="$(echo "$1" | awk -F"$SHTRACER_SEPARATOR" '{print $1}')"
	_TAG_TABLE_DUPLICATED="$(echo "$1" | awk -F"$SHTRACER_SEPARATOR" '{print $2}')"

	_RETURN_NUM="0"

	if [ "$(wc <"$_TAG_TABLE_ISOLATED" -l)" -ne 0 ] && [ "$(cat "$_TAG_TABLE_ISOLATED")" != "$NODATA_STRING" ]; then
		printf "1) Following tags are isolated.\n" 1>&2
		cat <"$_TAG_TABLE_ISOLATED" 1>&2
		_RETURN_NUM=$((_RETURN_NUM + 1))
	fi
	if [ "$(wc <"$_TAG_TABLE_DUPLICATED" -l)" -ne 0 ]; then
		printf "2) Following tags are duplicated.\n" 1>&2
		cat <"$_TAG_TABLE_DUPLICATED" 1>&2
		_RETURN_NUM=$((_RETURN_NUM + 1))
	fi
	return "$_RETURN_NUM"
}

##
# @brief
# @param  $1 : CONFIG_OUTPUT_DATA
# @param  $2 : BEFORE_TAG
# @param  $3 : AFTER_TAG
# @tag    @IMP2.6@ (FROM: @ARC2.4@)
swap_tags() {
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

		_FILE_LIST="$(echo "$_TARGET_DATA" |
			while read -r _DATA; do
				_PATH="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $2 }' | sed 's/"\(.*\)"/\1/')"
				_EXTENSION="$(echo "$_DATA" | awk -F "$SHTRACER_SEPARATOR" '{ print $3 }' | sed 's/"\(.*\)"/\1/')"
				cd "$CONFIG_DIR" || error_exit 1 "swat_tags" "Cannot change directory to config path"

				# Check if TARGET_PATH is file or direcrory
				if [ -f "$_PATH" ]; then # File
					_FILE="$_PATH"
				else # Directory (Check extension: Multiple extensions can be set by grep argument way)
					_EXTENSION=${_EXTENSION:-*}
					_FILE="$(eval ls "${_PATH%/}/" 2>/dev/null |
						grep -E "$_EXTENSION" |
						sed "s@^@$_PATH@")"

					if [ "$(echo "$_FILE" | sed '/^$/d' | wc -l)" -eq 0 ]; then
						return # There are no files to match specified extension.
					fi
				fi
				echo "$_FILE"
			done)"

		(
			cd "$CONFIG_DIR" || error_exit 1 "swap_tags" "Cannot change directory to config path"
			echo "$_FILE_LIST" |
				sort -u |
				while read -r t; do
					sed -i "s/${2}/${_TEMP_TAG}/g" "$t"
					sed -i "s/${3}/${2}/g" "$t"
					sed -i "s/${_TEMP_TAG}/${3}/g" "$t"
				done
		)
	)
}

