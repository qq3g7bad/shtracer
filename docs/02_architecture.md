# 🏡 Architecture & Detailed design

## 📂 Project layout

```text
├── shtracer              Entry point of this project
├── docs/                 Documents for development
├── sample                Sample config data
└── scripts               Scripts for `shtracer`
    ├── main              Main shell scripts (and helper functions)
    └── test              For testing
        └── shunit2       Testing framework introduced by git submodule
```

### Workflow

```mermaid
stateDiagram

input:Input
opt_input:Optional input files

state input {
  targetfiles:Trace target files
  config:config.md
}
state opt_input {
  wordinput:Word files
  excelinput:Excel files
}
note left of input
  Text files
end note

[*] --> input
[*] --> opt_input

opt_input --> targetfiles
opt_output:Optional output files

state output {
  txt_output: Text files
  html_output:HTML file
}

state txt_output {
  rtm:Requirements traceability matrix (RTM)
  uml:UML
}

state opt_output {
  excel_output:Excel file
}


input --> output : shtracer
rtm --> opt_output
rtm --> html_output
uml --> html_output

```

<!-- @ARC1.1@ (FROM: @REQ6.1@) -->
## 🔵 `shtracer`

<a id="tag-123"></a>

* Entry point of this project.

```bash
# Change mode
chmod +x ./shtracer

# Read a configuration file and create a traceability matrix
./shtracer ./sample/config.md
```

<!-- @ARC1.2@ (FROM: @REQ4.1@, @REQ4.2@, @REQ4.3@, @REQ4.4@, @REQ5.1@, @REQ6.1@) -->
### Utility

The `shtracer` file includes utility functions.

* Initialize environment
* Error and exit with specific exit codes
* Print usage (including exit code documentation)
* Parse arguments
* Load helper functions
* Main routine

<!-- @ARC1.3@ (FROM: @REQ5.1@, @REQ5.1.1@, @REQ5.1.2@, @REQ5.1.3@, @REQ5.1.4@) -->
### Exit Code Management

Exit codes are defined as constants for CI/CD integration:

**Usage Errors (1-9)**

* `EXIT_USAGE=1` - Invalid arguments or usage
* `EXIT_CONFIG_NOT_FOUND=2` - Config file not found
* `EXIT_CONFIG_INVALID=3` - Config file format invalid

**Processing Errors (10-19)**

* `EXIT_EXTRACT_TAGS_FAILED=10` - Failed to extract tags
* `EXIT_MAKE_TABLE_FAILED=11` - Failed to create tag table
* `EXIT_MAKE_JSON_FAILED=12` - Failed to generate JSON
* `EXIT_VIEWER_FAILED=13` - Viewer script execution failed

**Verification Errors (20-29)**

* `EXIT_ISOLATED_TAGS=20` - Found isolated tags (lowest priority)
* `EXIT_DUPLICATE_TAGS=21` - Found duplicate tags (highest priority)
* `EXIT_DANGLING_TAGS=22` - Found dangling FROM tag references

Note: If multiple issues exist, all are reported to stderr but exit code reflects highest-priority error (21 > 22 > 20)

**System Errors (30-39)**

* `EXIT_INTERNAL_ERROR=30` - Internal error
* `EXIT_VIEWER_NOT_FOUND=31` - Viewer script not found

All error handling uses these constants instead of hardcoded values.

## 📂 scripts/main/

### 📄 `shtracer_func.sh`

<!-- @ARC2.1@ (FROM: @REQ1.1@, @REQ1.2@, @REQ1.4@, @REQ2.1@, @REQ2.2@, @REQ3.5@) -->
#### Check the config file

* Read configuration file.
* Extract each trace target information in one line. Each line has the following items.

Implementation is divided into two helper functions:

##### Remove comments from config markdown

* Remove HTML comment blocks from the configuration markdown file.
* Preserve comment blocks surrounded by backticks (exceptions for code examples).
* Remove empty lines and normalize whitespace.
* Strip markdown bold syntax from field names.

##### Convert cleaned config to table format

* Parse markdown heading hierarchy and convert to colon-separated titles (e.g., `Heading1:Heading1.1:Heading1.1.1`).
* Extract field-value pairs from the cleaned markdown content.
* Output tab-separated table with 10 columns per trace target configuration.

column | optional  | content                                                              | quotation
------ | --------- | -------------------------------------------------------------------- | -------
1      | mandatory | trace target title                                                   | "
2      | mandatory | path (to directory or file from your config file)                    | "
3      | optional  | extension with wildcard (BRE is acceptable)                          | "
4      | optional  | ignore filter (you can use wildcards)                                | "
5      | optional  | description                                                          | "
6      | mandatory | tag format (for searching tags written in BRE)                       | `
7      | mandatory | tag line format (for searching lines including tags written in BRE) | `
8      | optional  | tag-title offset (how many lines away from each tag, default: 1)     | none

<!-- @ARC2.2@ (FROM: @REQ2.1@, @REQ3.3.1@) -->
#### Make tag table

* Read trace targets.
  * Get each tag and its "from tags".
  * A tag table consists of two-column data as shown below.

Implementation is divided into three helper functions:

##### Validate config file input

* Validate that the config output file exists.
* Convert relative paths to absolute paths for consistent file handling.
* Return the absolute path or exit with an error if the file does not exist.

##### Discover target files from config

* Parse the config table to extract path and extension filter information.
* Handle both file and directory paths.
* Build `find` commands for directory traversal with extension filters.
* Support multiple extension filters separated by `|` (pipe).
* Support ignore filters to exclude specific files or directories.
* Return a sorted, unique list of files to process.

##### Extract tags from discovered files

