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

convert_template_html() {
  :
}

convert_template_js() {
  :
}

##
# @brief  Make output files (html, js, css)
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
# @param  $3 : UML_FILENAME
make_html() {
	(
		_TABLE_HTML=""
		_MERMAID_SCRIPT=""

		_TEMPLATE_HTML_DIR="${SCRIPT_DIR%/}/scripts/main/template/"
		_TEMPLTE_ASSETS_DIR="${_TEMPLATE_HTML_DIR%/}/assets/"
		_OUTPUT_ASSETS_DIR="${OUTPUT_DIR%/}/assets/"

		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" '{
				tag = $2;
				path = $5
				line = $6
				print tag, line, path
			}')"

		_UNIQ_FILE="$(echo "$_TAG_INFO_TABLE" | awk '{print $3}' | sort -u)\n${CONFIG_PATH}"

		mkdir -p "${OUTPUT_DIR%/}/assets/"

		# [HTML]
    # _UNIQ_FILE
    # _TAG_INFO_TABLE
    # _TEMPLATE_HTML_DIR

		# Add header row
		_TABLE_HTML="<thead>\n  <tr>\n$(awk 'NR == 1 {
			for (i = 1; i <= NF; i++) {
				printf "    <th><a href=\"#\" onclick=\"sortTable(%d)\">sort</a></th>\\n", i - 1;
			}
		}' <"$1")  </tr>\n</thead>\n"

		# Prepare the tag table : Convert a tag table to a html table.
		_TABLE_HTML="$_TABLE_HTML<tbody>$(awk '{
			printf "\\n  <tr>\\n"
				for (i = 1; i <= NF; i++) {
					printf "    <td>"$i"</td>\\n"
				}
			printf "  </tr>"
		} ' <"$1")\n</tbody>"

		# Insert the tag table to a html template.
		_HTML_CONTENT="$(
			sed -e "s/'\\\\n'/'\\\\\\\\n'/g" \
				-e "s|^[ \t]*<!-- INSERT TABLE -->.*|<!-- SHTRACER INSERTED -->\n${_TABLE_HTML}\n<!-- SHTRACER INSERTED -->|" \
				<"${_TEMPLATE_HTML_DIR%/}/template.html"
		)"
		_HTML_CONTENT="$(
			echo "$_TAG_INFO_TABLE" |
				{
					while read -r s; do
						_TAG="$(echo "$s" | awk '{print $1}')"
						_LINE="$(echo "$s" | awk '{print $2}')"
						_FILE_PATH="$(echo "$s" | awk '{print $3}')"
						_FILENAME="$(basename "$_FILE_PATH" | sed 's/\./_/g; s/^/Target_/')"
						_EXTENSION=$(basename "$_FILE_PATH" | sed -n 's/.*\.\([^\.]*\)$/\1/p')
						_EXTENSION="${_EXTENSION:-sh}"
						_SED_COMMAND="s|""$_TAG""|<a href=\"#\" onclick=\"showText(event, \'""$_FILENAME""\', ""$_LINE"", \'""$_EXTENSION""\', \'""$_FILE_PATH""\')\">""$_TAG""</a>|g"
						_HTML_CONTENT="$(echo "$_HTML_CONTENT" | sed "$_SED_COMMAND")"
					done
					echo "$_HTML_CONTENT"
				}
		)"

		# Prepare file information
		_INFORMATION="<ul>\n$(echo "$_UNIQ_FILE" |
			while read -r s; do
				_FILENAME="$(basename "$s" | sed 's/\./_/g; s/^/Target_/')"
				_EXTENSION=$(basename "$s" | sed -n 's/.*\.\([^\.]*\)$/\1/p')
				_EXTENSION="${_EXTENSION:-sh}"
				echo "<li><a href=\"#\" onclick=\"showText(event, '""$_FILENAME""', ""1"", '""$_EXTENSION""', '""$s""')\">""$(basename "$s")""</a></li>"
			done)\n</ul>"

		# Prepare the Mermaid UML
		_MERMAID_SCRIPT="$(cat "$3")"

		# Insert the Mermaid UML to a html template.
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			awk -v information="${_INFORMATION}" -v mermaid_script="${_MERMAID_SCRIPT}" '
				{
					gsub(/ *<!-- INSERT INFORMATION -->/,
						"<!-- SHTRACER INSERTED -->\n" information "\n<!-- SHTRACER INSERTED -->");
					gsub(/ *<!-- INSERT MERMAID -->/,
						"<!-- SHTRACER INSERTED -->\n" mermaid_script "\n<!-- SHTRACER INSERTED -->");
					print
				}' |

			awk '
				BEGIN {
			    add_space = 0
				}

				# Handle special comment
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

				# Process regular lines
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
			')"

		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			sed '/<!-- SHTRACER INSERTED -->/d')"

		echo "$_HTML_CONTENT" >"${OUTPUT_DIR%/}/output.html"

		# [JS]
    # UNIQ_FILE
    # ASSETS_TEMPLATE_DIR

		_JS_TEMPLATE='
@TRACE_TARGET_FILENAME@: {content: `
@TRACE_TARGET_CONTENTS@
`,
},
'
		pattern="@TRACE_TARGET_CONTENTS@"
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
						while read -r line; do
							case "$line" in
							*"$pattern"*)
								printf "%s\n" "$_TRACE_TARGET_CONTENTS"
								;;
							*)
								printf "%s\n" "$line"
								;;
							esac
						done
				done
		)"


		# Subsitute a comment block in the template js file to "$_JS_CONTENTS"
		while read -r s; do
			case "$s" in
			*//\ js_contents*)
				printf "%s\n" "$_JS_CONTENTS"
				;;
			*)
				printf "%s\n" "$s"
				;;
			esac
		done <"${_TEMPLTE_ASSETS_DIR%/}/show_text.js" |
			sed 's/\\$/\\\\/' |
			sed 's/<SHTRACER_NEWLINE>/\\\\n/' >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"

		# [CSS]
    # TEMPLATE_ASSETS_DIR
		cat "${_TEMPLTE_ASSETS_DIR%/}/template.css" >"${_OUTPUT_ASSETS_DIR%/}/template.css"
	)
}
