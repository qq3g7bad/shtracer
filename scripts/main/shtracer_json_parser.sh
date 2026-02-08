#!/bin/sh

# shtracer_json_parser.sh - Unified JSON parsing module for shtracer
#
# This module provides consistent JSON parsing functions for shtracer's
# output format. All functions read JSON from stdin or a provided string
# and output pipe-delimited text for easy processing by shell scripts.
#
# @tag @IMP4.6@ (FROM: @ARC1.2@)

# Prevent double-sourcing
if [ -n "${_SHTRACER_JSON_PARSER_LOADED:-}" ]; then
	# shellcheck disable=SC2317
	return 0 2>/dev/null || exit 0
fi
_SHTRACER_JSON_PARSER_LOADED=1

##
# @brief Parse metadata section from JSON
# @param $1 : JSON input string
# @return Prints metadata fields as key=value lines:
#         version=X.Y.Z
#         generated=TIMESTAMP
#         config_path=/path/to/config.md
json_parse_metadata() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_meta=0 }
		/"metadata":/ { in_meta=1; next }
		in_meta && /^  \}/ { in_meta=0; next }
		in_meta && /"version":/ {
			line=$0; sub(/.*"version": *"/, "", line); sub(/".*$/, "", line)
			if (line != "") print "version=" line
		}
		in_meta && /"generated":/ {
			line=$0; sub(/.*"generated": *"/, "", line); sub(/".*$/, "", line)
			if (line != "") print "generated=" line
		}
		in_meta && /"config_path":/ {
			line=$0; sub(/.*"config_path": *"/, "", line); sub(/".*$/, "", line)
			if (line != "") print "config_path=" line
		}
	'
}

##
# @brief Parse files array from JSON
# @param $1 : JSON input string
# @return Prints: file_id|file_path|version (one per line)
json_parse_files() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_files=0; in_obj=0 }
		/"files": \[/ { in_files=1; next }
		in_files && /^  \],?$/ { in_files=0; next }
		in_files && /^    \{/ {
			in_obj=1; file_id=""; file=""; version=""
			next
		}
		in_files && in_obj && /^    \},?$/ {
			if (file_id != "") print file_id "|" file "|" version
			in_obj=0
			next
		}
		in_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_obj && /"file":/ { line=$0; sub(/.*"file": *"/, "", line); sub(/".*$/, "", line); file = line }
		in_obj && /"version":/ { line=$0; sub(/.*"version": *"/, "", line); sub(/".*$/, "", line); version = line }
	'
}

##
# @brief Parse layers array from JSON
# @param $1 : JSON input string
# @return Prints: layer_id|name|pattern (one per line)
json_parse_layers() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_layers=0; in_obj=0 }
		/"layers": \[/ { in_layers=1; next }
		in_layers && /^  \],?$/ { in_layers=0; next }
		in_layers && /^    \{/ {
			in_obj=1; layer_id=""; name=""; pattern=""
			next
		}
		in_layers && in_obj && /^    \},?$/ {
			if (layer_id != "") print layer_id "|" name "|" pattern
			in_obj=0
			next
		}
		in_obj && /"layer_id":/ { line=$0; sub(/.*"layer_id": */, "", line); sub(/,.*$/, "", line); layer_id = line }
		in_obj && /"name":/ { line=$0; sub(/.*"name": *"/, "", line); sub(/".*$/, "", line); name = line }
		in_obj && /"pattern":/ { line=$0; sub(/.*"pattern": *"/, "", line); sub(/".*$/, "", line); pattern = line }
	'
}

