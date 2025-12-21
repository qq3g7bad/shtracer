#!/bin/sh

# This script can be executed (JSON -> single HTML to stdout) or sourced (unit tests).

##
# @brief   Generate HTML table header with sortable columns
# @param   $1 : TAG_TABLE_FILENAME
# @return  HTML <thead> element with sort buttons (literal \n for sed processing)
_html_add_table_header() {
	# AWK: Read first row of tag table, generate <th> elements with onclick handlers
	# Note: Returns literal \n strings (not newlines) for later sed substitution
	printf '%s' "<thead>\n  <tr>\n$(awk 'NR == 1 {
		for (i = 1; i <= NF; i++) {
			printf "    <th><a href=\"#\" onclick=\"sortTable(%d)\">sort</a></th>\\n", i - 1;
		}
	}' <"$1")  </tr>\n</thead>\n"
}

##
# @brief   Convert tag table rows to HTML table body
# @param   $1 : TAG_TABLE_FILENAME
# @return  HTML <tbody> element with table data (literal \n for sed processing)
_html_convert_tag_table() {
	# AWK: Process all rows, convert each field to <td> elements
	# Note: Returns literal \n strings (not newlines) for later sed substitution
	printf '%s' "<tbody>$(awk '{
		printf "\\n  <tr>\\n"
			for (i = 1; i <= NF; i++) {
				printf "    <td>"$i"</td>\\n"
			}
		printf "  </tr>"
	} ' <"$1")\n</tbody>"
}

##
# @brief   Generate sed script to convert tags to clickable links
# @param   $1 : TAG_INFO_TABLE (tag information with file paths)
# @return  sed commands to replace plain tags with <a> elements
_html_generate_tag_links() {
	echo "$1" \
		| awk -F"$SHTRACER_SEPARATOR" '{
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
		}'
}

##
# @brief   Generate HTML file information list for sidebar
# @param   $1 : TAG_INFO_TABLE (tag information with file paths)
# @return  HTML <ul> element with clickable file links
_html_generate_file_list() {
	printf '%s' "<ul>\n$(echo "$1" \
		| awk -F"$SHTRACER_SEPARATOR" '{print $3}' \
		| sort -u \
		| awk '{
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
			print "<li><a href=\"#\" onclick=\"showText(event, '\''"filename"'\'', \"\"1\"\", '\''"extension"'\'')\" onmouseover=\"showTooltip(event, '\''"filename"'\'')\" onmouseout=\"hideTooltip()\">"raw_filename"</a></li>"
		}')\n</ul>"
}

##
# @brief   Insert file information into HTML with proper indentation
# @param   $1 : HTML_CONTENT (template HTML to modify)
# @param   $2 : INFORMATION (file list HTML)
# @return  Modified HTML with inserted content and fixed indentation
_html_insert_content_with_indentation() {
	echo "$1" \
		| awk -v information="$2" '
			{
				gsub(/ *<!-- INSERT INFORMATION -->/,
					"<!-- SHTRACER INSERTED -->\n" information "\n<!-- SHTRACER INSERTED -->");
				print
			}' \
		| awk '
			BEGIN {
			    add_space = 0
			}

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
		' \
		| sed '/<!-- SHTRACER INSERTED -->/d'
}

##
# @brief Convert a template html file for output.html
# @param $1 : TAG_TABLE_FILENAME
# @param $2 : TAG_INFO_TABLE
# @param $3 : TEMPLATE_HTML_DIR
# @param $4 : JSON_FILE (optional)
convert_template_html() {
	(
		profile_start "convert_template_html"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$2"
		_TEMPLATE_HTML_DIR="$3"
		_JSON_FILE="${4:-}"

		profile_start "convert_template_html_build_table"
		_TABLE_HTML="$(_html_add_table_header "$_TAG_TABLE_FILENAME")"
		_TABLE_HTML="$_TABLE_HTML$(_html_convert_tag_table "$_TAG_TABLE_FILENAME")"
		profile_end "convert_template_html_build_table"

		profile_start "convert_template_html_insert_tag_table"
		_HTML_CONTENT="$(
			sed -e "s/'\\n'/'\\\\n'/g" \
				-e "s|^[ \t]*<!-- INSERT TABLE -->.*|<!-- SHTRACER INSERTED -->\n${_TABLE_HTML}\n<!-- SHTRACER INSERTED -->|" \
				<"${_TEMPLATE_HTML_DIR%/}/template.html"
		)"
		profile_end "convert_template_html_insert_tag_table"

		profile_start "convert_template_html_insert_tag_table_link"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" | sed "$(_html_generate_tag_links "$_TAG_INFO_TABLE")")"
		profile_end "convert_template_html_insert_tag_table_link"

		profile_start "convert_template_html_insert_information"
		_INFORMATION="$(_html_generate_file_list "$_TAG_INFO_TABLE")"
		profile_end "convert_template_html_insert_information"

		profile_start "convert_template_html_read_json"
		if [ -z "$_JSON_FILE" ]; then
			_JSON_FILE="${OUTPUT_DIR%/}/output.json"
		fi
		_JSON_DATA_B64="$(base64 -w 0 "$_JSON_FILE" 2>/dev/null || base64 "$_JSON_FILE" 2>/dev/null | tr -d '\n')"
		_JSON_SCRIPT="const traceabilityData = JSON.parse(atob('${_JSON_DATA_B64}'));"
		profile_end "convert_template_html_read_json"

		profile_start "convert_template_html_insert_json"
		_HTML_CONTENT="$(echo "$_HTML_CONTENT" | sed "s|<!-- INSERT JSON DATA -->|${_JSON_SCRIPT}|")"
		profile_end "convert_template_html_insert_json"

		profile_start "convert_template_html_insert_mermaid"
		_HTML_CONTENT="$(_html_insert_content_with_indentation "$_HTML_CONTENT" "$_INFORMATION")"
		profile_end "convert_template_html_insert_mermaid"

		echo "$_HTML_CONTENT"

		profile_end "convert_template_html"
	)
}

