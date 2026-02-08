#!/bin/sh

# For unit test
_SHTRACER_JSON_EXPORT_SH=""

case "$0" in
	*shtracer)
		: # Successfully sourced from shtracer.
		;;
	*shtracer*test*)
		: # Successfully sourced from shtracer.
		;;
	*shtracer_json_export*)
		: # Successfully sourced (zsh sets $0 to sourced file).
		;;
	*)
		echo "This script should only be sourced, not executed directly."
		exit 1
		;;
esac

##
# ============================================================================
# JSON Generation Helper Functions
# ============================================================================
##

##
# @brief  Emit JSON metadata section
# @param  $1 : Version string (SHTRACER_VERSION)
# @param  $2 : Timestamp (ISO 8601 format)
# @param  $3 : Config path
# @return JSON metadata section to stdout
# @tag    @IMP2.6.3@ (FROM: @ARC2.6@)
_json_emit_metadata() {
	_version="$1"
	_timestamp="$2"
	_config_path="$3"

	printf '{\n'
	printf '  "metadata": {\n'
	printf '    "version": "%s",\n' "$_version"
	printf '    "generated": "%s",\n' "$_timestamp"
	printf '    "config_path": "%s"\n' "$_config_path"
	printf '  },\n'
}

##
# @brief  Emit JSON chains array from tag table
# @param  $1 : TAG_TABLE file path (04_tag_table)
# @return JSON chains array to stdout
# @tag    @IMP2.6.4@ (FROM: @ARC2.6@)
_json_emit_chains() {
	_tag_table="$1"

	printf '  "chains": [\n'
	awk '
	BEGIN { first=1 }
	{
		if (!first) printf ",\n"
		first=0
		printf "    ["
		for (i=1; i<=NF; i++) {
			if (i > 1) printf ", "
			printf "\"%s\"", $i
		}
		printf "]"
	}
	' "$_tag_table"
	printf '\n  ],\n'
}

