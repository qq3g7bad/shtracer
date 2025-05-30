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
		profile_start "make_target_flowchart"

		_CONFIG_OUTPUT_DATA="$1"
		_FORK_STRING_BRE="\\\\(fork\\\\)"

		_UML_OUTPUT_DIR="${OUTPUT_DIR%/}/uml/"
		_UML_OUTPUT_CONFIG="${_UML_OUTPUT_DIR%/}/01_config"
		_UML_OUTPUT_DECLARATION="${_UML_OUTPUT_DIR%/}/10_declaration"
		_UML_OUTPUT_RELATIONSHIPS="${_UML_OUTPUT_DIR%/}/11_relationships"
		_UML_OUTPUT_FILENAME="${_UML_OUTPUT_DIR%/}/20_uml"

		mkdir -p "$_UML_OUTPUT_DIR"

		# Parse config output data
		awk <"$_CONFIG_OUTPUT_DATA" \
			-F "$SHTRACER_SEPARATOR" \
			'{ if(previous != $1){print $1}; previous=$1 }' |
			awk -F":" -v fork_string_bre="$_FORK_STRING_BRE" \
				'BEGIN{}
				{
					# Fork counter
					fork_count       = gsub(fork_string_bre, "&")
					fork_count_index = 2*fork_count
					increment_index  = 2*fork_count + 1

					idx[increment_index]++

					# If fork detected
					if(previous_fork_count+1 == fork_count) {
						idx[fork_count_index] = 0
						idx[increment_index]  = 1
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
			sed 's/^[^_]*_//; s/ :/:/' >"$_UML_OUTPUT_CONFIG"

		# Prepare declaration for UML
		awk <"$_UML_OUTPUT_CONFIG" \
			-F ":" \
			'{print "id"$1"(["$NF"])"}' >"$_UML_OUTPUT_DECLARATION"

		# Prepare relationships for UML
		awk <"$_UML_OUTPUT_CONFIG" \
			-F ":" -v fork_string_bre="$_FORK_STRING_BRE" \
			'BEGIN{previous="start"}
			{
				# Fork counter
				fork_count = gsub(fork_string_bre, "&")

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
					fork_last[fork_counter[fork_count]] = $1
				}

				# 2) fork counter decremented
				else if(previous_fork_count >= fork_count+1) {
					while(previous_fork_count >= fork_count+1) {
						print "end"
						for (i=1; i<=fork_counter[previous_fork_count]; i++) {
							print "id"fork_last[i]" --> id"$1
						}
						previous_fork_count--;
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
							fork_last[fork_counter[fork_count]] = $1
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
							previous="id"$1
						}
					}
					# 4-1)
					else {
						print previous" --> id"$1
						previous="id"$1
					}
				}
				previous_fork_count=fork_count
			}
			END {
				# When the fork block is not closed at the last line
				if (fork_count >= 1) {
					while(fork_count >=1) {
						print "end"
						fork_count--;
					}
				}
				else {
					print stop[End]
					print "id"$1" --> stop"
				}
			}' |
			# delete subgraphs without data
			sed '/^subgraph ".*"$/{N;/^\(subgraph ".*"\)\nend$/d;}' >"$_UML_OUTPUT_RELATIONSHIPS"

		_TEMPLATE_FLOWCHART='flowchart TB

			start[Start]
			@state_declaration@
			@state_relationships@
			'

		echo "$_TEMPLATE_FLOWCHART" |
			sed "/@state_declaration@/r $_UML_OUTPUT_DECLARATION" |
			sed '/@state_declaration@/d' |
			sed "/@state_relationships@/r $_UML_OUTPUT_RELATIONSHIPS" |
			sed '/@state_relationships@/d' |
			sed 's/^[[:space:]]*//' >"$_UML_OUTPUT_FILENAME"

		echo "$_UML_OUTPUT_FILENAME"
		profile_end "make_target_flowchart"
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
		profile_start "convert_template_html"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$2"
		_UML_FILENAME="$3"
		_TEMPLATE_HTML_DIR="$4"

		profile_start "convert_template_html_add_header_row"
		# Add header row
		_TABLE_HTML="<thead>\n  <tr>\n$(awk 'NR == 1 {
			for (i = 1; i <= NF; i++) {
				printf "    <th><a href=\"#\" onclick=\"sortTable(%d)\">sort</a></th>\\n", i - 1;
			}
		}' <"$_TAG_TABLE_FILENAME")  </tr>\n</thead>\n"
		profile_end "convert_template_html_add_header_row"

		# Prepare the tag table : Convert a tag table to a html table.
		profile_start "convert_template_html_prepare_tag_table"
		_TABLE_HTML="$_TABLE_HTML<tbody>$(awk '{
			printf "\\n  <tr>\\n"
				for (i = 1; i <= NF; i++) {
					printf "    <td>"$i"</td>\\n"
				}
			printf "  </tr>"
		} ' <"$_TAG_TABLE_FILENAME")\n</tbody>"
		profile_end "convert_template_html_prepare_tag_table"

		# Insert the tag table to a html template.
		profile_start "convert_template_html_insert_tag_table"
		_HTML_CONTENT="$(
			sed -e "s/'\\\\n'/'\\\\\\\\n'/g" \
				-e "s|^[ \t]*<!-- INSERT TABLE -->.*|<!-- SHTRACER INSERTED -->\n${_TABLE_HTML}\n<!-- SHTRACER INSERTED -->|" \
				<"${_TEMPLATE_HTML_DIR%/}/template.html"
		)"
		profile_end "convert_template_html_insert_tag_table"

		profile_start "convert_template_html_insert_tag_table_link"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			sed "$(echo "$_TAG_INFO_TABLE" |
				awk -F"$SHTRACER_SEPARATOR" '{
					n = split($3, parts, "/");
					filename = parts[n];
					raw_filename = filename;
					extension_pos = match(raw_filename, /\.[^\.]+$/);
					gsub(/\./, "_", filename);
					gsub(/^/, "Target_", filename);

					if (extension_pos) {
						extension = substr(raw_filename, extension_pos + 1);
					} else {
						extension = "sh";
					}
					print "s|" $1 "|<a href=\"#\" onclick=\"showText(event, '\''" filename "'\'', " $2 ", '\''" extension "'\'')\" onmouseover=\"showTooltip(event, '\''" filename "'\'')\" onmouseout=\"hideTooltip()\">" $1 "</a>|g";
				}')")"
		profile_end "convert_template_html_insert_tag_table_link"

		# Prepare file information
		profile_start "convert_template_html_insert_information"
		_INFORMATION="<ul>\n$(echo "$_TAG_INFO_TABLE" |
			awk -F"$SHTRACER_SEPARATOR" '{print $3}' |
			sort -u |
			awk '{
				n = split($0, parts, "/");
				filename = parts[n];
				raw_filename = filename;
				extension_pos = match(filename, /\.[^\.]+$/);
				gsub(/\./, "_", filename);
				gsub(/^/, "Target_", filename);

				if (extension_pos) {
					extension = substr(raw_filename, extension_pos + 1);
				} else {
					extension = "sh";
				}
				print "<li><a href=\"#\" onclick=\"showText(event, '\''"filename"'\'', ""1"", '\''"extension"'\'')\" onmouseover=\"showTooltip(event, '\''"filename"'\'')\" onmouseout=\"hideTooltip()\">"raw_filename"</a></li>"
			}')\n</ul>"
		profile_end "convert_template_html_insert_information"

		# Prepare the Mermaid UML
		_MERMAID_SCRIPT="$(cat "$_UML_FILENAME")"

		profile_start "convert_template_html_insert_mermaid"
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

		profile_end "convert_template_html_insert_mermaid"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" |
			sed '/<!-- SHTRACER INSERTED -->/d')"

		echo "$_HTML_CONTENT"

		profile_end "convert_template_html"
	)
}

