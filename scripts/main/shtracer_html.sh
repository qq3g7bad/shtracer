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
# @param $1 : CONFIG_OUTPUT_DATA
# @return UML_OUTPUT_FILENAME
# @tag @IMP3.1@ (FROM: @ARC3.1@)
make_target_flowchart() {
	(
		profile_start "MAKE_TARGET_FLOWCHART"

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
		profile_end "MAKE_TARGET_FLOWCHART"
	)
}

##
# @brief Convert a template html file for output.html
# @param $1 : TAG_TABLE_FILENAME
# @param $2 : TAG_INFO_TABLE
# @param $3 : UML_FILENAME
# @param $4 : TEMPLATE_HTML_DIR
convert_template_html() {
	(
		profile_start "CONVERT_TEMPLATE_HTML"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$2"
		_UML_FILENAME="$3"
		_TEMPLATE_HTML_DIR="$4"

		profile_start "CONVERT_TEMPLATE_HTML_ADD_HEADER_ROW"
		# Add header row
		_TABLE_HTML="<thead>\n  <tr>\n$(awk 'NR == 1 {
			for (i = 1; i <= NF; i++) {
				printf "    <th><a href=\"#\" onclick=\"sortTable(%d)\">sort</a></th>\\n", i - 1;
			}
		}' <"$_TAG_TABLE_FILENAME")  </tr>\n</thead>\n"
		profile_end "CONVERT_TEMPLATE_HTML_ADD_HEADER_ROW"

		# Prepare the tag table : Convert a tag table to a html table.
		profile_start "CONVERT_TEMPLATE_HTML_PREPARE_TAG_TABLE"
		_TABLE_HTML="$_TABLE_HTML<tbody>$(awk '{
			printf "\\n  <tr>\\n"
				for (i = 1; i <= NF; i++) {
					printf "    <td>"$i"</td>\\n"
				}
			printf "  </tr>"
		} ' <"$_TAG_TABLE_FILENAME")\n</tbody>"
		profile_end "CONVERT_TEMPLATE_HTML_PREPARE_TAG_TABLE"

		# Insert the tag table to a html template.
		profile_start "CONVERT_TEMPLATE_HTML_INSERT_TAG_TABLE"
		_HTML_CONTENT="$(
				sed -e "s/'\\\\n'/'\\\\\\\\n'/g" \
				-e "s|^[ \t]*<!-- INSERT TABLE -->.*|<!-- SHTRACER INSERTED -->\n${_TABLE_HTML}\n<!-- SHTRACER INSERTED -->|" \
				<"${_TEMPLATE_HTML_DIR%/}/template.html"
		)"
		profile_end "CONVERT_TEMPLATE_HTML_INSERT_TAG_TABLE"

		profile_start "CONVERT_TEMPLATE_HTML_INSERT_TAG_TABLE_LINK"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			sed "$(echo "$_TAG_INFO_TABLE" |
				awk '{
				n = split($3, parts, "/");
				filename = parts[n];
        raw_filename = filename;
				gsub(/\./, "_", filename);
				gsub(/^/, "Target_", filename);
				extension_pos = match(raw_filename, /\.[^\.]+$/);

				if (extension_pos) {
					extension = substr(raw_filename, extension_pos + 1);
				} else {
					extension = "sh";
				}

					print "s|" $1 "|<a href=\"#\" onclick=\"showText(event, '\''" filename "'\'', " $2 ", '\''" extension "'\'')\" onmouseover=\"showTooltip(event, '\''" filename "'\'')\" onmouseout=\"hideTooltip()\">" $1 "</a>|g";
				}')")"
		profile_end "CONVERT_TEMPLATE_HTML_INSERT_TAG_TABLE_LINK"

		# Prepare file information
		profile_start "CONVERT_TEMPLATE_HTML_INSERT_INFORMATION"
		_INFORMATION="<ul>\n$(echo "$_TAG_INFO_TABLE" |
			awk '{print $3}' |
			sort -u |
			awk '{
				n = split($0, parts, "/");
				filename = parts[n];
				raw_filename = filename;
				gsub(/\./, "_", filename);
				gsub(/^/, "Target_", filename);
				extension_pos = match(filename, /\.[^\.]+$/);

				if (extension_pos) {
					extension = substr(raw_filename, extension_pos + 1);
				} else {
					extension = "sh";
				}
				print "<li><a href=\"#\" onclick=\"showText(event, '\''"filename"'\'', ""1"", '\''"extension"'\'')\" onmouseover=\"showTooltip(event, '\''"filename"'\'')\" onmouseout=\"hideTooltip()\">"raw_filename"</a></li>"
			}')\n</ul>"
		profile_end "CONVERT_TEMPLATE_HTML_INSERT_INFORMATION"

		# Prepare the Mermaid UML
		_MERMAID_SCRIPT="$(cat "$_UML_FILENAME")"

		profile_start "CONVERT_TEMPLATE_HTML_INSERT_MERMAID"
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

		profile_end "CONVERT_TEMPLATE_HTML_INSERT_MERMAID"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			sed '/<!-- SHTRACER INSERTED -->/d')"

		echo "$_HTML_CONTENT"

		profile_end "CONVERT_TEMPLATE_HTML"
	)
}