##
# @brief Parse trace_tags array from JSON
# @param $1 : JSON input string
# @return Prints: id|description|file_path|line|layer_name|version (one per line)
# @details Resolves file_id and layer_id to actual values using files/layers arrays
json_parse_trace_tags() {
	_json="$1"

	# Get files and layers for lookups
	_files="$(json_parse_files "$_json")"
	_layers="$(json_parse_layers "$_json")"

	# Note: lookup data is fed via stdin (not -v) for nawk/macOS awk portability
	{
		printf '%s\n' "---FILES---"
		printf '%s\n' "$_files"
		printf '%s\n' "---LAYERS---"
		printf '%s\n' "$_layers"
		printf '%s\n' "---JSON---"
		printf '%s\n' "$_json"
	} | awk '
		/^---FILES---$/ { mode="files"; next }
		/^---LAYERS---$/ { mode="layers"; next }
		/^---JSON---$/ { mode="json"; next }

		mode == "files" && /\|/ {
			split($0, parts, "|")
			if (parts[1] != "") {
				file_map[parts[1]] = parts[2]
				ver_map[parts[1]] = parts[3]
			}
			next
		}
		mode == "layers" && /\|/ {
			split($0, parts, "|")
			if (parts[1] != "") {
				layer_map[parts[1]] = parts[2]
			}
			next
		}

		mode != "json" { next }

		/"trace_tags": \[/ { in_tags=1; next }
		in_tags && /^  \],?$/ { in_tags=0; next }
		in_tags && /^    \{/ {
			in_obj=1
			tag_id=""; desc=""; file_id=""; line=""; layer_id=""
			next
		}
		in_tags && in_obj && /^    \},?$/ {
			if (tag_id != "") {
				file = file_map[file_id]
				version = ver_map[file_id]
				target = layer_map[layer_id]
				print tag_id "|" desc "|" file "|" line "|" target "|" version
			}
			in_obj=0
			next
		}
		in_obj && /"id":/ { line=$0; sub(/.*"id": *"/, "", line); sub(/".*$/, "", line); tag_id = line }
		in_obj && /"description":/ { line=$0; sub(/.*"description": *"/, "", line); sub(/".*$/, "", line); desc = line }
		in_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_obj && /"line":/ { line=$0; sub(/.*"line": */, "", line); sub(/,.*$/, "", line); line = line }
		in_obj && /"layer_id":/ { line=$0; sub(/.*"layer_id": */, "", line); sub(/,.*$/, "", line); layer_id = line }
	'
}

##
# @brief Parse chains array from JSON
# @param $1 : JSON input string
# @return Prints: tag1|tag2|tag3|... (one chain per line, pipe-separated)
json_parse_chains() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_chains=0 }
		/"chains": \[/ { in_chains=1; next }
		in_chains && /^  \]/ { in_chains=0; next }
		in_chains && /\["@/ {
			line = $0
			gsub(/^[[:space:]]*\[/, "", line)
			gsub(/\],?[[:space:]]*$/, "", line)
			gsub(/"/, "", line)
			gsub(/, /, "|", line)
			print line
		}
	'
}