##
# @brief   Build TAG_INFO_TABLE from shtracer JSON output
# @param   $1 : JSON_FILE
# @return  Echoes TAG_INFO_TABLE to stdout (tag<sep>line<sep>path per line)
tag_info_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_info_table_from_json_file" "JSON file not readable"
	fi
	_sep="${SHTRACER_SEPARATOR}"
	_tmp_file="$(mktemp 2>/dev/null || mktemp -t shtracer_taginfo)"
	_tmp_sort="$(mktemp 2>/dev/null || mktemp -t shtracer_taginfo_sort)"
	trap 'rm -f "$_tmp_file" "$_tmp_sort" 2>/dev/null || true' EXIT INT TERM

	awk '
		BEGIN {
			in_nodes = 0
			in_obj = 0
		}
		function grab_str(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*\""
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("\".*", "", v)
				return v
			}
			return ""
		}
		function grab_int(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*"
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("[^0-9].*", "", v)
				return v
			}
			return ""
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)
			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				if (!in_nodes && t ~ /"nodes"[[:space:]]*:/) {
					seen_nodes_key = 1
				}
				if (!in_nodes && seen_nodes_key && t ~ /\[/) {
					in_nodes = 1
					seen_nodes_key = 0
				}

				if (in_nodes && !in_obj && t ~ /\{/) {
					in_obj = 1
					id = ""
					file = ""
					ln = ""
					idx = ""
				}

				if (in_obj) {
					v = grab_str(t, "id"); if (v != "") { id = v }
					v = grab_str(t, "file"); if (v != "") { file = v }
					v = grab_int(t, "line"); if (v != "") { ln = v }
					v = grab_int(t, "index"); if (v != "") { idx = v }

					if (t ~ /\}/) {
						if (idx == "") { idx = 999999999 }
						if (id != "" && file != "" && ln != "") {
							print idx "\t" id "\t" ln "\t" file
						}
						in_obj = 0
					}
				}

				if (in_nodes && !in_obj && t ~ /\]/) {
					in_nodes = 0
				}
			}
		}
	' <"$_JSON_FILE" \
		| sort -k1,1n \
			>"$_tmp_sort"

	awk -F '\t' -v sep="$_sep" -v OFS="" '
		!seen[$2]++ {
			print $2, sep, $3, sep, $4
		}
	' <"$_tmp_sort" >"$_tmp_file"

	_config_path="$(grep -m 1 '"config_path"' "$_JSON_FILE" 2>/dev/null | sed 's/.*"config_path"[[:space:]]*:[[:space:]]*"//; s/".*//')"
	if [ -n "$_config_path" ]; then
		printf '%s%s%s%s%s\n' '@CONFIG@' "$_sep" '1' "$_sep" "$_config_path" >>"$_tmp_file"
	fi

	cat "$_tmp_file"
	rm -f "$_tmp_file" "$_tmp_sort" 2>/dev/null || true
	trap - EXIT INT TERM
}

