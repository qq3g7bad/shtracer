#!/bin/sh

# shtracer_markdown_viewer.sh — Generates a print-friendly Markdown report.
#
# Input contract (Option B, intermediate-file architecture):
#   - stdin: JSON, used ONLY for metadata (version, generated, config_path)
#   - intermediate files under ${OUTPUT_DIR}/ are the source of truth for
#     everything else.
#
# Intermediate files consumed:
#   - config/01_config_table          — layer names and tag patterns (in order)
#   - tags/01_tags                    — trace tags (8 SEP-delimited fields)
#   - tags/04_tag_table               — traceability chains (space-separated)
#   - tags/health_summary             — health + coverage (sectioned)
#   - tags/[0-9][0-9]_cross_ref_matrix_*  — adjacent-layer link matrices
#
# Can be executed (JSON → Markdown to stdout) or sourced (for unit tests).

SHTRACER_SEP="${SHTRACER_SEPARATOR:-<shtracer_separator>}"
# Single-char delimiter used when piping SEP-delimited lines into `read`
# (POSIX `read` treats each character of IFS as a separator, so a multi-char
# SEP cannot be used directly).
_MD_TAB=$(printf '\t')

##
# @brief Convert SEP-delimited stdin into tab-delimited stdout
_md_sep_to_tab() {
	awk -F"$SHTRACER_SEP" -v OFS="$_MD_TAB" '{ $1 = $1; print }'
}

##
# @brief Format a version string (git:.../mtime:.../unknown) for display
_md_ver_display() {
	case "$1" in
		"" | unknown) printf 'unknown' ;;
		git:*) printf "\`%s\`" "${1#git:}" ;;
		mtime:*)
			printf '%s' "${1#mtime:}" | sed 's/T/ /; s/:[0-9][0-9]Z$//'
			;;
		*) printf '%s' "$1" ;;
	esac
}