##
# @brief Parse health section from JSON
# @param $1 : JSON input string
# @return Prints health statistics as key=value lines plus special formats:
#         total_tags=N
#         tags_with_links=N
#         isolated_tags=N
#         duplicate_tags=N
#         dangling_references=N
#         isolated|TAG_ID|FILE_PATH|LINE (for each isolated tag)
#         duplicate|TAG_ID|FILE_PATH|LINE (for each duplicate tag)
#         dangling|CHILD|PARENT|FILE_PATH|LINE (for each dangling ref)
json_parse_health() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN {
			in_files=0; in_file_obj=0
			in_health=0
			in_isolated_list=0
			in_duplicate_list=0
			in_dangling_list=0
		}

		# Parse files array to map file_id -> file path
		/"files": \[/ { in_files=1; next }
		in_files && /^  \],?/ { in_files=0; next }
		in_files && /^    \{/ { in_file_obj=1; file_id=""; file_path=""; next }
		in_files && in_file_obj && /^    \},?/ {
			if (file_id != "") file_map[file_id] = file_path
			in_file_obj=0
			next
		}
		in_file_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_file_obj && /"file":/ { line=$0; sub(/.*"file": *"/, "", line); sub(/".*$/, "", line); file_path = line }

		# Parse health section
		/"health": \{/ { in_health=1; next }
		in_health && /^  \},?$/ { in_health=0; next }

		in_health && /"total_tags":/ {
			line=$0; sub(/.*"total_tags": */, "", line); sub(/,.*$/, "", line)
			print "total_tags=" line
		}
		in_health && /"tags_with_links":/ {
			line=$0; sub(/.*"tags_with_links": */, "", line); sub(/,.*$/, "", line)
			print "tags_with_links=" line
		}
		in_health && /"isolated_tags":/ {
			line=$0; sub(/.*"isolated_tags": */, "", line); sub(/,.*$/, "", line)
			print "isolated_tags=" line
		}
		in_health && /"duplicate_tags":/ {
			line=$0; sub(/.*"duplicate_tags": */, "", line); sub(/,.*$/, "", line)
			print "duplicate_tags=" line
		}
		in_health && /"dangling_references":/ {
			line=$0; sub(/.*"dangling_references": */, "", line); sub(/,.*$/, "", line)
			print "dangling_references=" line
		}

		# Parse isolated_tag_list
		in_health && /"isolated_tag_list": \[/ { in_isolated_list=1; next }
		in_isolated_list && /^    \]/ { in_isolated_list=0; next }
		in_isolated_list && /\{"id":/ {
			iso_id=""; iso_fid=""; iso_line=""
			line=$0; if (index(line, "\"id\"")) { sub(/.*"id": *"/, "", line); sub(/".*$/, "", line); iso_id = line; line=$0 }
			if (index(line, "\"file_id\"")) { sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); iso_fid = line; line=$0 }
			if (index(line, "\"line\"")) { sub(/.*"line": */, "", line); sub(/[,}].*$/, "", line); iso_line = line }
			if (iso_id != "") {
				fpath = (iso_fid in file_map) ? file_map[iso_fid] : "unknown"
				print "isolated|" iso_id "|" fpath "|" iso_line
			}
		}

		# Parse duplicate_tag_list
		in_health && /"duplicate_tag_list": \[/ { in_duplicate_list=1; next }
		in_duplicate_list && /^    \]/ { in_duplicate_list=0; next }
		in_duplicate_list && /\{"id":/ {
			dup_id=""; dup_fid=""; dup_line=""
			line=$0; if (index(line, "\"id\"")) { sub(/.*"id": *"/, "", line); sub(/".*$/, "", line); dup_id = line; line=$0 }
			if (index(line, "\"file_id\"")) { sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); dup_fid = line; line=$0 }
			if (index(line, "\"line\"")) { sub(/.*"line": */, "", line); sub(/[,}].*$/, "", line); dup_line = line }
			if (dup_id != "") {
				fpath = (dup_fid in file_map) ? file_map[dup_fid] : "unknown"
				print "duplicate|" dup_id "|" fpath "|" dup_line
			}
		}

		# Parse dangling_reference_list
		in_health && /"dangling_reference_list": \[/ { in_dangling_list=1; next }
		in_dangling_list && /^    \]/ { in_dangling_list=0; next }
		in_dangling_list && /\{"child_tag":/ {
			dang_child=""; dang_parent=""; dang_fid=""; dang_line=""
			line=$0; if (index(line, "\"child_tag\"")) { sub(/.*"child_tag": *"/, "", line); sub(/".*$/, "", line); dang_child = line; line=$0 }
			if (index(line, "\"missing_parent\"")) { sub(/.*"missing_parent": *"/, "", line); sub(/".*$/, "", line); dang_parent = line; line=$0 }
			if (index(line, "\"file_id\"")) { sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); dang_fid = line; line=$0 }
			if (index(line, "\"line\"")) { sub(/.*"line": */, "", line); sub(/[,}].*$/, "", line); dang_line = line }
			if (dang_child != "" && dang_parent != "") {
				fpath = (dang_fid in file_map) ? file_map[dang_fid] : "unknown"
				print "dangling|" dang_child "|" dang_parent "|" fpath "|" dang_line
			}
		}
	'
}