##
# @brief   Build TAG_TABLE from shtracer JSON output (chains)
# @param   $1 : JSON_FILE
# @return  Echoes TAG_TABLE rows to stdout (space-separated tags per line)
tag_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_table_from_json_file" "JSON file not readable"
	fi

	awk '
		BEGIN {
			in_chains = 0
			in_chain = 0
			seen_chains_key = 0
			out = ""
		}
		function grab_str(s,   v) {
			v = s
			sub(/^[[:space:]]*"/, "", v)
			sub(/".*$/, "", v)
			return v
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)
			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				if (!in_chains && t ~ /"chains"[[:space:]]*:/) {
					seen_chains_key = 1
				}
				if (!in_chains && seen_chains_key && t ~ /\[/) {
					in_chains = 1
					seen_chains_key = 0
					continue
				}

				if (in_chains && !in_chain && t ~ /\[/) {
					in_chain = 1
					out = ""
					continue
				}

				if (in_chain) {
					if (t ~ /^[[:space:]]*"/) {
						v = grab_str(t)
						if (v != "") {
							if (out == "") out = v
							else out = out " " v
						}
					}
					if (t ~ /\]/) {
						if (out != "") print out
						in_chain = 0
						out = ""
						continue
					}
				}

				if (in_chains && !in_chain && t ~ /\]/) {
					in_chains = 0
				}
			}
		}
	' <"$_JSON_FILE"
}

##
# @brief Convert template js file for tracing targets (using Base64 encoding)
# @param $1 : TAG_INFO_TABLE
# @param $2 : TEMPLATE_ASSETS_DIR
convert_template_js() {
	(
		profile_start "convert_template_js"
		_TAG_INFO_TABLE="$1"
		_TEMPLATE_ASSETS_DIR="$2"

		_JS_TEMPLATE=$(
			cat <<-'EOF'
				@TRACE_TARGET_FILENAME@: {
				      path:"@TRACE_TARGET_PATH@",
				      contentBase64:"@TRACE_TARGET_CONTENTS_BASE64@",
				      extension:"@TRACE_TARGET_EXTENSION@"
				},
			EOF
		)

		_JS_CONTENTS="$(
			echo "$_TAG_INFO_TABLE" | awk -F"$SHTRACER_SEPARATOR" '{ print $3 }' | sort -u \
				| awk -v js_template="$_JS_TEMPLATE" 'BEGIN{
						init_js_template = js_template
					}
					{
						js_template = init_js_template
						path = $0
						n = split($0, parts, "/");
						filename = parts[n];
						raw_filename = filename;

						extension_pos = match(raw_filename, /\.[^\.]+$/);
						if (extension_pos) {
							extension = substr(raw_filename, extension_pos + 1);
						} else {
							extension = "txt";
						}

						gsub(/\./, "_", filename);
						gsub(/^/, "Target_", filename);

						cmd = "base64 -w 0 \"" path "\" 2>/dev/null || base64 \"" path "\""
						cmd | getline base64_content
						close(cmd)

						gsub(/@TRACE_TARGET_PATH@/, path, js_template);
						gsub(/@TRACE_TARGET_FILENAME@/, filename, js_template);
						gsub(/@TRACE_TARGET_CONTENTS_BASE64@/, base64_content, js_template);
						gsub(/@TRACE_TARGET_EXTENSION@/, extension, js_template);
						print js_template
					}'
		)"
		while read -r s; do
			case "$s" in
				*//\ js_contents*)
					printf "%s\n" "$_JS_CONTENTS"
					;;
				*)
					printf "%s\n" "$s"
					;;
			esac
		done <"${_TEMPLATE_ASSETS_DIR%/}/show_text.js"
		profile_end "convert_template_js"
	)
}

##
# @brief  Make output files (html, js, css)
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
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

		mkdir -p "${OUTPUT_DIR%/}/assets/"
		convert_template_html "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE" "$_TEMPLATE_HTML_DIR" >"${OUTPUT_DIR%/}/output.html"
		convert_template_js "$_TAG_INFO_TABLE" "$_TEMPLTE_ASSETS_DIR" >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"
		cat "${_TEMPLTE_ASSETS_DIR%/}/template.css" >"${_OUTPUT_ASSETS_DIR%/}/template.css"
		cat "${_TEMPLTE_ASSETS_DIR%/}/traceability_diagrams.js" >"${_OUTPUT_ASSETS_DIR%/}/traceability_diagrams.js"
	)
}

print_usage() {
	cat <<-USAGE 1>&2
		Usage: shtracer_viewer.sh [--tag-table <tag_table_file>] [-i <json_file>]

		Reads shtracer JSON from stdin (default) or from -i <json_file>,
		and writes a single self-contained HTML document to stdout.

		Examples:
		  # JSON-only (viewer builds the tag table from JSON chains)
		  ./shtracer ./sample/config.md --json | ./scripts/main/shtracer_viewer.sh > output.html

		  # Explicit tag-table path
		  ./shtracer ./sample/config.md --json | ./scripts/main/shtracer_viewer.sh --tag-table ./sample/output/tags/04_tag_table > output.html

		  # JSON file input
		  ./scripts/main/shtracer_viewer.sh -i ./sample/output/output.json > output.html
	USAGE
	exit 1
}

