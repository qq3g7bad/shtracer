#!/bin/sh

# For unit test
_SHTRACER_VERIFY_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*shtracer_verify*)
		: # Successfully sourced (zsh sets $0 to sourced file).
		;;
	*)
		echo "This script should only be sourced, not executed directly."
		exit 1
		;;
esac

##
# @brief  Print traceability summary based on direct links only (02_tag_pairs)
# @param  $1 : TAG_OUTPUT_DATA path (01_tags)
# @param  $2 : TAG_PAIRS path (02_tag_pairs)
# @return  Prints summary lines to stdout
print_summary_direct_links() {
	if [ $# -ne 3 ] || [ ! -r "$1" ] || [ ! -r "$2" ] || [ ! -r "$3" ]; then
		error_exit 1 "print_summary_direct_links" "incorrect argument."
	fi

	_TAGS_FILE="$1"
	_TAG_PAIRS_FILE="$2"
	_FILE_VERSIONS_FILE="$3"

	# Output format:
	#   <layer>
	#     upstream: <target layer> <pct>, ...
	#     downstream: <target layer> <pct>, ...
	# Notes:
	# - Uses direct links only.
	# - Treats links as undirected.
	# - Computes upstream/downstream projections independently (relative to layer order).
	# - For nodes connected to multiple target layers on a side, split 1 equally across distinct target layers.
	# - Percent formatting matches the Type diagram labels.
	awk \
		-v SEP="$SHTRACER_SEPARATOR" \
		-v TAGS_FILE="$_TAGS_FILE" \
		-v VERSIONS_FILE="$_FILE_VERSIONS_FILE" \
		\
		"$AWK_FN_TRIM"'
		'"$AWK_FN_GET_LAST_SEGMENT"'
		function fmt_pct(value, total,   p, s) {
			if (total <= 0) { return "" }
			p = (value / total) * 100
			if (p > 0 && p < 0.5) { return "<1%" }
			if (p >= 10) { s = sprintf("%.0f", p) }
			else { s = sprintf("%.1f", p) }
			sub(/[.]0$/, "", s)
			return s "%"
		}
		BEGIN {
			# First pass: load tag->layer from 01_tags
			while ((getline line < TAGS_FILE) > 0) {
				n = split(line, f, SEP)
				if (n < 2) { continue }
				tag = trim(f[2])
				if (tag == "" || tag == "NONE") { continue }
				layer = trim(get_last_segment(f[1]))
				if (layer == "") { continue }
				if (!(tag in tag2layer)) {
					tag2layer[tag] = layer
					layerN[layer]++
					layers[layer] = 1
				}
			}
			close(TAGS_FILE)

	# Load file versions and track unique files per layer
	while ((getline line < VERSIONS_FILE) > 0) {
		n = split(line, f, SEP)
		if (n < 3) { continue }
		trace_target = trim(f[1])
		file_path = trim(f[2])
		version = trim(f[3])
		key = trace_target SEP file_path
		file_versions[key] = version

		# Track unique files per layer
		layer = trim(get_last_segment(trace_target))
		if (layer != "") {
			file_key = layer SEP file_path
			if (!(file_key in layer_files_seen)) {
				layer_files_seen[file_key] = 1
				idx = layer_file_count[layer]++
				layer_files[layer, idx] = file_path
				layer_trace_targets[layer, idx] = trace_target
			}
		}
	}
	close(VERSIONS_FILE)

			# Preferred stable order
			order[1] = "Requirement"
			order[2] = "Architecture"
			order[3] = "Implementation"
			order[4] = "Unit test"
			order[5] = "Integration test"
			for (i = 1; i <= 5; i++) {
				ord[order[i]] = i
			}
		}
		{
			# Second pass (main input): 02_tag_pairs (space separated)
			tagA = $1
			tagB = $2
			if (tagA == "" || tagB == "") { next }
			if (tagA == "NONE" || tagB == "NONE") { next }
			if (!(tagA in tag2layer) || !(tagB in tag2layer)) { next }
			la = tag2layer[tagA]
			lb = tag2layer[tagB]
			if (la == "" || lb == "") { next }
			if (la == lb) { next }
			if (!(la in ord) || !(lb in ord)) { next }

			# Undirected, but categorize per endpoint as upstream/downstream by layer order.
			# Endpoint A
			if (ord[lb] < ord[la]) {
				k = tagA SUBSEP lb
				if (!(k in hasUp)) { hasUp[k] = 1; upcnt[tagA]++ }
			} else if (ord[lb] > ord[la]) {
				k = tagA SUBSEP lb
				if (!(k in hasDown)) { hasDown[k] = 1; downcnt[tagA]++ }
			}
			# Endpoint B
			if (ord[la] < ord[lb]) {
				k = tagB SUBSEP la
				if (!(k in hasUp)) { hasUp[k] = 1; upcnt[tagB]++ }
			} else if (ord[la] > ord[lb]) {
				k = tagB SUBSEP la
				if (!(k in hasDown)) { hasDown[k] = 1; downcnt[tagB]++ }
			}
		}
		END {
			# Accumulate split-mass per layer side (up/down) and target layer
			for (k in hasUp) {
				split(k, parts, SUBSEP)
				tag = parts[1]
				tgt = parts[2]
				src = tag2layer[tag]
				if (src == "" || tgt == "") { continue }
				if (upcnt[tag] <= 0) { continue }
				accUp[src SUBSEP tgt] += (1.0 / upcnt[tag])
				hasAccUp[src SUBSEP tgt] = 1
			}
			for (k in hasDown) {
				split(k, parts, SUBSEP)
				tag = parts[1]
				tgt = parts[2]
				src = tag2layer[tag]
				if (src == "" || tgt == "") { continue }
				if (downcnt[tag] <= 0) { continue }
				accDown[src SUBSEP tgt] += (1.0 / downcnt[tag])
				hasAccDown[src SUBSEP tgt] = 1
			}

			# Emit summary per layer (no totals). Upstream and downstream in stable order.
			for (i = 1; i <= 5; i++) {
				src = order[i]
				N = layerN[src] + 0
				if (N <= 0) { continue }

				# Determine if this layer has any upstream/downstream targets
				hasLine = 0
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j >= i) { continue }
					if ((src SUBSEP tgt) in hasAccUp) { hasLine = 1 }
				}
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j <= i) { continue }
					if ((src SUBSEP tgt) in hasAccDown) { hasLine = 1 }
				}
				if (!hasLine) { continue }

				print src

				# Display file information for this layer
				if (layer_file_count[src] > 0) {
					print "  files:"
					for (file_idx = 0; file_idx < layer_file_count[src]; file_idx++) {
						file_path = layer_files[src, file_idx]
						trace_target = layer_trace_targets[src, file_idx]
						# Get basename for display
						n_slash = split(file_path, path_parts, "/")
						file_name = path_parts[n_slash]

						# Get version info
						key = trace_target SEP file_path
						version_raw = file_versions[key]

						# Format version for display
						if (version_raw ~ /^git:/) {
							version_display = substr(version_raw, 5)  # Remove "git:" prefix
						} else if (version_raw ~ /^mtime:/) {
							# Convert "mtime:2025-12-26T10:30:45Z" to "2025-12-26 10:30"
							timestamp = substr(version_raw, 7)  # Remove "mtime:" prefix
							sub(/T/, " ", timestamp)
							sub(/:[0-9][0-9]Z$/, "", timestamp)
							version_display = timestamp
						} else {
							version_display = version_raw
						}

						printf "    - %s (%s)\n", file_name, version_display
					}
				}

				# upstream: reverse order (closest previous layer first visually)
				upStr = ""
				for (j = 5; j >= 1; j--) {
					tgt = order[j]
					if (j >= i) { continue }
					key = src SUBSEP tgt
					if (!(key in hasAccUp)) { continue }
					part = tgt " " fmt_pct(accUp[key] + 0, N)
					if (upStr == "") upStr = part
					else upStr = upStr ", " part
				}
				if (upStr != "") {
					print "  upstream: " upStr
				}

				# downstream: forward order
				downStr = ""
				for (j = 1; j <= 5; j++) {
					tgt = order[j]
					if (j <= i) { continue }
					key = src SUBSEP tgt
					if (!(key in hasAccDown)) { continue }
					part = tgt " " fmt_pct(accDown[key] + 0, N)
					if (downStr == "") downStr = part
					else downStr = downStr ", " part
				}
				if (downStr != "") {
					print "  downstream: " downStr
				}
			}
		}
		' <"$_TAG_PAIRS_FILE"
}