##
# @brief Parse coverage data from JSON health section
# @param $1 : JSON input string
# @return Prints coverage data in two formats:
#         layer|NAME|TOTAL|UP_COUNT|DOWN_COUNT|UP_PCT|DOWN_PCT
#         file|LAYER|FILE_PATH|TOTAL|UP_COUNT|DOWN_COUNT|UP_PCT|DOWN_PCT|VERSION
json_parse_coverage() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN {
			in_files=0; in_file_entry=0
			in_coverage=0; in_layers=0; in_layer_obj=0
			in_upstream_obj=0; in_downstream_obj=0
			in_layer_files=0; in_file_obj=0
			in_file_upstream=0; in_file_downstream=0
			current_layer_name=""
		}

		# Parse top-level files array for file_id mapping
		/"files": \[/ && !in_coverage { in_files=1; next }
		in_files && /^  \],?$/ { in_files=0; next }
		in_files && /^    \{/ { in_file_entry=1; file_id=""; file_path=""; next }
		in_files && in_file_entry && /^    \},?$/ {
			if (file_id != "") file_map[file_id] = file_path
			in_file_entry=0
			next
		}
		in_file_entry && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_file_entry && /"file":/ { line=$0; sub(/.*"file": *"/, "", line); sub(/".*$/, "", line); file_path = line }

		# Parse coverage section
		/"coverage": \{/ { in_coverage=1; next }
		in_coverage && /^    \}/ { in_coverage=0; next }
		in_coverage && /"layers": \[/ { in_layers=1; next }
		in_layers && /^      \],?$/ { in_layers=0; next }

		# Layer object
		in_layers && /^        \{/ {
			in_layer_obj=1
			name=""; total=""; up_count=""; down_count=""; up_pct=""; down_pct=""
			next
		}
		in_layers && in_layer_obj && /^        \},?$/ {
			if (name != "") {
				print "layer|" name "|" total "|" up_count "|" down_count "|" up_pct "|" down_pct
			}
			in_layer_obj=0
			current_layer_name=""
			next
		}
		in_layer_obj && /"name":/ {
			line=$0; sub(/.*"name": *"/, "", line); sub(/".*$/, "", line)
			name = line
			current_layer_name = line
		}
		in_layer_obj && /"total":/ && !in_upstream_obj && !in_downstream_obj && !in_layer_files {
			line=$0; sub(/.*"total": */, "", line); sub(/,.*$/, "", line)
			total = line
		}

		# Layer upstream object
		in_layer_obj && /"upstream": \{/ && !in_layer_files { in_upstream_obj=1; next }
		in_upstream_obj && /^          \},?$/ { in_upstream_obj=0; next }
		in_upstream_obj && /"count":/ { line=$0; sub(/.*"count": */, "", line); sub(/,.*$/, "", line); up_count = line }
		in_upstream_obj && /"percent":/ { line=$0; sub(/.*"percent": */, "", line); sub(/,.*$/, "", line); up_pct = line }

		# Layer downstream object
		in_layer_obj && /"downstream": \{/ && !in_layer_files { in_downstream_obj=1; next }
		in_downstream_obj && /^          \},?$/ { in_downstream_obj=0; next }
		in_downstream_obj && /"count":/ { line=$0; sub(/.*"count": */, "", line); sub(/,.*$/, "", line); down_count = line }
		in_downstream_obj && /"percent":/ { line=$0; sub(/.*"percent": */, "", line); sub(/,.*$/, "", line); down_pct = line }

		# Files array within layer
		in_layer_obj && /"files": \[/ { in_layer_files=1; in_file_obj=0; next }
		in_layer_files && /^          \],?$/ { in_layer_files=0; next }
		in_layer_files && /^            \{/ {
			in_file_obj=1
			file_id_local=""; file_total=""; file_up_count=""; file_down_count=""
			file_up_pct=""; file_down_pct=""; version=""
			next
		}
		in_layer_files && in_file_obj && /^            \},?$/ {
			if (file_id_local != "") {
				fpath = (file_id_local in file_map) ? file_map[file_id_local] : "unknown"
				print "file|" current_layer_name "|" fpath "|" file_total "|" file_up_count "|" file_down_count "|" file_up_pct "|" file_down_pct "|" version
			}
			in_file_obj=0
			next
		}
		in_file_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id_local = line }
		in_file_obj && /"total":/ && !in_file_upstream && !in_file_downstream {
			line=$0; sub(/.*"total": */, "", line); sub(/,.*$/, "", line); file_total = line
		}

		# File upstream object
		in_file_obj && /"upstream": \{/ { in_file_upstream=1; next }
		in_file_upstream && /^              \},?$/ { in_file_upstream=0; next }
		in_file_upstream && /"count":/ { line=$0; sub(/.*"count": */, "", line); sub(/,.*$/, "", line); file_up_count = line }
		in_file_upstream && /"percent":/ { line=$0; sub(/.*"percent": */, "", line); sub(/,.*$/, "", line); file_up_pct = line }

		# File downstream object
		in_file_obj && /"downstream": \{/ { in_file_downstream=1; next }
		in_file_downstream && /^              \},?$/ { in_file_downstream=0; next }
		in_file_downstream && /"count":/ { line=$0; sub(/.*"count": */, "", line); sub(/,.*$/, "", line); file_down_count = line }
		in_file_downstream && /"percent":/ { line=$0; sub(/.*"percent": */, "", line); sub(/,.*$/, "", line); file_down_pct = line }

		in_file_obj && /"version":/ { line=$0; sub(/.*"version": *"/, "", line); sub(/".*$/, "", line); version = line }
	'
}