##
# @brief  Generate JSON output for traceability data
# @param  $1 : TAG_OUTPUT_DATA (01_tags file path)
# @param  $2 : TAG_PAIRS (02_tag_pairs file path)
# @param  $3 : TAG_PAIRS_DOWNSTREAM (03_tag_pairs_downstream file path)
# @param  $4 : TAG_TABLE (04_tag_table file path)
# @param  $5 : CONFIG_TABLE (01_config_table file path)
# @param  $6 : CONFIG_PATH (config file path)
# @param  $7 : XREF_DIR (cross-reference directory path, optional)
# @return JSON_OUTPUT_FILENAME
make_json() {
	_TAG_OUTPUT_DATA="$1"
	_TAG_PAIRS="$2"
	_TAG_PAIRS_DOWNSTREAM="$3"
	_TAG_TABLE="$4"
	_CONFIG_TABLE="$5"
	_CONFIG_PATH="$6"
	_XREF_DIR="${7:-}"

	_JSON_OUTPUT_FILENAME="${OUTPUT_DIR%/}/output.json"
	_ISOLATED_FILE="${OUTPUT_DIR%/}/tags/verified/10_isolated_fromtag"
	_DUPLICATED_FILE="${OUTPUT_DIR%/}/tags/verified/11_duplicated"
	_DANGLING_FILE="${OUTPUT_DIR%/}/tags/verified/12_dangling_fromtag"

	# Generate timestamp
	_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

	# Start JSON structure
	{
		# Emit metadata section
		_json_emit_metadata "$SHTRACER_VERSION" "$_TIMESTAMP" "$_CONFIG_PATH"

		printf '  "verificationErrors": '
		awk -v tag_output_data="$_TAG_OUTPUT_DATA" \
			-v sep="$SHTRACER_SEPARATOR" \
			-v isolated_file="$_ISOLATED_FILE" \
			-v duplicated_file="$_DUPLICATED_FILE" \
			-v dangling_file="$_DANGLING_FILE" \
			"$AWK_FN_JSON_ESCAPE"'
		'"$AWK_FN_TRIM"'
		BEGIN {
			while ((getline line < isolated_file) > 0) {
				_np = split(line, parts, " ")
				if (_np >= 2 && parts[2] != "") {
					isolated[parts[2]] = 1
				}
			}
			close(isolated_file)

			while ((getline line < duplicated_file) > 0) {
				line = trim(line)
				if (line != "") {
					duplicates[line] = 1
				}
			}
			close(duplicated_file)

			while ((getline line < dangling_file) > 0) {
				_np = split(line, parts, " ")
				if (_np >= 4) {
					d_child[d_count] = parts[1]
					d_parent[d_count] = parts[2]
					d_file[d_count] = parts[3]
					d_line[d_count] = parts[4]
					d_count++
				}
			}
			close(dangling_file)

			while ((getline line < tag_output_data) > 0) {
				_nf = split(line, fields, sep)
				if (_nf >= 8) {
					tag_id = fields[2]
					file_path = fields[5]
					line_num = fields[6]

					if (!(file_path in file_to_id)) {
						file_to_id[file_path] = file_id
						file_id++
					}

					if (tag_id in isolated) {
						iso_count++
						iso_tag[iso_count] = tag_id
						iso_file[iso_count] = file_path
						iso_line[iso_count] = line_num
					}

					if (tag_id in duplicates) {
						dup_count++
						dup_tag[dup_count] = tag_id
						dup_file[dup_count] = file_path
						dup_line[dup_count] = line_num
					}
				}
			}
			close(tag_output_data)

			print "{"
			print "    \"isolated\": ["
			first = 1
			for (i = 1; i <= iso_count; i++) {
				if (!first) print ","
				first = 0
				tag = json_escape(iso_tag[i])
				file_path = iso_file[i]
				fid = (file_path in file_to_id) ? file_to_id[file_path] : -1
				line_num = iso_line[i]
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"id\": \"%s\", \"file_id\": %d, \"line\": %d}", tag, fid, line_num
			}
			print "\n    ],"

			print "    \"duplicates\": ["
			first = 1
			for (i = 1; i <= dup_count; i++) {
				if (!first) print ","
				first = 0
				tag = json_escape(dup_tag[i])
				file_path = dup_file[i]
				fid = (file_path in file_to_id) ? file_to_id[file_path] : -1
				line_num = dup_line[i]
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"id\": \"%s\", \"file_id\": %d, \"line\": %d}", tag, fid, line_num
			}
			print "\n    ],"

			print "    \"dangling\": ["
			first = 1
			for (i = 0; i < d_count; i++) {
				if (!first) print ","
				first = 0
				child_tag = json_escape(d_child[i])
				parent_tag = json_escape(d_parent[i])
				file_path = d_file[i]
				fid = (file_path in file_to_id) ? file_to_id[file_path] : -1
				line_num = d_line[i]
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"child_tag\": \"%s\", \"missing_parent\": \"%s\", \"file_id\": %d, \"line\": %d}", child_tag, parent_tag, fid, line_num
			}
			print "\n    ]"
			print "  }"
		}'
		printf ',\n'

		# NEW: Generate files array and layers array first, then collect stats
		# This requires reading all data upfront in one AWK pass

		# Calculate all data (files, layers, trace_tags, health) in one AWK pass
		awk -v tag_output_data="$_TAG_OUTPUT_DATA" \
			-v tag_pairs="$_TAG_PAIRS" \
			-v tag_pairs_downstream="$_TAG_PAIRS_DOWNSTREAM" \
			-v config_table="$_CONFIG_TABLE" \
			-v sep="$SHTRACER_SEPARATOR" \
			-v output_dir="${OUTPUT_DIR%/}" \
			"$AWK_FN_JSON_ESCAPE"'

BEGIN {
	# STEP 1: Read layer order AND patterns from config table
	n_layers = 0
	while ((getline line < config_table) > 0) {
		_nf = split(line, fields, sep)
		if (_nf >= 6 && fields[1] != "") {
			# Extract layer name: last component after last colon
			layer = fields[1]
			sub(/^:/, "", layer)
			sub(/.*:/, "", layer)

			# Extract TAG FORMAT pattern (field 6)
			tag_pattern = fields[6]
			gsub(/^`|`$|^"|"$/, "", tag_pattern)  # Remove backticks/quotes

			# Record layer order and pattern (skip duplicates)
			if (layer != "" && tag_pattern != "" && !(layer in layer_order)) {
				layer_order[layer] = n_layers
				layer_pattern[layer] = tag_pattern
				ordered_layers[n_layers] = layer
				n_layers++
			}
		}
	}
	close(config_table)

		# STEP 2: Read all tags AND build global file mapping
		global_file_id = 0
		while ((getline line < tag_output_data) > 0) {
			_nf = split(line, fields, sep)
			if (_nf >= 8) {
				tag_id = fields[2]
				all_tags[tag_id] = 1
				tag_from[tag_id] = fields[3]  # NEW: Store from_tag
				tag_desc[tag_id] = fields[4]
				tag_file[tag_id] = fields[5]
				tag_line[tag_id] = fields[6]
				tag_target[tag_id] = fields[1]
				tag_version[tag_id] = fields[8]
				total_tags++

				# Build global file mapping (use full path to avoid basename collisions)
				file_path = fields[5]
				n_slash = split(file_path, path_parts, "/")
				basename = path_parts[n_slash]

				if (!(file_path in file_mapping)) {
					file_mapping[file_path] = global_file_id
					file_id_to_path[global_file_id] = file_path
					file_id_to_version[global_file_id] = fields[8]
					global_file_id++
				}
			}
		}
		close(tag_output_data)

			# STEP 3: Build layer-to-files relationship
			for (tag in all_tags) {
				target = tag_target[tag]
				# Extract layer from target (remove leading ":", take last segment)
				layer = target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)

				file_path = tag_file[tag]
				file_id = file_mapping[file_path]

				# Add to layer_files mapping (unique)
				key = layer SUBSEP file_id
				if (!(key in layer_has_file)) {
					layer_has_file[key] = 1
					if (layer_files[layer] == "") {
						layer_files[layer] = file_id
					} else {
						layer_files[layer] = layer_files[layer] "," file_id
					}
				}
			}

			# Read tags with links (source tags from pairs)
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE" && fields[2] != "NONE" && fields[1] in all_tags && fields[2] in all_tags) {
					tags_with_links[fields[1]] = 1
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE" && fields[2] != "NONE" && fields[1] in all_tags && fields[2] in all_tags) {
					tags_with_links[fields[1]] = 1
				}
			}
			close(tag_pairs_downstream)

			# Read dangling FROM tag references (file format: child_tag parent_tag file line)
			dangling_file = output_dir "/tags/verified/12_dangling_fromtag"
			dangling_count = 0
			while ((getline line < dangling_file) > 0) {
				_nf = split(line, fields, " ")
				if (_nf >= 4) {
					dangling_child[dangling_count] = fields[1]
					dangling_parent[dangling_count] = fields[2]
					dangling_file_path[dangling_count] = fields[3]
					dangling_line[dangling_count] = fields[4]
					dangling_count++
				}
			}
			close(dangling_file)

			# Count tags with links
			tags_with_links_count = 0
			for (tag in tags_with_links) {
				tags_with_links_count++
			}

			# Calculate isolated tags
			isolated_count = 0
			for (tag in all_tags) {
				if (!(tag in tags_with_links)) {
					isolated_tags[isolated_count++] = tag
				}
			}

			# Build tag-to-layer mapping
			for (tag in all_tags) {
				trace_target = tag_target[tag]
				# Extract layer name (last component after colon)
				layer = trace_target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)
				tag_to_layer[tag] = layer

				# Track full file path (needed for unique IDs)
				file_path = tag_file[tag]
				tag_to_file[tag] = file_path
			}

			# Build directed reference tracking
			# Tag pair format: "src tgt" means "tgt references src" (tgt has FROM: src)
			# references[tag] = tags this tag references (outgoing: this tag -> other tags)
			# referenced_by[tag] = tags that reference this tag (incoming: other tags -> this tag)

			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					# tgt references src (tgt has FROM: src)
					# So: tgt -> src (outgoing from tgt)
					#     src <- tgt (incoming to src)

					# Add to tgt references list (tgt references src)
					if (references[tgt] == "") {
						references[tgt] = src
					} else {
						if (index(references[tgt], src) == 0) {
							references[tgt] = references[tgt] ";" src
						}
					}

					# Add to src referenced_by list (src is referenced by tgt)
					if (referenced_by[src] == "") {
						referenced_by[src] = tgt
					} else {
						if (index(referenced_by[src], tgt) == 0) {
							referenced_by[src] = referenced_by[src] ";" tgt
						}
					}
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					# tgt references src (same semantics as above)

					# Add to tgt references list (avoid duplicates)
					if (references[tgt] == "") {
						references[tgt] = src
					} else {
						if (index(references[tgt], src) == 0) {
							references[tgt] = references[tgt] ";" src
						}
					}

					# Add to src referenced_by list (avoid duplicates)
					if (referenced_by[src] == "") {
						referenced_by[src] = tgt
					} else {
						if (index(referenced_by[src], tgt) == 0) {
							referenced_by[src] = referenced_by[src] ";" tgt
						}
					}
				}
			}
			close(tag_pairs_downstream)

			# Calculate coverage for each tag
			for (tag in all_tags) {
				layer = tag_to_layer[tag]
				file_path = tag_to_file[tag]
				n_slash = split(file_path, path_parts, "/")
				file_basename = path_parts[n_slash]

				# Skip if layer not in order or if config.md
				if (!(layer in layer_order) || file_basename == "config.md") continue

				my_order = layer_order[layer]

				# Count nodes per layer
				layer_total[layer]++

				# Count nodes per file (use full path as key to avoid collisions)
				file_key = layer "|" file_path
				file_total[file_key]++

				# Store version on first encounter
				if (file_version[file_key] == "") {
					file_version[file_key] = tag_version[tag]
				}

				# Find connected layers for this tag
				up_layers_str = ""
				down_layers_str = ""
				has_up = 0
				has_down = 0

				# Upstream coverage: tags in earlier layers that I reference
				# (I have FROM: pointing to them)
				if (references[tag] != "") {
					n_refs = split(references[tag], ref_arr, ";")
					for (j = 1; j <= n_refs; j++) {
						ref_tag = ref_arr[j]
						ref_layer = tag_to_layer[ref_tag]

						if (ref_layer == "" || ref_layer == layer) continue
						if (!(ref_layer in layer_order)) continue

						ref_order = layer_order[ref_layer]

						# Only count if reference is to an earlier layer
						if (ref_order < my_order) {
							has_up = 1
							if (index(up_layers_str, ref_layer) == 0) {
								up_layers_str = up_layers_str (up_layers_str ? "," : "") ref_layer
							}
						}
					}
				}

				# Downstream coverage: tags in later layers that reference me
				# (later tags have FROM: pointing to me)
				if (referenced_by[tag] != "") {
					n_refby = split(referenced_by[tag], refby_arr, ";")
					for (j = 1; j <= n_refby; j++) {
						refby_tag = refby_arr[j]
						refby_layer = tag_to_layer[refby_tag]

						if (refby_layer == "" || refby_layer == layer) continue
						if (!(refby_layer in layer_order)) continue

						refby_order = layer_order[refby_layer]

						# Only count if referencer is in a later layer
						if (refby_order > my_order) {
							has_down = 1
							if (index(down_layers_str, refby_layer) == 0) {
								down_layers_str = down_layers_str (down_layers_str ? "," : "") refby_layer
							}
						}
					}
				}

				# Track upstream/downstream connections for layers
				if (up_layers_str != "") {
					n_up = split(up_layers_str, up_arr, ",")
					layer_up_count[layer]++

					# Track connected target layers
					for (k = 1; k <= n_up; k++) {
						target_layer = up_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_up_targets)) {
							layer_up_targets[key] = 1
						}
					}
				}

				if (down_layers_str != "") {
					n_down = split(down_layers_str, down_arr, ",")
					layer_down_count[layer]++

					# Track connected target layers
					for (k = 1; k <= n_down; k++) {
						target_layer = down_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_down_targets)) {
							layer_down_targets[key] = 1
						}
					}
				}

				# Count files with upstream/downstream connections
				if (has_up) file_up[file_key] = (file_up[file_key] + 0) + 1
				if (has_down) file_down[file_key] = (file_down[file_key] + 0) + 1
		}

		# STEP 4: Output files array (top-level, globally unique file_id)
		printf "  \"files\": [\n"
		for (fid = 0; fid < global_file_id; fid++) {
			if (fid > 0) printf ",\n"
			printf "    {\n"
			printf "      \"file_id\": %d,\n", fid
			printf "      \"file\": \"%s\",\n", json_escape(file_id_to_path[fid])
			printf "      \"version\": \"%s\"\n", json_escape(file_id_to_version[fid])
			printf "    }"
		}
		printf "\n  ],\n"

		# STEP 5: Output layers array
		printf "  \"layers\": [\n"
		layer_id = 0
		layer_printed = 0
		for (layer_idx = 0; layer_idx < n_layers; layer_idx++) {
			layer = ordered_layers[layer_idx]
			if (!(layer in layer_total)) continue

			total = layer_total[layer]

			# Build upstream_layers array
			up_layers_arr = ""
			for (j = 0; j < n_layers; j++) {
				target = ordered_layers[j]
				key = layer SUBSEP target
				if (key in layer_up_targets) {
					if (up_layers_arr != "") up_layers_arr = up_layers_arr ", "
					up_layers_arr = up_layers_arr "\"" target "\""
				}
			}

			# Build downstream_layers array
			down_layers_arr = ""
			for (j = 0; j < n_layers; j++) {
				target = ordered_layers[j]
				key = layer SUBSEP target
				if (key in layer_down_targets) {
					if (down_layers_arr != "") down_layers_arr = down_layers_arr ", "
					down_layers_arr = down_layers_arr "\"" target "\""
				}
			}

			if (layer_printed) printf ",\n"
			layer_printed = 1

			printf "    {\n"
			printf "      \"layer_id\": %d,\n", layer_id
			printf "      \"name\": \"%s\",\n", json_escape(layer)
			printf "      \"pattern\": \"%s\",\n", json_escape(layer_pattern[layer])

			# Output file_ids array
			printf "      \"file_ids\": ["
			if (layer_files[layer] != "") {
				n_fids = split(layer_files[layer], fids, ",")
				for (fid_idx = 1; fid_idx <= n_fids; fid_idx++) {
					if (fid_idx > 1) printf ", "
					printf "%d", fids[fid_idx]
				}
			}
			printf "],\n"

			printf "      \"total_tags\": %d,\n", total
			printf "      \"upstream_layers\": [%s],\n", up_layers_arr
			printf "      \"downstream_layers\": [%s]\n", down_layers_arr
			printf "    }"

			layer_id++
		}
		printf "\n  ],\n"

		# Write file mapping to temp file for trace_tags generation
		mapping_file = output_dir "/file_mapping.tmp"
		for (file_path in file_mapping) {
			print file_path "|" file_mapping[file_path] > mapping_file
		}
		close(mapping_file)

		# Also write layer_order mapping for trace_tags
		layer_mapping_file = output_dir "/layer_mapping.tmp"
		for (layer in layer_order) {
			print layer "|" layer_order[layer] > layer_mapping_file
		}
		close(layer_mapping_file)
}'

		# STEP 6: Generate trace_tags array (renamed from nodes, with from_tag field)
		_FILE_MAPPING_TEMP="${OUTPUT_DIR%/}/file_mapping.tmp"
		_LAYER_MAPPING_TEMP="${OUTPUT_DIR%/}/layer_mapping.tmp"
		printf '  "trace_tags": [\n'
		awk -F"$SHTRACER_SEPARATOR" -v file_mapping="$_FILE_MAPPING_TEMP" -v layer_mapping="$_LAYER_MAPPING_TEMP" '