##
# @brief Convert template js file for tracing targets
# @param $1 : TAG_INFO_TABLE
# @param $2 : TEMPLATE_ASSETS_DIR
convert_template_js() {
	(
		profile_start "convert_template_js"
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
			echo "$_TAG_INFO_TABLE" | awk -F"$SHTRACER_SEPARATOR" '{ print $3 }' | sort -u |
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
						for (i = 1; i <= 9; i++) {
							gsub("\\\\" i, "<SHTRACER_BACKSLASH>" i, contents) # REMOVE FROM SHTRACER PREVIEW
						}
						# 大文字 \A〜\Z
						for (i = 65; i <= 90; i++) {
							c = sprintf("%c", i)
							gsub("\\\\" c, "<SHTRACER_BACKSLASH>" c, contents) # REMOVE FROM SHTRACER PREVIEW
						}

						# 小文字 \a〜\z
						for (i = 97; i <= 122; i++) {
							c = sprintf("%c", i)
							gsub("\\\\" c, "<SHTRACER_BACKSLASH>" c, contents) # REMOVE FROM SHTRACER PREVIEW
						}
						gsub("\\\\\\\\", "<SHTRACER_BACKSLASH>" c, contents) # REMOVE FROM SHTRACER PREVIEW
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
			sed 's/<SHTRACER_NEWLINE>/\\\\n/g' |
			sed 's/<SHTRACER_BACKSLASH>/\\\\/g'
		profile_end "convert_template_js"
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
		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" -v config_path="${CONFIG_PATH}" -v separator="$SHTRACER_SEPARATOR" '
			BEGIN {
				OFS = separator;
			}
			{
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