##
# @brief Convert template js file for tracing targets
# @param $1 : TAG_INFO_TABLE
# @param $2 : TEMPLATE_ASSETS_DIR
convert_template_js() {
	(
		profile_start "CONVERT_TEMPLATE_JS"
		_TAG_INFO_TABLE="$1"
		_TEMPLATE_ASSETS_DIR="$2"

		# Define the template with a tab-indented structure
		_JS_TEMPLATE=$(
			cat <<-'EOF'
				@TRACE_TARGET_FILENAME@: {
				      path:"@TRACE_TARGET_PATH@",
				      content: `
				@TRACE_TARGET_CONTENTS@
				`,
				},
			EOF
		)

		# Make a JavaScript file
		_JS_CONTENTS="$(
			echo "$_TAG_INFO_TABLE" | awk '{ print $3 }' | sort -u |
				awk -v js_template="$_JS_TEMPLATE" 'BEGIN{
						init_js_template = js_template
					}
					{
						js_template = init_js_template
						contents = ""
						path = $0
						n = split($0, parts, "/");
						filename = parts[n];
						raw_filename = filename;
						gsub(/\./, "_", filename);
						gsub(/^/, "Target_", filename);

						while (getline line < path > 0) {
							sub(/[^\\]\\$/, "<SHTRACER_BACKSLASH>", line)    # REMOVE FROM SHTRACER PREVIEW
							contents = contents line "\n"
						}
						gsub(/\\n/, "<SHTRACER_BACKSLASH>n", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/&/, "\\\\&", contents)                       # REMOVE FROM SHTRACER PREVIEW
						gsub(/`/, "\\`", contents)                         # REMOVE FROM SHTRACER PREVIEW
						gsub(/\${/, "\\${", contents)                      # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\1/, "<SHTRACER_BACKSLASH>1", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\2/, "<SHTRACER_BACKSLASH>2", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\3/, "<SHTRACER_BACKSLASH>3", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\4/, "<SHTRACER_BACKSLASH>4", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\5/, "<SHTRACER_BACKSLASH>5", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\6/, "<SHTRACER_BACKSLASH>6", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\7/, "<SHTRACER_BACKSLASH>7", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\8/, "<SHTRACER_BACKSLASH>8", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/\\9/, "<SHTRACER_BACKSLASH>9", contents)     # REMOVE FROM SHTRACER PREVIEW
						gsub(/@TRACE_TARGET_PATH@/, path, js_template);
						gsub(/@TRACE_TARGET_FILENAME@/, filename, js_template);
						gsub(/@TRACE_TARGET_CONTENTS@/, contents, js_template);
						print js_template
					}'
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
		done <"${_TEMPLATE_ASSETS_DIR%/}/show_text.js" |
			sed 's/^\([[:space:]]*\).*REMOVE FROM SHTRACER PREVIEW.*/ /g' |
			sed 's/<SHTRACER_NEWLINE>/\\\\n/' |
			sed 's/<SHTRACER_BACKSLASH>/\\\\/'
		profile_end "CONVERT_TEMPLATE_JS"
	)
}

##
# @brief  Make output files (html, js, css)
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
# @param  $3 : UML_FILENAME
make_html() {
	(
		_TEMPLATE_HTML_DIR="${SCRIPT_DIR%/}/scripts/main/template/"
		_TEMPLTE_ASSETS_DIR="${_TEMPLATE_HTML_DIR%/}/assets/"
		_OUTPUT_ASSETS_DIR="${OUTPUT_DIR%/}/assets/"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" -v config_path="${CONFIG_PATH}" '{
				tag = $2;
				path = $5
				line = $6
				print tag, line, path
			}
			END {
				print "@CONFIG@", "1", config_path
			}')"
		_UML_FILENAME="$3"

		mkdir -p "${OUTPUT_DIR%/}/assets/"
		convert_template_html "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE" "$_UML_FILENAME" "$_TEMPLATE_HTML_DIR" >"${OUTPUT_DIR%/}/output.html"
		convert_template_js "$_TAG_INFO_TABLE" "$_TEMPLTE_ASSETS_DIR" >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"
		cat "${_TEMPLTE_ASSETS_DIR%/}/template.css" >"${_OUTPUT_ASSETS_DIR%/}/template.css"
	)
}
