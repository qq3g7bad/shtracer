#!/bin/sh

# For unit test
_SHTRACER_HTML_SH=""

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
# @param	$1 : CONFIG_OUTPUT_DATA
# @return UML_OUTPUT_FILENAME
# @tag		@IMP3.1@ (FROM: @ARC3.1@)
make_target_flowchart() {
	(
		_CONFIG_OUTPUT_DATA="$1"
		_FORK_STRING_BRE="\(fork\)"

		_UML_OUTPUT_DIR="${OUTPUT_DIR%/}/uml/"
		_UML_OUTPUT_CONFIG="${_UML_OUTPUT_DIR%/}/01_config"
		_UML_OUTPUT_DECLARATION="${_UML_OUTPUT_DIR%/}/10_declaration"
		_UML_OUTPUT_RELATIONSHIPS="${_UML_OUTPUT_DIR%/}/11_relationships"
		_UML_OUTPUT_FILENAME="${_UML_OUTPUT_DIR%/}/20_uml"

		mkdir -p "$_UML_OUTPUT_DIR"

		# Parse config output data
		awk <"$_CONFIG_OUTPUT_DATA" \
			-F "$SHTRACER_SEPARATOR" \
			'{if(previous != $1){print $1}; previous=$1}' |
			awk -F":" \
				'BEGIN{}
				{
					# Fork counter
					fork_count = gsub(/'"$_FORK_STRING_BRE"'/, "&")
					fork_count_index=2*fork_count
					increment_index=2*fork_count+1

					idx[increment_index]++

					# If fork detected
					if(previous_fork_count+1 == fork_count) {
						idx[fork_count_index]=0
						idx[increment_index]=1
						idx[increment_index-2]++
					}
					previous_fork_count=fork_count


					# In fork situation, concatenation from $1 to $(NF-1)
					if(fork_count_index > 0) {
						fork_section = ""
						for (i = 2; i < NF; i++) {
							fork_section = fork_section"-"$i
						}
						if (fork_section != previous_fork_section) {
							idx[fork_count_index]++
							idx[increment_index]=1
						}
						previous_fork_section = fork_section
					}

					flowchart_idx = ""
					for (i = 1; i <= increment_index; i++) {
						flowchart_idx = flowchart_idx"_"idx[i]
					}

					print flowchart_idx, $0
				}' |
			sed 's/^[^_]*_//' |
			sed 's/ :/:/' >"$_UML_OUTPUT_CONFIG"

		# Prepare declaration for UML
		awk <"$_UML_OUTPUT_CONFIG" \
			-F ":" \
			'{print "id"$1"(["$NF"])"}' >"$_UML_OUTPUT_DECLARATION"

		# Prepare relationships for UML
		awk <"$_UML_OUTPUT_CONFIG" \
			-F ":" \
			'BEGIN{previous="start"}
			{
				# Fork counter
				fork_count = gsub(/'"$_FORK_STRING_BRE"'/, "&")

				split($1, section, "_")
				split(previous, previous_section, "_")

				# If fork detected

				# 1) fork counter incremented
				if(previous_fork_count+1 == fork_count) {
					fork_base=previous
					previous="id"$1
					print fork_base" --> id"$1
					fork_counter[fork_count]++
					print "subgraph \""$(NF-1) "\""
				}

				# 2) fork counter decremented
				else if(previous_fork_count-1 == fork_count) {
					print "end"
					for (i=1; i<=fork_counter[fork_count+1]; i++) {
						print "id"fork_last[i]" --> id"$1
					}
				}

				else{
					if (length(section) > 2 && length(previous_section) > 2) {

						# 3-1) fork again
						if(section[length(section)-1] > previous_section[length(previous_section)-1]) {
							print "end"
							print fork_base" --> id"$1
							previous="id"$1
							fork_counter[fork_count]++
							print "subgraph \""$(NF-1) "\""
						}

						# 3-2) fork end
						else if(section[length(section)-1] < previous_section[length(previous_section)-1]) {
							print previous" --> id"$1
							previous="id"$1
						}

						# 3-3) In the same fork
						else {
							print previous" --> id"$1
							fork_last[fork_counter[fork_count]] = $1
						}
					}
					# 3-2)
					else {
						print previous" --> id"$1
						previous="id"$1
					}
				}
				previous_fork_count=fork_count
			} END { print "id"$1" --> stop"}' >"$_UML_OUTPUT_RELATIONSHIPS"

		_TEMPLATE_FLOWCHART='flowchart TB

			start[Start]
			@state_declaration@
			stop[End]

			@state_relationships@
			'

		echo "$_TEMPLATE_FLOWCHART" |
			sed "/@state_declaration@/r $_UML_OUTPUT_DECLARATION" |
			sed '/@state_declaration@/d' |
			sed "/@state_relationships@/r $_UML_OUTPUT_RELATIONSHIPS" |
			sed '/@state_relationships@/d' |
			sed 's/^[[:space:]]*//' >"$_UML_OUTPUT_FILENAME"

		echo "$_UML_OUTPUT_FILENAME"
	)
}

