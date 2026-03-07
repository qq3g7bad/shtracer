#!/bin/sh
# Unit tests for JSON parser functions (shtracer_json_parser.sh)

# Source test target
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
if [ -z "$SCRIPT_DIR" ]; then
	echo "[ERROR] Failed to determine script directory" >&2
	exit 1
fi

# shunit2 needs a readable path to this test file
SHUNIT_PARENT="${SCRIPT_DIR%/}/$(basename -- "$0")"
export SHUNIT_PARENT

TEST_ROOT=${TEST_ROOT:-$(CDPATH='' cd -- "${SCRIPT_DIR%/}/.." 2>/dev/null && pwd -P)}
SHTRACER_ROOT_DIR=${SHTRACER_ROOT_DIR:-$(CDPATH='' cd -- "${TEST_ROOT%/}/../.." 2>/dev/null && pwd -P)}

cd "${TEST_ROOT}" || exit 1

# shellcheck source=../../main/shtracer_util.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_util.sh"
# shellcheck source=../../main/shtracer_json_parser.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/main/shtracer_json_parser.sh"
# shellcheck source=../test_helper.sh
. "${SHTRACER_ROOT_DIR%/}/scripts/test/test_helper.sh"

# Minimal JSON fixture for tests
# shellcheck disable=SC2034
TEST_JSON='{
  "metadata": {
    "version": "0.2.0",
    "generated": "2026-01-15T10:30:00Z",
    "config_path": "/path/to/config.md"
  },
  "files": [
    {
      "file_id": 0,
      "file": "requirements.md",
      "version": "git:abc1234"
    },
    {
      "file_id": 1,
      "file": "architecture.md",
      "version": "mtime:2026-01-10T08:00:00Z"
    }
  ],
  "layers": [
    {
      "layer_id": 0,
      "name": "Requirement",
      "pattern": "@REQ[0-9\\.]+@",
      "file_ids": [0],
      "total_tags": 2,
      "upstream_layers": [],
      "downstream_layers": [1]
    },
    {
      "layer_id": 1,
      "name": "Architecture",
      "pattern": "@ARC[0-9\\.]+@",
      "file_ids": [1],
      "total_tags": 1,
      "upstream_layers": [0],
      "downstream_layers": []
    }
  ],
  "trace_tags": [
    {
      "id": "@REQ1@",
      "from_tags": [],
      "description": "First requirement",
      "file_id": 0,
      "line": 5,
      "layer_id": 0
    },
    {
      "id": "@REQ2@",
      "from_tags": [],
      "description": "Second requirement",
      "file_id": 0,
      "line": 10,
      "layer_id": 0
    },
    {
      "id": "@ARC1@",
      "from_tags": ["@REQ1@"],
      "description": "Architecture item",
      "file_id": 1,
      "line": 3,
      "layer_id": 1
    }
  ],
  "chains": [
    ["@REQ1@", "@ARC1@", "NONE", "NONE"],
    ["@REQ2@", "NONE", "NONE", "NONE"]
  ],
  "health": {
    "total_tags": 3,
    "tags_with_links": 1,
    "isolated_tags": 1,
    "isolated_tag_list": [
      {"id": "@REQ2@", "file_id": 0, "line": 10}
    ],
    "duplicate_tags": 0,
    "duplicate_tag_list": [

    ],
    "dangling_references": 0,
    "dangling_reference_list": [

    ],
    "coverage": {
      "layers": [
        {
          "layer_id": 0,
          "upstream": {"count": 0, "percent": 0.0},
          "downstream": {"count": 1, "percent": 50.0},
          "files": [
            {
              "file_id": 0,
              "total": 2,
              "upstream": {"count": 0, "percent": 0.0},
              "downstream": {"count": 1, "percent": 50.0}
            }
          ]
        }
      ]
    }
  }
}'

##
# @brief
#
oneTimeSetUp() {
	shtracer_test_header "UNIT TEST (JSON Parser)"
}

##
# @brief SetUp function for each test
#
setUp() {
	set +u
	export SHTRACER_IS_PROFILE_ENABLE="$SHTRACER_FALSE"
}

# ============================================================================
# json_parse_metadata tests
# ============================================================================

##
# @brief Test json_parse_metadata extracts version
# @tag @UT4.6.1@ (FROM: @IMP4.6@)
test_json_parse_metadata_version() {
	result=$(json_parse_metadata "$TEST_JSON" | grep '^version=' | cut -d= -f2-)
	assertEquals "0.2.0" "$result"
}

##
# @brief Test json_parse_metadata extracts generated timestamp
test_json_parse_metadata_generated() {
	result=$(json_parse_metadata "$TEST_JSON" | grep '^generated=' | cut -d= -f2-)
	assertEquals "2026-01-15T10:30:00Z" "$result"
}

##
# @brief Test json_parse_metadata extracts config_path
test_json_parse_metadata_config_path() {
	result=$(json_parse_metadata "$TEST_JSON" | grep '^config_path=' | cut -d= -f2-)
	assertEquals "/path/to/config.md" "$result"
}

# ============================================================================
# json_parse_files tests
# ============================================================================

##
# @brief Test json_parse_files returns correct file count
# @tag @UT4.6.2@ (FROM: @IMP4.6@)
test_json_parse_files_count() {
	result=$(json_parse_files "$TEST_JSON" | wc -l | tr -d ' ')
	assertEquals "2" "$result"
}