* Process each discovered file to extract tags.
* Use AWK to parse files line by line, searching for tag patterns.
* Extract tag IDs, FROM tags (upstream references), and associated titles.
* Handle TAG-TITLE OFFSET to find the correct title line relative to each tag.
* Output tag information with file paths and line numbers.

```text
NONE @REQ1.1@
NONE @REQ1.2@
NONE @REQ1.3@
@REQ1.2@ @ARC2.1@
@REQ1.4@ @ARC2.1@
@ARC2.1@ @IMP4.1@
```

<!-- @ARC2.3@ (FROM: @REQ2.1@, @REQ3.4.1@) -->
#### Join tag table

* Connect tag tables from right direction.

```text
@REQ1.1@ @ARC2.1@ @IMP2.1@ @TST1.1@
@REQ1.2@ @ARC2.1@ @IMP2.1@ @TST1.2@
@REQ2.1@ @ARC2.1@ @IMP2.1@ @TST1.3@
@REQ2.1@ @ARC2.2@ @IMP2.2@ @TST2.1@
```

<!-- @ARC2.4@ (FROM: @REQ4.1@) -->
#### Swap tags

* Swap tags in all trace targets

<!-- @ARC2.5@ (FROM: @REQ4.3@) -->
#### Verify tag information

The following cases are invalid.

* [ ] From tags that have no upstream tags.
* [ ] Duplicated tags.

Outputs errors to stderr in one-line-per-error format:

* `[shtracer][error][isolated_tags] @TAG@ /path/file.sh line` - Isolated tag (no upstream/downstream)
* `[shtracer][error][duplicated_tags] @TAG@ /path/file.sh line` - Duplicate tag occurrence
* `[shtracer][error][dangling_tags] @CHILD@ @PARENT@ /path/file.sh line` - Dangling FROM reference

All detected issues are reported, enabling easy filtering with grep/awk/cut for CI/CD integration.

<!-- @ARC2.6@ (FROM: @REQ3.1@) -->
#### Generate JSON output

* Export traceability data in structured JSON format.
* JSON schema includes:
  * `metadata`: version, timestamp, config_path
  * `health`: coverage statistics and isolated tag list
    * `total_tags`, `tags_with_links`, `isolated_tags`
    * `isolated_tag_list`: array of isolated tag metadata (id, file_id, line)
    * `coverage.layers`: per-layer statistics with mass-based coverage
  * `files`: top-level array of file metadata (layer, file basename, coverage statistics, version)
  * `nodes`: tag information (id, description, line, file_id referencing files array)
  * `links`: relationships between tags (source, target)
  * `chains`: complete trace paths from requirements to tests
  * `cross_references`: optional layer-to-layer traceability matrices
* Output to designated file in OUTPUT_DIR.
* Enable integration with CI/CD pipelines and custom tools.

<!-- @ARC2.7@ (FROM: @REQ3.3.2@) -->
#### Generate Cross-Reference Matrices

* Create layer-to-layer traceability matrices for visualization
* Matrix format includes:
  * Metadata: row_layer, col_layer, timestamp
  * Row/column tags with file paths and line numbers
  * Relationship links between row and column tags
* Output to `shtracer_output/tags/06_cross_ref_matrix_*` files
* Support both text-based and JSON-embedded matrix formats
* Helper functions for:
  * Layer hierarchy extraction from config
  * Matrix generation between adjacent layers
  * Markdown table formatting with hyperlinks
  * Relative path computation for cross-references

<!-- @ARC3.1@ (FROM: @REQ1.3@, @REQ3.2@, @REQ3.4.2@) -->
### 📄 `shtracer_html_viewer.sh`

* Generate an HTML visualization from shtracer JSON (stdin/file) as a viewer filter.
* Read JSON from stdin or file argument.
* Render interactive diagrams (D3.js network graph).
* Display traceability matrix and summary tables.
* Embed all assets inline (CSS, JavaScript) for standalone HTML.
* Support syntax highlighting for code references.

The viewer renders the diagrams and summary directly from the JSON payload (nodes/links/chains).

<!-- @ARC3.2@ (FROM: @REQ3.2@) -->
#### HTML Template Customization

* Support external template files for HTML viewer customization
* Template resolution priority:
  1. `$SHTRACER_TEMPLATE_DIR/template.html` (environment variable)
  2. `$HOME/.shtracer/template.html` (user-level customization)
  3. Embedded heredoc (default fallback)
* Separate functions for HTML and CSS template retrieval
* No validation of external templates (user responsibility)

<!-- @ARC4@ (FROM: @REQ3.3.2@, @REQ3.4.2@) -->
### 📄 Advanced Viewer Features

* Cross-reference matrix visualization in HTML viewer
* Markdown-based traceability reports
* Tag index generation for documentation

Implementation split into:
- HTML viewer: Interactive cross-reference matrix tabs
- Markdown viewer: Print-friendly reports with tag indices

<!-- @ARC4.1@ (FROM: @REQ3.2@, @REQ4.4@) -->
#### Markdown Report Generation

* Generate standalone markdown reports from JSON output
* Report structure:
  1. Header with metadata
  2. Table of contents
  3. Summary statistics
  4. Health report (coverage, isolated tags)
  5. Traceability chains
  6. Cross-reference matrices (layer-to-layer)
  7. Tag index (grouped by layer)
  8. Footer with metadata
* JSON parsing helpers for extracting:
  - Metadata, files, layers
  - Tags (trace_tags), links, chains
  - Health statistics and coverage data
* Print-friendly format for documentation and audits

subgraph "Optional scripts"
id3_2_1 --> id3_2_2
end
id3_1_2 --> id4
id3_2_2 --> id4
id4 --> stop

```