BEGIN {
	first=1
	# Load file path to global file_id mapping
	while ((getline line < file_mapping) > 0) {
		split(line, parts, "|")
		# parts[1] = file path, parts[2] = global file_id
		file_to_id[parts[1]] = parts[2]
	}
	close(file_mapping)

	# Load layer to layer_id mapping
	while ((getline line < layer_mapping) > 0) {
		split(line, parts, "|")
		# parts[1] = layer name, parts[2] = layer_id
		layer_to_id[parts[1]] = parts[2]
	}
	close(layer_mapping)
}
NF >= 8 {
	# Look up global file_id from mapping using full path
	file_path = $5
	file_id = file_to_id[file_path]
	if (file_id == "") file_id = -1

	# Extract layer from trace_target (field 1)
	target = $1
	sub(/^:/, "", target)
	sub(/.*:/, "", target)
	layer_id = layer_to_id[target]
	if (layer_id == "") layer_id = -1

	# Normalize upstream tags into an array (handles comma/semicolon/space separated lists)
	raw_from = $3
	gsub(/^ +| +$/, "", raw_from)
	gsub(/[;,]/, " ", raw_from)
	from_tags_json = "[]"

	if (raw_from != "" && raw_from != "NONE" && raw_from != "null") {
		n_from = split(raw_from, from_arr, /[ \t]+/)
		from_tags_json = "["
		sep = ""
		for (i = 1; i <= n_from; i++) {
			tag = from_arr[i]
			if (tag == "" || tag == "NONE" || tag == "null") continue
			from_tags_json = from_tags_json sep "\"" tag "\""
			sep = ", "
		}
		from_tags_json = from_tags_json "]"
	}

	# Escape quotes and backslashes in description
	desc = $4
	gsub(/\\/, "\\\\", desc)
	gsub(/"/, "\\\"", desc)
	gsub(/\015/, "\\r", desc)  # \r (CR)
	gsub(/\012/, "\\n", desc)  # \n (LF)
	gsub(/\011/, "\\t", desc)  # \t (TAB)

	if (!first) printf ",\n"
	first=0

	printf "    {\n"
	printf "      \"id\": \"%s\",\n", $2
	printf "      \"from_tags\": %s,\n", from_tags_json
	printf "      \"description\": \"%s\",\n", desc
	printf "      \"file_id\": %d,\n", file_id
	printf "      \"line\": %d,\n", $6
	printf "      \"layer_id\": %d\n", layer_id
	printf "    }"
}
END { printf "\n" }
' "$_TAG_OUTPUT_DATA"

		# Clean up layer mapping (file mapping still needed for health section)
		rm -f "$_LAYER_MAPPING_TEMP"

		printf '  ],\n'

		# STEP 7: Links array REMOVED (can be derived from trace_tags[].from_tags)

		# Generate chains array from tag table
		_json_emit_chains "$_TAG_TABLE"

		# STEP 8: Generate cross-reference matrix files for backward compatibility
		# Note: Cross_references removed from JSON schema, but matrix files still
		#       needed by HTML/Markdown viewers for cross-reference tables

		# STEP 9: Generate health section with restructured coverage
		_FILE_MAPPING_TEMP2="${OUTPUT_DIR%/}/file_mapping.tmp"
		awk -v tag_output_data="$_TAG_OUTPUT_DATA" \
			-v tag_pairs="$_TAG_PAIRS" \
			-v tag_pairs_downstream="$_TAG_PAIRS_DOWNSTREAM" \
			-v config_table="$_CONFIG_TABLE" \
			-v file_mapping="$_FILE_MAPPING_TEMP2" \
			-v output_dir="${OUTPUT_DIR%/}" \
			-v sep="$SHTRACER_SEPARATOR" \
			"$AWK_FN_JSON_ESCAPE"'

		# Selection sort to keep tag lists and their metadata aligned alphabetically
		function sort_tag_list(n, tags, files, lines,    i, j, min, tmpTag, tmpFile, tmpLine) {
			if (n <= 1) return
			for (i = 0; i < n - 1; i++) {
				min = i
				for (j = i + 1; j < n; j++) {
					if (tags[j] < tags[min]) {
						min = j
					}
				}
				if (min != i) {
					tmpTag = tags[i]; tags[i] = tags[min]; tags[min] = tmpTag
					tmpFile = files[i]; files[i] = files[min]; files[min] = tmpFile
					tmpLine = lines[i]; lines[i] = lines[min]; lines[min] = tmpLine
				}
			}
		}

	BEGIN {
		# Load global file_id mapping (full path -> file_id) generated earlier
		while ((getline line < file_mapping) > 0) {
			_np = split(line, parts, "|")
			if (_np >= 2) {
				file_global_id[parts[1]] = parts[2]
			}
		}
		close(file_mapping)

			n_layers = 0
			while ((getline line < config_table) > 0) {
				_nf = split(line, fields, sep)
				if (_nf >= 1 && fields[1] != "") {
					layer = fields[1]
					sub(/^:/, "", layer)
					sub(/.*:/, "", layer)
					if (layer != "" && !(layer in layer_order)) {
						layer_order[layer] = n_layers
						ordered_layers[n_layers] = layer
						n_layers++
					}
				}
			}
			close(config_table)

			# Read all tags
			while ((getline line < tag_output_data) > 0) {
				_nf = split(line, fields, sep)
				if (_nf >= 8) {
					tag_id = fields[2]
					all_tags[tag_id] = 1
					tag_target[tag_id] = fields[1]
					tag_file[tag_id] = fields[5]
					tag_line[tag_id] = fields[6]
					tag_version[tag_id] = fields[8]
					total_tags++
				}
			}
			close(tag_output_data)

			# Read duplicated tags list
			dup_file = output_dir "/tags/verified/11_duplicated"
			while ((getline line < dup_file) > 0) {
				gsub(/^[[:space:]]+/, "", line)
				gsub(/[[:space:]]+$/, "", line)
				if (line != "") {
					duplicated_tags[line] = 1
				}
			}
			close(dup_file)

			# Read dangling FROM tag references (file format: child_tag parent_tag file line)
			dangling_file = output_dir "/tags/verified/12_dangling_fromtag"
			dangling_count = 0
			while ((getline line < dangling_file) > 0) {
				_nf = split(line, fields, " ")
				if (_nf >= 4) {
					dangling_child[dangling_count] = fields[1]
					dangling_parent[dangling_count] = fields[2]
					dangling_file_path[dangling_count] = fields[3]
					dangling_line[dangling_count] = fields[4]
					dangling_count++
				}
			}
			close(dangling_file)

			# Read tags with links - track tags appearing in EITHER column
			# A tag is considered "connected" if it appears as FROM or TO (excluding NONE)
			# AND both tags in the connection actually exist in the codebase
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				# Mark both FROM and TO tags as having connections (only if BOTH exist)
				if (fields[1] != "NONE" && fields[2] != "NONE" && fields[1] in all_tags && fields[2] in all_tags) {
					tags_with_links[fields[1]] = 1
					tags_with_links[fields[2]] = 1
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				if (fields[1] != "NONE" && fields[2] != "NONE" && fields[1] in all_tags && fields[2] in all_tags) {
					tags_with_links[fields[1]] = 1
					tags_with_links[fields[2]] = 1
				}
			}
			close(tag_pairs_downstream)

			tags_with_links_count = 0
			for (tag in tags_with_links) {
				tags_with_links_count++
			}

			isolated_count = 0
			for (tag in all_tags) {
				if (!(tag in tags_with_links)) {
					isolated_tags[isolated_count] = tag
					file_path = tag_file[tag]
					isolated_file_id[isolated_count] = file_global_id[file_path]
					isolated_line[isolated_count] = tag_line[tag]
					isolated_count++
				}
			}

			# Sort isolated tags alphabetically for deterministic output
			sort_tag_list(isolated_count, isolated_tags, isolated_file_id, isolated_line)

			# Build duplicate tag list with file/line info
			duplicate_count = 0
			for (tag in duplicated_tags) {
				if (tag in all_tags) {
					duplicate_tags[duplicate_count] = tag
					file_path = tag_file[tag]
					duplicate_file_id[duplicate_count] = file_global_id[file_path]
					duplicate_line[duplicate_count] = tag_line[tag]
					duplicate_count++
				}
			}

			# Sort duplicate tags alphabetically for deterministic output
			sort_tag_list(duplicate_count, duplicate_tags, duplicate_file_id, duplicate_line)

			# Build tag-to-layer mapping
			for (tag in all_tags) {
				target = tag_target[tag]
				layer = target
				sub(/^:/, "", layer)
				sub(/.*:/, "", layer)
				tag_to_layer[tag] = layer

				file_path = tag_file[tag]
				tag_to_file[tag] = file_path
			}

			# Build adjacency list (same as before)
			while ((getline line < tag_pairs) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					if (adj_list[src] == "") {
						adj_list[src] = tgt
					} else {
						adj_list[src] = adj_list[src] ";" tgt
					}
					if (adj_list[tgt] == "") {
						adj_list[tgt] = src
					} else {
						adj_list[tgt] = adj_list[tgt] ";" src
					}
				}
			}
			close(tag_pairs)

			while ((getline line < tag_pairs_downstream) > 0) {
				split(line, fields, " ")
				src = fields[1]
				tgt = fields[2]
				if (src != "NONE" && tgt != "NONE" && src in all_tags && tgt in all_tags) {
					if (index(adj_list[src], tgt) == 0) {
						if (adj_list[src] == "") {
							adj_list[src] = tgt
						} else {
							adj_list[src] = adj_list[src] ";" tgt
						}
					}
					if (index(adj_list[tgt], src) == 0) {
						if (adj_list[tgt] == "") {
							adj_list[tgt] = src
						} else {
							adj_list[tgt] = adj_list[tgt] ";" src
						}
					}
				}
			}
			close(tag_pairs_downstream)

			# Calculate coverage (same logic as before)
			for (tag in all_tags) {
				layer = tag_to_layer[tag]
				file_path = tag_to_file[tag]
				n_slash = split(file_path, path_parts, "/")
				file_basename = path_parts[n_slash]

				if (!(layer in layer_order) || file_basename == "config.md") continue

				my_order = layer_order[layer]
				layer_total[layer]++

				file_key = layer "|" file_path
				file_total[file_key]++

				if (file_version[file_key] == "") {
					file_version[file_key] = tag_version[tag]
				}

				up_layers_str = ""
				down_layers_str = ""
				has_up = 0
				has_down = 0

				if (adj_list[tag] != "") {
					n_neighbors = split(adj_list[tag], neighbor_arr, ";")
					for (j = 1; j <= n_neighbors; j++) {
						neighbor = neighbor_arr[j]
						neighbor_layer = tag_to_layer[neighbor]

						if (neighbor_layer == "" || neighbor_layer == layer) continue
						if (!(neighbor_layer in layer_order)) continue

						neighbor_order = layer_order[neighbor_layer]

						if (neighbor_order < my_order) {
							has_up = 1
							if (index(up_layers_str, neighbor_layer) == 0) {
								up_layers_str = up_layers_str (up_layers_str ? "," : "") neighbor_layer
							}
						}
						else if (neighbor_order > my_order) {
							has_down = 1
							if (index(down_layers_str, neighbor_layer) == 0) {
								down_layers_str = down_layers_str (down_layers_str ? "," : "") neighbor_layer
							}
						}
					}
				}

				if (up_layers_str != "") {
					n_up = split(up_layers_str, up_arr, ",")
					layer_up_count[layer]++
					for (k = 1; k <= n_up; k++) {
						target_layer = up_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_up_targets)) {
							layer_up_targets[key] = 1
						}
					}
				}

				if (down_layers_str != "") {
					n_down = split(down_layers_str, down_arr, ",")
					layer_down_count[layer]++
					for (k = 1; k <= n_down; k++) {
						target_layer = down_arr[k]
						key = layer SUBSEP target_layer
						if (!(key in layer_down_targets)) {
							layer_down_targets[key] = 1
						}
					}
				}

				if (has_up) file_up[file_key] = (file_up[file_key] + 0) + 1
				if (has_down) file_down[file_key] = (file_down[file_key] + 0) + 1
			}

			# Output health section
			printf "  \"health\": {\n"
			printf "    \"total_tags\": %d,\n", total_tags
			printf "    \"tags_with_links\": %d,\n", tags_with_links_count
			printf "    \"isolated_tags\": %d,\n", isolated_count
			printf "    \"isolated_tag_list\": [\n"
			for (i = 0; i < isolated_count; i++) {
				if (i > 0) printf ",\n"
				tag_id = json_escape(isolated_tags[i])
				fid = isolated_file_id[i]
				line_num = isolated_line[i]
				if (fid == "") fid = -1
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"id\": \"%s\", \"file_id\": %d, \"line\": %d}", tag_id, fid, line_num
			}
			printf "\n    ],\n"

			# Output duplicate tag information
			printf "    \"duplicate_tags\": %d,\n", duplicate_count
			printf "    \"duplicate_tag_list\": [\n"
			for (i = 0; i < duplicate_count; i++) {
				if (i > 0) printf ",\n"
				tag_id = json_escape(duplicate_tags[i])
				fid = duplicate_file_id[i]
				line_num = duplicate_line[i]
				if (fid == "") fid = -1
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"id\": \"%s\", \"file_id\": %d, \"line\": %d}", tag_id, fid, line_num
			}
			printf "\n    ],\n"

			# Output dangling reference information
			printf "    \"dangling_references\": %d,\n", dangling_count
			printf "    \"dangling_reference_list\": [\n"
			for (i = 0; i < dangling_count; i++) {
				if (i > 0) printf ",\n"
				child_tag = json_escape(dangling_child[i])
				parent_tag = json_escape(dangling_parent[i])
				file_path = dangling_file_path[i]
				fid = file_global_id[file_path]
				if (fid == "") fid = -1
				line_num = dangling_line[i]
				if (line_num == "" || line_num + 0 < 1) line_num = 1
				printf "      {\"child_tag\": \"%s\", \"missing_parent\": \"%s\", \"file_id\": %d, \"line\": %d}", child_tag, parent_tag, fid, line_num
			}
			printf "\n    ],\n"

			printf "    \"coverage\": {\n"
			printf "      \"layers\": [\n"

			# Output coverage layers with NEW nested upstream/downstream structure
			layer_id = 0
			layer_printed = 0
			for (i = 0; i < n_layers; i++) {
				layer = ordered_layers[i]
				if (!(layer in layer_total)) continue

				total = layer_total[layer]
				up_count = layer_up_count[layer] + 0
				down_count = layer_down_count[layer] + 0
				# NEW: Float percentages with 1 decimal
				up_pct = (total > 0) ? (up_count * 100.0 / total) : 0.0
				down_pct = (total > 0) ? (down_count * 100.0 / total) : 0.0

				if (layer_printed) printf ",\n"
				layer_printed = 1

				printf "        {\n"
				printf "          \"layer_id\": %d,\n", layer_id
				printf "          \"name\": \"%s\",\n", layer
				printf "          \"total\": %d,\n", total

				# NEW: Nested upstream object
				printf "          \"upstream\": {\n"
				printf "            \"count\": %d,\n", up_count
				printf "            \"percent\": %.1f\n", up_pct
				printf "          },\n"

				# NEW: Nested downstream object
				printf "          \"downstream\": {\n"
				printf "            \"count\": %d,\n", down_count
				printf "            \"percent\": %.1f\n", down_pct
				printf "          },\n"

				# Output files with NEW structure
				printf "          \"files\": [\n"
				first_file = 1

				# Need to map file path to global file_id
				# We'\''ll reuse the file_mapping we created earlier
				for (file_key in file_total) {
					split(file_key, parts, "|")
					if (parts[1] != layer) continue

					file_path = parts[2]
					file_tag_total = file_total[file_key]
					file_up_count = file_up[file_key] + 0
					file_down_count = file_down[file_key] + 0

					# NEW: Float percentages with 1 decimal
					file_up_pct = (file_tag_total > 0) ? (file_up_count * 100.0 / file_tag_total) : 0.0
					file_down_pct = (file_tag_total > 0) ? (file_down_count * 100.0 / file_tag_total) : 0.0

					# Get global file_id from mapping
					fid = file_global_id[file_path]
					if (fid == "") fid = -1

					# Get version from file_version
					file_ver = file_version[file_key]
					if (file_ver == "") file_ver = "unknown"

					if (!first_file) printf ",\n"
					first_file = 0

					printf "            {\n"
					printf "              \"file_id\": %d,\n", fid
					printf "              \"total\": %d,\n", file_tag_total

					# NEW: Nested upstream object
					printf "              \"upstream\": {\n"
					printf "                \"count\": %d,\n", file_up_count
					printf "                \"percent\": %.1f\n", file_up_pct
					printf "              },\n"

					# NEW: Nested downstream object
					printf "              \"downstream\": {\n"
					printf "                \"count\": %d,\n", file_down_count
					printf "                \"percent\": %.1f\n", file_down_pct
					printf "              },\n"

					# Escape version string for JSON
					printf "              \"version\": \"%s\"\n", json_escape(file_ver)
					printf "            }"
				}
				printf "\n          ]\n"
				printf "        }"
				layer_id++
			}

			printf "\n      ]\n"
			printf "    }\n"
			printf "  }\n"
		}'

		printf '}\n'
	} >"$_JSON_OUTPUT_FILENAME"

	# Clean up temp file
	rm -f "${OUTPUT_DIR%/}/file_mapping.tmp"

	# Generate cross-reference matrix files for backward compatibility with viewers
	_generate_cross_reference_matrix_files "$_JSON_OUTPUT_FILENAME" "$OUTPUT_DIR"

	echo "$_JSON_OUTPUT_FILENAME"
}