##
# @brief Test json_parse_files first file fields
test_json_parse_files_first() {
	result=$(json_parse_files "$TEST_JSON" | head -1)
	assertEquals "0|requirements.md|git:abc1234" "$result"
}

##
# @brief Test json_parse_files second file fields
test_json_parse_files_second() {
	result=$(json_parse_files "$TEST_JSON" | sed -n '2p')
	assertEquals "1|architecture.md|mtime:2026-01-10T08:00:00Z" "$result"
}

# ============================================================================
# json_parse_layers tests
# ============================================================================

##
# @brief Test json_parse_layers returns correct layer count
# @tag @UT4.6.3@ (FROM: @IMP4.6@)
test_json_parse_layers_count() {
	result=$(json_parse_layers "$TEST_JSON" | wc -l | tr -d ' ')
	assertEquals "2" "$result"
}

##
# @brief Test json_parse_layers first layer name
test_json_parse_layers_first() {
	result=$(json_parse_layers "$TEST_JSON" | head -1)
	# Verify layer_id and name (pattern may have shell escaping issues)
	layer_id=$(printf '%s' "$result" | cut -d'|' -f1)
	layer_name=$(printf '%s' "$result" | cut -d'|' -f2)
	assertEquals "0" "$layer_id"
	assertEquals "Requirement" "$layer_name"
}

# ============================================================================
# json_parse_chains tests
# ============================================================================

##
# @brief Test json_parse_chains returns correct chain count
# @tag @UT4.6.4@ (FROM: @IMP4.6@)
test_json_parse_chains_count() {
	result=$(json_parse_chains "$TEST_JSON" | wc -l | tr -d ' ')
	assertEquals "2" "$result"
}

##
# @brief Test json_parse_chains first chain pipe-separated
test_json_parse_chains_first() {
	result=$(json_parse_chains "$TEST_JSON" | head -1)
	assertEquals "@REQ1@|@ARC1@|NONE|NONE" "$result"
}

##
# @brief Test json_parse_chains second chain
test_json_parse_chains_second() {
	result=$(json_parse_chains "$TEST_JSON" | sed -n '2p')
	assertEquals "@REQ2@|NONE|NONE|NONE" "$result"
}

# ============================================================================
# json_parse_health tests
# ============================================================================

##
# @brief Test json_parse_health extracts total_tags
# @tag @UT4.6.5@ (FROM: @IMP4.6@)
test_json_parse_health_total_tags() {
	result=$(json_parse_health "$TEST_JSON" | grep '^total_tags=' | cut -d= -f2-)
	assertEquals "3" "$result"
}

##
# @brief Test json_parse_health extracts tags_with_links
test_json_parse_health_tags_with_links() {
	result=$(json_parse_health "$TEST_JSON" | grep '^tags_with_links=' | cut -d= -f2-)
	assertEquals "1" "$result"
}

##
# @brief Test json_parse_health extracts isolated tag details
test_json_parse_health_isolated_detail() {
	result=$(json_parse_health "$TEST_JSON" | grep '^isolated|')
	assertEquals "isolated|@REQ2@|requirements.md|10" "$result"
}

# ============================================================================
# json_get_layer_order tests
# ============================================================================

##
# @brief Test json_get_layer_order returns layers in order
# @tag @UT4.6.6@ (FROM: @IMP4.6@)
test_json_get_layer_order() {
	result=$(json_get_layer_order "$TEST_JSON")
	first=$(printf '%s\n' "$result" | head -1)
	second=$(printf '%s\n' "$result" | sed -n '2p')
	assertEquals "Requirement" "$first"
	assertEquals "Architecture" "$second"
}

# ============================================================================
# json_get_layer_display_name tests
# ============================================================================

##
# @brief Test json_get_layer_display_name with matching abbreviation
# @tag @UT4.6.7@ (FROM: @IMP4.6@)
test_json_get_layer_display_name_match() {
	result=$(json_get_layer_display_name "$TEST_JSON" "Req")
	assertEquals "Requirement" "$result"
}

##
# @brief Test json_get_layer_display_name with no match returns abbreviation
test_json_get_layer_display_name_no_match() {
	result=$(json_get_layer_display_name "$TEST_JSON" "ZZZ")
	assertEquals "ZZZ" "$result"
}

# ============================================================================
# json_format_version_display tests
# ============================================================================

##
# @brief Test json_format_version_display with git hash
# @tag @UT4.6.8@ (FROM: @IMP4.6@)
test_json_format_version_display_git() {
	result=$(json_format_version_display "git:abc1234")
	assertEquals "abc1234" "$result"
}

##
# @brief Test json_format_version_display with mtime
test_json_format_version_display_mtime() {
	result=$(json_format_version_display "mtime:2025-12-26T10:30:45Z")
	assertEquals "2025-12-26 10:30" "$result"
}

##
# @brief Test json_format_version_display with unknown
test_json_format_version_display_unknown() {
	result=$(json_format_version_display "unknown")
	assertEquals "unknown" "$result"
}

##
# @brief Test json_format_version_display with empty string
test_json_format_version_display_empty() {
	result=$(json_format_version_display "")
	assertEquals "unknown" "$result"
}

# Load shunit2
# shellcheck source=../shunit2/shunit2
. "${TEST_ROOT%/}/shunit2/shunit2"