##
# @brief
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
# @param  $3 : UML_FILENAME
make_html() {
	(
		_TABLE_HTML=""
		_MERMAID_SCRIPT=""

		_HTML_TEMPLATE_DIR="${SCRIPT_DIR%/}/scripts/main/template/"
		_HTML_ASSETS_DIR="${_HTML_TEMPLATE_DIR%/}/assets/"
		_OUTPUT_ASSETS_DIR="${OUTPUT_DIR%/}/assets/"

		# Prepare the tag table : Convert a tag table to a html table.
		while read -r line || [ -n "$line" ]; do
			_TABLE_HTML="$_TABLE_HTML<tr>"
			for cell in $(echo "$line" | sed 's/ /\n/g'); do
				_TABLE_HTML="$_TABLE_HTML<td>$cell</td>"
			done
			_TABLE_HTML="$_TABLE_HTML</tr>\n"
		done <"$1"

		# Insert the tag table to a html template.
		_HTML_CONTENT="$(
			sed "s/'\\\\n'/'\\\\\\\\n'/g" <"${_HTML_TEMPLATE_DIR%/}/template.html" |
				sed "s|^[ \t]*<!-- INSERT TABLE -->.*|<!-- SHTRACER INSERTED TABLE_UML -->\n${_TABLE_HTML}\n<!-- SHTRACER INSERTED TABLE_UML -->|"
		)"

		# Prepare the Mermaid UML
		_MERMAID_SCRIPT="$(cat "$3")"

		# Insert the Mermaid UML to a html template.
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			awk -v mermaid_script="${_MERMAID_SCRIPT}" '
        BEGIN {
            RS="";
            ORS="\n\n";
        }
        {
          gsub(/ *<!-- INSERT MERMAID -->/,
            "<!-- SHTRACER INSERTED TABLE_UML -->\n" mermaid_script "\n<!-- SHTRACER INSERTED TABLE_UML -->");
          print
        }')"

		echo "$_HTML_CONTENT" >~/Desktop/test

		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			awk 'BEGIN {
		    add_space=0
		  }
		  /<!-- SHTRACER INSERTED TABLE_UML -->/{
		    if (add_space == 0) {
		      add_space = 1
          if (previous_space_count == space_count) {
            add_space_count = previous_space_count + 2
          }
          else {
            add_space_count = previous_space_count + 4
          }
		    }
		    else {
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
		  }')"

		echo "$_HTML_CONTENT" |
			sed '/<!-- SHTRACER INSERTED TABLE_UML -->/d' >"${OUTPUT_DIR%/}/output.html"

		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" '{
				tag = $2;
        path = $5
        line = $6
        print tag, line, path
      }')"

		_UNIQ_FILE="$(echo "$_TAG_INFO_TABLE" | awk '{print $3}' | sort -u)"
		_JS_TEMPLATE='
@TRACE_TARGET_FILENAME@: {content: `
@TRACE_TARGET_CONTENTS@
`,
},
'

		# Make a JavaScript file
		_JS_CONTENTS="$(
			echo "$_UNIQ_FILE" |
				while read -r s; do
					_TRACE_TARGET_FILENAME="$(basename "$s" | sed 's/\./_/g; s/^/Target_/')"

					# for JavaScript escape
					_TRACE_TARGET_CONTENTS="$(sed 's/\\n/<SHTRACER_NEWLINE>/g' <"$s" |
						sed 's/`/\\&/g' |
						sed 's/${/\\${/g' |
						sed 's/\\\([0-9]\)/\\u005c\1/')"

					# Insert trace target contents to the JavaScript template
					echo "$_JS_TEMPLATE" |
						sed 's/@TRACE_TARGET_FILENAME@/'"$_TRACE_TARGET_FILENAME"'/g' |
						awk -v replacement="$_TRACE_TARGET_CONTENTS" '{ gsub(/@TRACE_TARGET_CONTENTS@/, replacement) }1 '
				done
		)"

		mkdir -p "${OUTPUT_DIR%/}/assets/"

		echo "$_TAG_INFO_TABLE" |
			while read -r s; do
				_SED_COMMAND="$(echo "$s" | awk '{
		      cmd = "basename \""$3"\" | sed \"s/\./_/g; s/^/Target_/\""; cmd | getline filename_result; close(cmd)
          print "s|"$1"|<a href=\"#\" onclick=\"showText(event, '\''"filename_result"'\'', "$2")\">"$1"</a>|g"
        }')"
				sed "$_SED_COMMAND" <"${OUTPUT_DIR%/}/output.html" >"${OUTPUT_DIR%/}/output_tmp.html"
				mv "${OUTPUT_DIR%/}/output_tmp.html" "${OUTPUT_DIR%/}/output.html"
			done

		# echo "$_HTML_CONTENT" >"${OUTPUT_DIR%/}/output.html"
		awk <"${_HTML_ASSETS_DIR%/}/show_text.js" -v replacement="$_JS_CONTENTS" '{ gsub(/\/\/ js_contents/, replacement) }1 ' |
			sed 's/\\$/\\\\/' |
			sed 's/<SHTRACER_NEWLINE>/\\\\n/' >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"

		# cat "${_HTML_ASSETS_DIR%/}/show_text.js" >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"
		cat "${_HTML_ASSETS_DIR%/}/template.css" >"${_OUTPUT_ASSETS_DIR%/}/template.css"
	)

}