##
# @brief Extract layer names in order from JSON
# @param $1 : JSON input string
# @return Prints layer names, one per line, in definition order
json_get_layer_order() {
	_json="$1"

	printf '%s\n' "$_json" | awk '
		BEGIN { in_layers=0; in_obj=0 }
		/"layers": \[/ && !in_layers { in_layers=1; next }
		in_layers && /^  \],?$/ { in_layers=0; exit }
		in_layers && /^    \{/ { in_obj=1; next }
		in_layers && in_obj && /^    \},?$/ { in_obj=0; next }
		in_obj && /"name":/ {
			line=$0; sub(/.*"name": *"/, "", line); sub(/".*$/, "", line)
			if (line != "") print line
		}
	'
}

##
# @brief Get full layer name from abbreviation
# @param $1 : JSON input string
# @param $2 : Layer abbreviation (e.g., "REQ", "ARC")
# @return Full layer name (e.g., "Requirement", "Architecture") or abbreviation if not found
json_get_layer_display_name() {
	_json="$1"
	_abbrev="$2"

	printf '%s\n' "$_json" | awk -v abbrev="$_abbrev" '
		BEGIN { in_layers=0; in_obj=0; found="" }
		/"layers":/ && /\[/ { in_layers=1; next }
		in_layers && /^\s*\]/ { in_layers=0; next }
		in_layers && /^\s*\{/ { in_obj=1; layer_name=""; next }
		in_obj && /"name":/ {
			line=$0; sub(/.*"name"[[:space:]]*:[[:space:]]*"/, "", line); sub(/".*$/, "", line)
			layer_name = line
		}
		in_obj && /^\s*\}/ {
			in_obj=0
			if (layer_name != "") {
				if (tolower(layer_name) ~ "^" tolower(abbrev)) {
					if (found == "") found = layer_name
				}
			}
		}
		END { print (found != "") ? found : abbrev }
	'
}

##
# @brief Format version string for display
# @param $1 : Version string (e.g., "git:abc1234" or "mtime:2025-12-26T10:30:45Z")
# @return Formatted display string (e.g., "abc1234" or "2025-12-26 10:30")
json_format_version_display() {
	_version="$1"

	case "$_version" in
		git:*)
			# git:abc1234 -> abc1234
			printf '%s' "${_version#git:}"
			;;
		mtime:*)
			# mtime:2025-12-26T10:30:45Z -> 2025-12-26 10:30
			_ts="${_version#mtime:}"
			printf '%s' "$_ts" | sed 's/T/ /; s/:[0-9][0-9]Z$//'
			;;
		"" | "unknown")
			printf 'unknown'
			;;
		*)
			printf '%s' "$_version"
			;;
	esac
}