##
# @brief  Check if a verification file contains issues
# @param  $1 : File path to check
# @param  $2 : Issue type ("isolated" requires NODATA_STRING check, others just line count)
# @return 0 if no issues, 1 if issues found
_check_verification_file() {
	_file="$1"
	_type="$2"

	[ -r "$_file" ] || return 0

	_line_count="$(wc <"$_file" -l | tr -d ' \t')"
	[ "$_line_count" -eq 0 ] && return 0

	# For isolated tags, also check if content is just NODATA_STRING
	if [ "$_type" = "isolated" ]; then
		[ "$(cat "$_file")" = "$NODATA_STRING" ] && return 0
	fi

	return 1
}

##
# @brief  Print isolated tag errors in one-line format
# @param  $1 : ISOLATED file path
# @return None (prints to stderr)
_print_isolated_errors() {
	_isolated_file="$1"
	[ -r "$_isolated_file" ] || return 0
	[ -s "$_isolated_file" ] || return 0

	# Read detailed file and emit one line per error
	# Format: NONE tag file line -> [shtracer][error][isolated_tags] tag file line
	while IFS=' ' read -r _none _tag _file _line; do
		[ "$_none" = "$NODATA_STRING" ] || continue
		printf "[shtracer][error][isolated_tags] %s %s %s\n" "$_tag" "$_file" "$_line" 1>&2
	done <"$_isolated_file"
}