##
# @brief Print one section from tags/health_summary
# @param $1 : section name (without brackets), e.g. "SUMMARY", "LAYERS"
_md_read_section() {
	[ -r "${_MD_HEALTH:-}" ] || return 0
	awk -v tag="[$1]" '
		$0 == tag { on=1; next }
		on && /^\[/ { on=0; exit }
		on { print }
	' "$_MD_HEALTH"
}

##
# @brief Print unique layer names in config-file order
_md_layer_order() {
	[ -r "${_MD_CONFIG_TABLE:-}" ] || return 0
	awk -F"$SHTRACER_SEP" '
		NF >= 1 && $1 != "" {
			layer = $1
			sub(/^:/, "", layer)
			sub(/.*:/, "", layer)
			if (layer != "" && !(layer in seen)) {
				seen[layer] = 1
				print layer
			}
		}
	' "$_MD_CONFIG_TABLE"
}

##
# @brief Resolve a layer abbreviation (e.g. "REQ") to its full name
# @param $1 : abbreviation
# @details Matches the first layer whose lowercased name starts with the
#          lowercased abbreviation. Falls back to the abbreviation itself.
_md_layer_display_name() {
	_abbrev="$1"
	if [ ! -r "${_MD_CONFIG_TABLE:-}" ]; then
		printf '%s' "$_abbrev"
		return 0
	fi
	_result=$(awk -F"$SHTRACER_SEP" -v abbrev="$_abbrev" '
		BEGIN { want = tolower(abbrev) }
		NF >= 1 && $1 != "" {
			layer = $1
			sub(/^:/, "", layer)
			sub(/.*:/, "", layer)
			if (layer != "" && !(layer in seen)) {
				seen[layer] = 1
				if (tolower(layer) ~ "^" want) { print layer; exit }
			}
		}
	' "$_MD_CONFIG_TABLE")
	if [ -n "$_result" ]; then
		printf '%s' "$_result"
	else
		printf '%s' "$_abbrev"
	fi
}

##
# @brief Parse matrix file [METADATA] section
# @return row_pattern|col_pattern|timestamp
# @tag @IMP4.3.6.1@ (FROM: @ARC4.1@)
_parse_matrix_metadata() {
	_matrix_file="$1"
	awk -F"$SHTRACER_SEP" '
		/^\[METADATA\]/ { mode = "meta"; next }
		/^\[ROW_TAGS\]/ { mode = ""; exit }
		mode == "meta" && NF >= 2 {
			row_pattern = $1
			col_pattern = $2
			timestamp = $3
			gsub(/@|\[.*\]|\+/, "", row_pattern)
			gsub(/@|\[.*\]|\+/, "", col_pattern)
			print row_pattern "|" col_pattern "|" timestamp
			exit
		}
	' "$_matrix_file"
}

##
# @brief Parse matrix file [MATRIX] links
# @return row_tag|col_tag (one per line)
# @tag @IMP4.3.6.4@ (FROM: @ARC4.1@)
_parse_matrix_links() {
	_matrix_file="$1"
	awk -F"$SHTRACER_SEP" '
		/^\[MATRIX\]/ { mode = "matrix"; next }
		mode == "matrix" && $0 != "" && NF >= 2 {
			print $1 "|" $2
		}
	' "$_matrix_file"
}

##
# @brief Generate the report header section
# @tag @IMP4.3.1@ (FROM: @ARC4.1@)
_generate_markdown_header() {
	cat <<EOF
# Traceability Report

- **Generated**: $_MD_GENERATED
- **Config**: \`$_MD_CONFIG_PATH\`
- **shtracer version**: $_MD_VERSION

---
EOF
}

##
# @brief Generate the table of contents
# @tag @IMP4.3.2@ (FROM: @ARC4.1@)
_generate_markdown_toc() {
	_layers=$(_md_layer_order)

	printf '\n## Table of Contents\n\n'
	_toc_num=1

	printf '%s. [Executive Summary](#executive-summary)\n' "$_toc_num"
	printf '%s\n' "$_layers" | while IFS= read -r _layer_name; do
		[ -z "$_layer_name" ] && continue
		_anchor=$(printf '%s' "$_layer_name" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
		printf '   - [%s](#%s)\n' "$_layer_name" "$_anchor"
	done
	_toc_num=$((_toc_num + 1))

	printf '%s. [Traceability Health](#traceability-health)\n' "$_toc_num"
	_toc_num=$((_toc_num + 1))
	printf '%s. [Requirement traceability matrix](#requirement-traceability-matrix)\n' "$_toc_num"
	_toc_num=$((_toc_num + 1))
	printf '%s. [Cross-Reference Details](#cross-reference-details)\n' "$_toc_num"
	_toc_num=$((_toc_num + 1))
	printf '%s. [Tag Index](#tag-index)\n' "$_toc_num"

	printf '\n---\n\n'
}

##
# @brief Generate executive summary with per-layer coverage + file list
# @tag @IMP4.3.3@ (FROM: @ARC4.1@)
_generate_markdown_summary() {
	_layers_tab=$(_md_read_section LAYERS | _md_sep_to_tab)
	_files_tab=$(_md_read_section LAYER_FILES | _md_sep_to_tab)

	printf '\n## Executive Summary\n\n'

	printf '%s\n' "$_layers_tab" | while IFS="$_MD_TAB" read -r _lid _name _total _up_cnt _up_pct _down_cnt _down_pct; do
		[ -z "$_name" ] && continue

		printf '### %s\n\n' "$_name"

		if awk "BEGIN {exit !($_up_pct > 0 || $_down_pct > 0)}"; then
			_up_str=""
			_down_str=""
			if awk "BEGIN {exit !($_up_pct > 0)}"; then
				_up_str="upstream $_up_pct%"
			fi
			if awk "BEGIN {exit !($_down_pct > 0)}"; then
				_down_str="downstream $_down_pct%"
			fi
			if [ -n "$_up_str" ] && [ -n "$_down_str" ]; then
				printf '%s / %s\n\n' "$_up_str" "$_down_str"
			elif [ -n "$_up_str" ]; then
				printf '%s\n\n' "$_up_str"
			elif [ -n "$_down_str" ]; then
				printf '%s\n\n' "$_down_str"
			fi
		fi

		# File-level rows whose layer_id matches $_lid
		printf '%s\n' "$_files_tab" \
			| awk -F"$_MD_TAB" -v lid="$_lid" '$1 == lid' \
			| while IFS="$_MD_TAB" read -r _flid _fpath _ft _fu _fu_pct _fd _fd_pct _fver; do
				[ -z "$_fpath" ] && continue
				_ver_display=$(_md_ver_display "$_fver")
				_file_basename=$(basename "$_fpath")
				printf -- '- %s (%s) upstream %s%% / downstream %s%%\n' "$_file_basename" "$_ver_display" "$_fu_pct" "$_fd_pct"
			done
		printf '\n'
	done

	printf -- '---\n\n'
}

##
# @brief Generate traceability health (coverage + issue lists)
# @tag @IMP4.3.4@ (FROM: @ARC4.1@)
_generate_markdown_health() {
	_summary_line=$(_md_read_section SUMMARY | awk 'NR==1')
	_total_tags=$(printf '%s' "$_summary_line" | awk -F"$SHTRACER_SEP" '{print $1}')
	_tags_with_links=$(printf '%s' "$_summary_line" | awk -F"$SHTRACER_SEP" '{print $2}')
	_isolated_tags=$(printf '%s' "$_summary_line" | awk -F"$SHTRACER_SEP" '{print $3}')
	_duplicate_tags=$(printf '%s' "$_summary_line" | awk -F"$SHTRACER_SEP" '{print $4}')
	_dangling_refs=$(printf '%s' "$_summary_line" | awk -F"$SHTRACER_SEP" '{print $5}')

	# Tab-delimited copies of the issue lists (needed for `read -r` below).
	_isolated_tab=$(_md_read_section ISOLATED | _md_sep_to_tab)
	_duplicate_tab=$(_md_read_section DUPLICATE | _md_sep_to_tab)
	_dangling_tab=$(_md_read_section DANGLING | _md_sep_to_tab)

	_total_tags=${_total_tags:-0}
	_tags_with_links=${_tags_with_links:-0}
	_isolated_tags=${_isolated_tags:-0}
	_duplicate_tags=${_duplicate_tags:-0}
	_dangling_refs=${_dangling_refs:-0}

	if [ "$_total_tags" -gt 0 ]; then
		_isolated_pct=$((100 * _isolated_tags / _total_tags))
	else
		_isolated_pct=0
	fi
	_tags_with_links_pct=$((100 - _isolated_pct))

	cat <<EOF
## Traceability Health

### Coverage Analysis

| Metric                | Value    |
| --------------------- | -------- |
| Total Tags            | $_total_tags      |
| Tags with Links       | $_tags_with_links ($_tags_with_links_pct%) |
| Isolated Tags         | $_isolated_tags ($_isolated_pct%) |
| Duplicate Tags        | $_duplicate_tags |
| Dangling References   | $_dangling_refs |

EOF

	printf '### Isolated Tags\n\n'
	if [ "$_isolated_tags" -eq 0 ]; then
		printf '✓ No isolated tags found.\n\n'
	else
		printf '%s isolated tag(s) with no downstream traceability:\n\n' "$_isolated_tags"
		printf '%s\n' "$_isolated_tab" | while IFS="$_MD_TAB" read -r _tag _file _line; do
			[ -z "$_tag" ] && continue
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				_file_basename=$(basename "$_file")
				printf -- '- **%s** (%s:%s)\n' "$_tag" "$_file_basename" "${_line:-1}"
			else
				printf -- '- **%s**\n' "$_tag"
			fi
		done
		printf '\n'
	fi

	printf '### Duplicate Tags\n\n'
	if [ "$_duplicate_tags" -eq 0 ]; then
		printf '✓ No duplicate tags found.\n\n'
	else
		printf '%s duplicate tag(s) detected (same tag ID appears multiple times):\n\n' "$_duplicate_tags"
		printf '%s\n' "$_duplicate_tab" | while IFS="$_MD_TAB" read -r _tag _file _line; do
			[ -z "$_tag" ] && continue
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				_file_basename=$(basename "$_file")
				printf -- '- **%s** (%s:%s)\n' "$_tag" "$_file_basename" "${_line:-1}"
			else
				printf -- '- **%s**\n' "$_tag"
			fi
		done
		printf '\n'
	fi

	printf '### Dangling References\n\n'
	if [ "$_dangling_refs" -eq 0 ]; then
		printf '✓ No dangling references found.\n\n'
	else
		printf '%s dangling reference(s) - tags referencing non-existent parents:\n\n' "$_dangling_refs"
		printf '| Child Tag | Missing Parent | File | Line |\n'
		printf '|-----------|----------------|------|------|\n'
		printf '%s\n' "$_dangling_tab" | while IFS="$_MD_TAB" read -r _child _parent _file _line; do
			[ -z "$_child" ] && continue
			if [ -n "$_file" ] && [ "$_file" != "unknown" ]; then
				_file_basename=$(basename "$_file")
				printf '| %s | %s | %s | %s |\n' "$_child" "$_parent" "$_file_basename" "${_line:-1}"
			else
				printf '| %s | %s | %s | %s |\n' "$_child" "$_parent" "unknown" "${_line:-1}"
			fi
		done
		printf '\n'
	fi

	printf -- '---\n\n'
}

##
# @brief Generate the traceability-chains table from tags/04_tag_table
# @tag @IMP4.3.5@ (FROM: @ARC4.1@)
_generate_markdown_chains() {
	_total=$(grep -c '^' "$_MD_TAG_TABLE" 2>/dev/null || echo 0)

	printf '## Requirement traceability matrix\n\n'
	printf '%s total traceability chains.\n\n' "$_total"

	_order=$(_md_layer_order)
	_col_count=$(printf '%s\n' "$_order" | grep -c '^' || echo 0)

	_header=$(printf '%s\n' "$_order" | sed ':a;N;$!ba;s/\n/ | /g')
	printf '| %s |\n' "$_header"

	printf '|'
	_i=0
	while [ "$_i" -lt "$_col_count" ]; do
		printf '%s' '------|'
		_i=$((_i + 1))
	done
	printf '\n'

	while IFS= read -r _chain; do
		[ -z "$_chain" ] && continue
		_row=$(printf '%s' "$_chain" | sed 's/ / | /g')
		printf '| %s |\n' "$_row"
	done <"$_MD_TAG_TABLE"

	printf '\n---\n\n<!-- PAGE BREAK -->\n'
}

##
# @brief Generate a 2-column table for one cross-reference matrix file
# @tag @IMP4.3.6.5@ (FROM: @ARC4.1@)
_generate_markdown_matrix_table() {
	_matrix_file="$1"

	_metadata=$(_parse_matrix_metadata "$_matrix_file")
	_row_layer=$(printf '%s' "$_metadata" | cut -d'|' -f1)
	_col_layer=$(printf '%s' "$_metadata" | cut -d'|' -f2)

	_row_layer_full=$(_md_layer_display_name "$_row_layer")
	_col_layer_full=$(_md_layer_display_name "$_col_layer")

	_links=$(_parse_matrix_links "$_matrix_file")
	_link_count=$(printf '%s\n' "$_links" | grep -c '^' || echo 0)

	printf '### %s → %s\n\n' "$_row_layer_full" "$_col_layer_full"
	printf '**Summary**:\n\n'
	printf -- '- %s traceability links\n' "$_link_count"
	printf '\n'

	printf '| %s | %s |\n' "Source Tag" "Target Tag"
	printf '|------------|------------|\n'
	printf '%s\n' "$_links" | while IFS='|' read -r _source _target; do
		[ -z "$_source" ] && continue
		printf '| %s | %s |\n' "$_source" "$_target"
	done
	printf '\n'
}

##
# @brief Generate cross-reference details (iterates matrix files in order)
# @tag @IMP4.3.6@ (FROM: @ARC4.1@)
_generate_markdown_cross_refs() {
	printf '## Cross-Reference Details\n\n'

	if [ ! -d "$_MD_TAGS_DIR" ]; then
		printf 'No cross-reference data available.\n\n'
		printf -- '---\n\n<!-- PAGE BREAK -->\n'
		return 0
	fi

	_matrix_files=$(find "$_MD_TAGS_DIR" -maxdepth 1 -name '[0-9][0-9]_cross_ref_matrix_*' -type f 2>/dev/null | sort)

	if [ -z "$_matrix_files" ]; then
		printf 'No cross-reference matrices found.\n\n'
		printf -- '---\n\n<!-- PAGE BREAK -->\n'
		return 0
	fi

	_matrix_count=$(printf '%s\n' "$_matrix_files" | grep -c '^' || echo 0)
	printf 'Generated %s cross-reference matrix/matrices:\n\n' "$_matrix_count"

	printf '%s\n' "$_matrix_files" | while IFS= read -r _matrix_file; do
		[ -z "$_matrix_file" ] && continue
		_generate_markdown_matrix_table "$_matrix_file"
		printf '\n'
	done

	printf -- '---\n\n<!-- PAGE BREAK -->\n'
}

##
# @brief Generate the alphabetical tag index from tags/01_tags
# @tag @IMP4.3.7@ (FROM: @ARC4.1@)
_generate_markdown_tag_index() {
	_count=$(grep -c '^' "$_MD_TAGS_FILE" 2>/dev/null || echo 0)

	printf '## Tag Index\n\n'
	printf 'Alphabetical listing of all %s tags:\n\n' "$_count"

	# 01_tags fields: trace_target<SEP>tag<SEP>from<SEP>desc<SEP>file<SEP>line<SEP>filenum<SEP>version
	# Emit: tag<SEP>desc<SEP>file<SEP>line<SEP>version  sorted by tag.
	# POSIX sort -t requires single char; instead rely on lexicographic sort of the
	# whole line (tag is the first field, so ordering matches).
	awk -F"$SHTRACER_SEP" -v OFS="$_MD_TAB" '{
		print $2, $4, $5, $6, $8
	}' "$_MD_TAGS_FILE" | sort | {
		_current_letter=""
		while IFS="$_MD_TAB" read -r _tag _desc _file _line _ver; do
			[ -z "$_tag" ] && continue
			_first_char=$(printf '%s' "$_tag" | sed 's/^@//' | cut -c1)
			if [ "$_first_char" != "$_current_letter" ]; then
				_current_letter="$_first_char"
				printf '\n### %s\n\n' "$_first_char"
			fi
			_short_desc=$(printf '%s' "$_desc" | cut -c1-50)
			if [ ${#_desc} -gt 50 ]; then
				_short_desc="${_short_desc}..."
			fi
			_ver_display=$(_md_ver_display "$_ver")
			printf -- '- **%s** - %s\n' "$_tag" "$_short_desc"
			printf '  - %s:%s (%s)\n' "$_file" "$_line" "$_ver_display"
		done
	}
}

##
# @brief Resolve OUTPUT_DIR from env or from the JSON's metadata.config_path
# @param $1 : path to stdin-JSON temp file
# @return Exports _MD_OUTPUT_DIR, _MD_VERSION, _MD_GENERATED, _MD_CONFIG_PATH
_md_resolve_context() {
	_json_file="$1"

	_MD_VERSION=$(grep -m 1 '"version"' "$_json_file" 2>/dev/null \
		| sed 's/.*"version"[[:space:]]*:[[:space:]]*"//; s/".*//')
	_MD_GENERATED=$(grep -m 1 '"generated"' "$_json_file" 2>/dev/null \
		| sed 's/.*"generated"[[:space:]]*:[[:space:]]*"//; s/".*//')
	_MD_CONFIG_PATH=$(grep -m 1 '"config_path"' "$_json_file" 2>/dev/null \
		| sed 's/.*"config_path"[[:space:]]*:[[:space:]]*"//; s/".*//')

	if [ -n "${OUTPUT_DIR:-}" ]; then
		_MD_OUTPUT_DIR="${OUTPUT_DIR%/}"
	elif [ -n "$_MD_CONFIG_PATH" ]; then
		_MD_OUTPUT_DIR="$(dirname "$_MD_CONFIG_PATH")/shtracer_output"
	else
		_MD_OUTPUT_DIR="./shtracer_output"
	fi

	_MD_TAGS_DIR="${_MD_OUTPUT_DIR}/tags"
	_MD_CONFIG_TABLE="${_MD_OUTPUT_DIR}/config/01_config_table"
	_MD_TAGS_FILE="${_MD_TAGS_DIR}/01_tags"
	_MD_TAG_TABLE="${_MD_TAGS_DIR}/04_tag_table"
	_MD_HEALTH="${_MD_TAGS_DIR}/health_summary"
}

##
# @brief Main entry — reads JSON from stdin, writes Markdown to stdout
# @tag @IMP4.3@ (FROM: @ARC4.1@)
shtracer_markdown_viewer_main() {
	_json_tmp=$(mktemp 2>/dev/null) || {
		printf 'Error: unable to create temp file\n' >&2
		return 1
	}
	# shellcheck disable=SC2064
	trap "rm -f '$_json_tmp'" EXIT INT TERM

	cat >"$_json_tmp"
	if [ ! -s "$_json_tmp" ]; then
		printf 'Error: No JSON input received from stdin\n' >&2
		return 1
	fi

	_md_resolve_context "$_json_tmp"

	# Sanity-check required intermediate files
	for _f in "$_MD_CONFIG_TABLE" "$_MD_TAGS_FILE" "$_MD_TAG_TABLE" "$_MD_HEALTH"; do
		if [ ! -r "$_f" ]; then
			printf 'Error: required intermediate file missing: %s\n' "$_f" >&2
			return 1
		fi
	done

	_generate_markdown_header
	_generate_markdown_toc
	_generate_markdown_summary
	_generate_markdown_health
	_generate_markdown_chains
	_generate_markdown_cross_refs
	_generate_markdown_tag_index

	return 0
}

# Standalone execution vs sourcing pattern
case "$0" in
	*shtracer_markdown_viewer.sh | *shtracer_markdown_viewer)
		shtracer_markdown_viewer_main "$@"
		;;
	*)
		: # sourced for unit tests
		;;
esac
