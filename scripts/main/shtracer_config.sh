#!/bin/sh

# For unit test
_SHTRACER_CONFIG_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*shtracer_config*)
		: # Successfully sourced (zsh sets $0 to sourced file).
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