##
# @brief  Print duplicate tag errors in one-line format
# @param  $1 : DUPLICATED file path (just tag IDs)
# @param  $2 : TAG_OUTPUT_DATA file path (01_tags with full tag info)
# @return None (prints to stderr)
_print_duplicated_errors() {
	_dup_file="$1"
	_tag_data="$2"

	[ -r "$_dup_file" ] || return 0
	[ -s "$_dup_file" ] || return 0
	[ -r "$_tag_data" ] || return 0

	# Process each unique duplicate tag using awk (avoids subshell issues)
	awk -F"$SHTRACER_SEPARATOR" -v dup_file="$_dup_file" '
		BEGIN {
			# Read duplicate tag IDs into array
			while ((getline < dup_file) > 0) {
				if ($0 != "") {
					dup_tags[$0] = 1
				}
			}
			close(dup_file)
		}
		{
			# Check if this tag ID is in the duplicates list
			tag_id = $2
			file = $5
			line = $6
			if (tag_id in dup_tags) {
				printf "[shtracer][error][duplicated_tags] %s %s %s\n", tag_id, file, line
			}
		}
	' "$_tag_data" 1>&2
}

##
# @brief  Print dangling tag errors in one-line format
# @param  $1 : DANGLING file path
# @return None (prints to stderr)
_print_dangling_errors() {
	_dangling_file="$1"
	[ -r "$_dangling_file" ] || return 0
	[ -s "$_dangling_file" ] || return 0

	# Read detailed file and emit one line per error
	# Format: child_tag parent_tag file line -> [shtracer][error][dangling_tags] child parent file line
	while IFS=' ' read -r _child _parent _file _line; do
		printf "[shtracer][error][dangling_tags] %s %s %s %s\n" "$_child" "$_parent" "$_file" "$_line" 1>&2
	done <"$_dangling_file"
}

##
# @brief  Display tag verification results in one-line-per-error format
# @param  $1 : TAG_OUTPUT_DATA file path (01_tags with full tag info)
# @param  $2 : ISOLATED file path
# @param  $3 : DUPLICATED file path
# @param  $4 : DANGLING file path
# @return None (prints to stderr only, no return code)
# @tag    @IMP2.5@ (FROM: @ARC2.5@)
print_verification_result() {
	_tag_data="$1"
	_isolated_file="$2"
	_duplicated_file="$3"
	_dangling_file="$4"

	# Print errors in one-line format (all detected issues)
	_print_isolated_errors "$_isolated_file"
	_print_duplicated_errors "$_duplicated_file" "$_tag_data"
	_print_dangling_errors "$_dangling_file"
}