shtracer_viewer_main() {
	JSON_FILE=""
	TAG_TABLE_FILE=""

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				print_usage
				;;
			-i)
				shift
				[ $# -gt 0 ] || print_usage
				JSON_FILE="$1"
				;;
			--tag-table)
				shift
				[ $# -gt 0 ] || print_usage
				TAG_TABLE_FILE="$1"
				;;
			*)
				print_usage
				;;
		esac
		shift
	done

	# Determine repo root (SCRIPT_DIR in shtracer terminology)
	_REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
	SCRIPT_DIR="$_REPO_DIR"
	export SCRIPT_DIR

	# Source shared functions (must be sourced, not executed)
	# shellcheck source=scripts/main/shtracer_util.sh
	. "${SCRIPT_DIR%/}/scripts/main/shtracer_util.sh"

	SHTRACER_SEPARATOR="${SHTRACER_SEPARATOR:=<shtracer_separator>}"
	export SHTRACER_SEPARATOR

	_TEMPLATE_DIR="${SCRIPT_DIR%/}/scripts/main/template"
	_TEMPLATE_ASSETS_DIR="${_TEMPLATE_DIR%/}/assets"

	_tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t shtracer_viewer)"
	_json_tmp="${_tmp_dir%/}/input.json"
	_html_tmp="${_tmp_dir%/}/base.html"
	_tag_table_tmp="${_tmp_dir%/}/tag_table"
	_show_text_tmp="${_tmp_dir%/}/show_text.js"

	cleanup() {
		rm -rf "$_tmp_dir" 2>/dev/null || true
	}
	trap cleanup EXIT INT TERM

	if [ -n "$JSON_FILE" ]; then
		[ -r "$JSON_FILE" ] || {
			echo "[shtracer_viewer.sh][error]: json not readable: $JSON_FILE" 1>&2
			exit 1
		}
		cat "$JSON_FILE" >"$_json_tmp"
	else
		if [ -t 0 ]; then
			echo "[shtracer_viewer.sh][error]: no stdin; use -i <json_file>" 1>&2
			exit 1
		fi
		cat >"$_json_tmp"
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		_config_path="$(grep -m 1 '"config_path"' "$_json_tmp" 2>/dev/null | sed 's/.*"config_path"[[:space:]]*:[[:space:]]*"//; s/".*//')"
		if [ -n "$_config_path" ]; then
			_config_dir="$(dirname "$_config_path")"
			_inferred_table="${_config_dir%/}/output/tags/04_tag_table"
			if [ -r "$_inferred_table" ]; then
				TAG_TABLE_FILE="$_inferred_table"
			fi
		fi
	fi

	if [ -n "$TAG_TABLE_FILE" ] && [ ! -r "$TAG_TABLE_FILE" ]; then
		echo "[shtracer_viewer.sh][error]: tag table not readable: $TAG_TABLE_FILE" 1>&2
		exit 1
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		tag_table_from_json_file "$_json_tmp" >"$_tag_table_tmp"
		if [ ! -s "$_tag_table_tmp" ]; then
			echo "[shtracer_viewer.sh][error]: cannot build tag table from JSON (missing/empty chains)" 1>&2
			exit 1
		fi
		TAG_TABLE_FILE="$_tag_table_tmp"
	fi

	_TAG_INFO_TABLE="$(tag_info_table_from_json_file "$_json_tmp")"

	convert_template_html "$TAG_TABLE_FILE" "$_TAG_INFO_TABLE" "$_TEMPLATE_DIR" "$_json_tmp" >"$_html_tmp"
	convert_template_js "$_TAG_INFO_TABLE" "$_TEMPLATE_ASSETS_DIR" >"$_show_text_tmp"

	awk \
		-v css_file="${_TEMPLATE_ASSETS_DIR%/}/template.css" \
		-v show_text_file="$_show_text_tmp" \
		-v trace_js_file="${_TEMPLATE_ASSETS_DIR%/}/traceability_diagrams.js" \
		'
			function emit_file(path) {
				while ((getline line < path) > 0) {
					print line
				}
				close(path)
			}
			{
				if ($0 ~ /<link rel="stylesheet" href="\.\/assets\/template\.css">/) {
					print "  <style>"
					emit_file(css_file)
					print "  </style>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/show_text\.js"><\/script>/) {
					print "  <script>"
					emit_file(show_text_file)
					print "  </script>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/traceability_diagrams\.js"><\/script>/) {
					print "  <script>"
					emit_file(trace_js_file)
					print "  </script>"
					next
				}
				print
			}
		' <"$_html_tmp"
}

case "$0" in
	*shtracer_viewer.sh | *shtracer_viewer)
		shtracer_viewer_main "$@"
		;;
	*)
		: # sourced
		;;
esac