##
# @brief Generate cross-reference matrix files from JSON trace_tags
# @details Creates 06_cross_ref_matrix_* files in OUTPUT_DIR/tags/ directory
#          by parsing trace_tags[].from_tags field for backward compatibility
#          with HTML and Markdown viewers
# @param $1 : JSON file path
# @param $2 : OUTPUT_DIR
# @return 0 on success, 1 on failure
# @tag @IMP2.8@ (FROM: @ARC2.4@)
_generate_cross_reference_matrix_files() {
	_json_file="$1"
	_output_dir="${2%/}"
	_tags_dir="${_output_dir}/tags"

	[ -f "$_json_file" ] || return 1
	[ -d "$_tags_dir" ] || mkdir -p "$_tags_dir"

	# Remove stale matrices to avoid duplicate tabs
	rm -f "${_tags_dir}"/[0-9][0-9]_cross_ref_matrix_* 2>/dev/null || true

	# Parse files, layers, and trace_tags arrays from JSON, then emit adjacent-layer matrices
	printf '%s\n' "$(cat "$_json_file")" | awk -v tags_dir="$_tags_dir" '
		function safe_path(p) { return (p == "") ? "/unknown" : p }
		function safe_line(l) { return (l == "" || l + 0 < 1) ? 1 : l }
		BEGIN {
			in_files=0; in_file_obj=0;
			in_layers=0; in_layer_obj=0;
			in_trace_tags=0; in_tag_obj=0;
			layer_count=0; link_count=0;
		}

		/"files": \[/ { in_files=1; next }
		in_files && /^  \],?$/ { in_files=0; next }
		in_files && /^    \{/ { in_file_obj=1; file_id=""; file=""; next }
		in_files && in_file_obj && /^    \},?$/ { if (file_id != "") file_map[file_id]=file; in_file_obj=0; next }
		in_file_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_file_obj && /"file":/ { line=$0; sub(/.*"file": *"/, "", line); sub(/".*$/, "", line); file = line }

		/"layers": \[/ { in_layers=1; next }
		in_layers && /^  \],?$/ { in_layers=0; next }
		in_layers && /^    \{/ { in_layer_obj=1; layer_id=""; name=""; pattern=""; next }
		in_layers && in_layer_obj && /^    \},?$/ {
			if (layer_id != "") {
				layer_ids[++layer_count] = layer_id
				layer_map[layer_id] = name
				pattern_map[layer_id] = pattern
			}
			in_layer_obj=0; next
		}
		in_layer_obj && /"layer_id":/ { line=$0; sub(/.*"layer_id": */, "", line); sub(/,.*$/, "", line); layer_id = line }
		in_layer_obj && /"name":/ { line=$0; sub(/.*"name": *"/, "", line); sub(/".*$/, "", line); name = line }
		in_layer_obj && /"pattern":/ { line=$0; sub(/.*"pattern": *"/, "", line); sub(/".*$/, "", line); pattern = line }

		/"trace_tags": \[/ { in_trace_tags=1; next }
		in_trace_tags && /^  \],?$/ { in_trace_tags=0; next }
		in_trace_tags && /^    \{/ { in_tag_obj=1; tag_id=""; layer_id=""; file_id=""; line=""; from_tags_count=0; delete from_tags; next }
		in_trace_tags && in_tag_obj && /^    \},?$/ {
			if (tag_id != "" && layer_id != "" && file_id != "") {
				tag_layer[tag_id] = layer_id
				tag_file[tag_id] = file_map[file_id]
				tag_line[tag_id] = safe_line(line)
				tags_in_layer_count[layer_id]++
				tags_in_layer[layer_id, tags_in_layer_count[layer_id]] = tag_id

				# Collect upstream sources from from_tags array
				n_up = 0
				if (from_tags_count > 0) {
					for (u = 1; u <= from_tags_count; u++) upstream[u] = from_tags[u]
					n_up = from_tags_count
				}

				for (u = 1; u <= n_up; u++) {
					src_tag = upstream[u]
					if (src_tag == "" || src_tag == "null" || src_tag == "NONE") continue
					key = src_tag SUBSEP tag_id
					if (!link_seen[key]++) {
						links[link_count,0] = src_tag
						links[link_count,1] = tag_id
						link_count++
					}
				}
			}
			in_tag_obj=0; next
		}
		in_tag_obj && /"id":/ { line=$0; sub(/.*"id": *"/, "", line); sub(/".*$/, "", line); tag_id = line }
		in_tag_obj && /"from_tags":/ {
			from_tags_count = 0
			delete from_tags
			line=$0; sub(/.*\[/, "", line); sub(/\].*$/, "", line); raw = line
			if (raw != "") {
				n_ft = split(raw, ft_arr, ",")
				for (k = 1; k <= n_ft; k++) {
					t = ft_arr[k]
					gsub(/^[ \t"]+|[ \t"]+$/, "", t)
					if (t != "" && t != "NONE" && t != "null") {
						from_tags[++from_tags_count] = t
					}
				}
			}
		}
		in_tag_obj && /"layer_id":/ { line=$0; sub(/.*"layer_id": */, "", line); sub(/,.*$/, "", line); layer_id = line }
		in_tag_obj && /"file_id":/ { line=$0; sub(/.*"file_id": */, "", line); sub(/,.*$/, "", line); file_id = line }
		in_tag_obj && /"line":/ { line=$0; sub(/.*"line": */, "", line); sub(/,.*$/, "", line); line = line }

		END {
			if (layer_count < 2) exit
			file_num = 6
			for (i = 1; i < layer_count; i++) {
				src_id = layer_ids[i]
				tgt_id = layer_ids[i+1]
				src_name = layer_map[src_id]
				tgt_name = layer_map[tgt_id]
				src_pattern = pattern_map[src_id]
				tgt_pattern = pattern_map[tgt_id]
				src_safe = src_name; tgt_safe = tgt_name
				gsub(/ /, "_", src_safe); gsub(/ /, "_", tgt_safe)
				filename = sprintf("%s/%02d_cross_ref_matrix_%s_%s", tags_dir, file_num, src_safe, tgt_safe)
				file_num++

				print "[METADATA]" > filename
				print src_pattern "<shtracer_separator>" tgt_pattern >> filename
				print "[ROW_TAGS]" >> filename
				row_n = tags_in_layer_count[src_id]
				for (r = 1; r <= row_n; r++) {
					tag = tags_in_layer[src_id, r]
					print tag "<shtracer_separator>" safe_path(tag_file[tag]) "<shtracer_separator>" safe_line(tag_line[tag]) >> filename
				}

				print "[COL_TAGS]" >> filename
				col_n = tags_in_layer_count[tgt_id]
				for (c = 1; c <= col_n; c++) {
					tag = tags_in_layer[tgt_id, c]
					print tag "<shtracer_separator>" safe_path(tag_file[tag]) "<shtracer_separator>" safe_line(tag_line[tag]) >> filename
				}

				print "[MATRIX]" >> filename
				for (l = 0; l < link_count; l++) {
					src_tag = links[l,0]
					tgt_tag = links[l,1]
					if (tag_layer[src_tag] == src_id && tag_layer[tgt_tag] == tgt_id) {
						mkey = src_tag "<shtracer_separator>" tgt_tag
						if (!matrix_seen[mkey]++) print mkey >> filename
					}
				}
				close(filename)
			}
		}
	'

	return 0
}
