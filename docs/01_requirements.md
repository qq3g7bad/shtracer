# 📍 Requirements

## 📃 1. Use `config.md` for configuration

<!-- @REQ1.1@ -->
### To make a requirements traceability matrix, use a configuration file.

* This file is written in markdown format.
  * e.g. `../sample/config.md`.
  * Markdown is easy to learn, easy to reuse, and environment-independent.
* Markdown files are just regular text files, so changes can be easily managed in an SCM (such as git).

<!-- @REQ1.2@ -->
### This file has the file structure information to trace.

* Each section indicates the target layer structure.
* In the section, the following format information should be written.
  * Written in the listed format by writing `*` at the beginning.
  * A field consists of a name (left) and value (right). These are separated by ":".
    * The name in a field has **bold style**.
    * The value in a field is surrounded by double quotations.
  * Multiple `PATH` information entries are acceptable.


#### Field format

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

* **[BRE](https://www.gnu.org/software/sed/manual/html_node/BRE-syntax.html)**: Basic regular expressions.

```markdown
## Trace target

* **PATH**:  "target path 1"
* **BRIEF**: "brief information"
* **TAG FORMAT**: `@REQ[0-9\.]+@`
* **TAG LINE FORMAT**: `<!--.*-->`
* **TAG-TITLE OFFSET**: 2
```

* Tags are searched by the combination `TAG FORMAT` and `TAG LINE FORMAT`.
  * So that this `@REQ1.1.1@` will not be extracted by shtracer.
  * This pseudo-tag (`@REQ1.1.1@`) has `TAG FORMAT` but has no `TAG LINE FORMAT`.

<!-- @REQ1.2.1@ -->
#### Tracing Tags by Content vs. Filename

* If `TAG_FORMAT` is not empty, shtracer open filename.
* If `TAG_FORMAT` is empty, shtracer trace only by filename.

<!-- @REQ1.3@ -->
### The file structure can be convert to UML format by executing scripts.

* Output the result as a [mermaid.js](https://mermaid.js.org/) file.

<!-- @REQ1.4@ -->
### Check if configuration file are written correctly.

* Check whether the file or directory in `PATH` exists.
* If `PATH` means a directory, the `EXTENSION FILTER` field are written correctly.
* Tags are exist on `PATH` file.
* Tags are not duplicated.
* Tags are not isolated.

## 📥 2. Input

<!-- @REQ2.1@ -->
### Use text files

* Normal text files are easy to manage under SCM (such as git).
* Markdown format is acceptable, as are text files for programs (e.g. `*.c`, `*.cpp`).
  * But proprietary binary files such as MSexcel files must be converted to text files first.
  * It may seem like a pain but is important for easy change management.
* Each file has tag data.
  * They are written in a specific tag format written in config file (e.g. `<!-- @REQ[0-9\.]+@.* -->`).
  * If `(FROM:.*)` is included in the tag, it indicates that the tag written immediately after it is upstream of this tag.

<!-- @REQ2.2@ -->
### (Optional) Convert MSexcel (`*.xlsx`) or MSword (`*.docx`) format trace target to markdown files.

* It is not mandatory.
  * Since it relies on other proprietary programs, you may wish to use tools other than shell scripts.
* An example is [pandoc-comment-extractor](https://github.com/qq3g7bad/pandoc-comment-extractor).

## 📤 3. Output

<!-- @REQ3.1@ -->
### JSON Output for CI/CD Integration

* Export traceability data in structured JSON format for programmatic processing.
* JSON output should be sent to stdout for pipeline integration.
* JSON schema should include:
  * Metadata (version, timestamp, config path)
  * Trace chains (complete tag sequences)
  * Tag relationships (nodes and links)
  * Summary statistics (total traces, completeness)
* Enable seamless integration with CI/CD tools (jq, custom scripts, etc.).

<!-- @REQ3.2@ -->
### HTML Output

* Generate standalone HTML reports with embedded visualization.
* HTML output should be self-contained (no external dependencies).
* Support interactive diagrams and tables.
* HTML should be generated via viewer script from JSON data.

### Between two trace targets.

<!-- @REQ3.3.1@ -->
#### Make a text file which explain the relationship between two trace targets.

* The relationship between tags are shown by a simple text table (n x 2).
  * column 1: start tag
  * column 2: next connected tag
* Each tag has a hyperlink to the file that contains it.

<!-- @REQ3.3.2@ -->
#### Make a cross-reference table for easy reference.

* Cross-reference tables are made in markdown format.
* An example is shown below.
* Each tag has a hyperlink to the file that contains it.

.         | @ARC1.2@ | @ARC1.1@ | @ARC2.1@ | @ARC2.2@ |
--------- | -------- | -------- | -------- | -------- |
@REQ1.1@  | x        | x        |          |          |
@REQ1.2@  |          | x        |          |          |
@REQ1.3@  | x        |          |          | x        |
@REQ2.1@  | x        |          | x        |          |

### Between all trace targets.

<!-- @REQ3.4.1@ -->
#### Make a text file which explain the relationship between all trace targets.

* The relationship between tags are shown by a simple text table.
  * In the table format, you can see forward and backward flow by sorting a column.
* Isolated tags which have no relationship with other tags, those should be shown as is.
* Each tag has a hyperlink to the file that contains it.

<!-- @REQ3.4.2@ -->
#### Make a UML which explain the relationship between all trace targets.

* The relationship between tags are shown by UML that can be written as text format.

<!-- @REQ3.5@ -->
### (Optional) Convert trace output markdown files to MSexcel (`*.xlsx`) or MSword (`*.docx`) format.

* It is not mandatory.
* Since it relies on other proprietary programs, you may wish to use tools other than shell scripts.

## ⚙️ 4. Options

<!-- @REQ4.1@ -->
### Rename tag

* Change tag name based on input.

<!-- @REQ4.2@ -->
### Run test

<!-- @REQ4.3@ -->
### Verify

* Check if there are invalid config/tag information.

<!-- @REQ4.4@ -->
### Export modes

* `--json`: Export traceability data as JSON to stdout
* `--html`: Generate standalone HTML report to stdout
* `--summary`: Print traceability summary (direct links only)

## 🔢 5. Error Codes for CI/CD Integration

<!-- @REQ5.1@ -->
### Exit codes must clearly indicate error types

* Exit codes should enable CI/CD systems to identify specific failure types.
* Each error category should have a distinct exit code range.
* Exit code `0` indicates success.

<!-- @REQ5.1.1@ -->
#### Usage Errors (1-9)

* `1` - Invalid usage or arguments
* `2` - Config file not found
* `3` - Config file format invalid

<!-- @REQ5.1.2@ -->
#### Processing Errors (10-19)

* `10` - Failed to extract tags
* `11` - Failed to create tag table
* `12` - Failed to generate JSON
* `13` - Viewer script execution failed

<!-- @REQ5.1.3@ -->
#### Verification Errors (20-29)

* `20` - Found isolated tags (no downstream references)
* `21` - Found duplicate tags
* `22` - Found both isolated and duplicate tags

<!-- @REQ5.1.4@ -->
#### System Errors (30-39)

* `30` - Internal error (directory change failure, etc.)
* `31` - Viewer script not found

<!-- @REQ6.1@ -->
## ⭕ 6. Nice-to-have requirements

* Must-have-requirements (these are written above) have their own tags for trace.
* Nice-to-have requirements don't have any tag and not traced.

### Use shell scripts other than optional scripts

* For portability, use only shell scripts to create the RTM.
* In the case of optional scripts, there are already useful tools.
  * Use there tools.
  * Although the language or environment is not important, portability is a priority.

### Unit test each function

* Use [shUnit2](https://github.com/kward/shunit2) (for unit testing).

### Reduce dependence on specific shells and be as POSIX compliant as possible.

## 📗 7. Definition

* **Trace target**: File or directory which has information to trace.
* **Tag** : In trace target, there are some tags to discriminate details of trace information. `shtracer` trace the relationship between each tag.
* **From tag** : Each tag has its "from tag". "From tag" means upstream tags which connect to the tag.
* **Tag table** : Tag tables are consisted of two column data as shown below. The left column have upstream tags, and the right column have downstream tags.

```text
NONE @REQ1.1@
NONE @REQ1.2@
NONE @REQ1.3@
@REQ1.2@ @ARC2.1@
@REQ1.4@ @ARC2.1@
@ARC2.1@ @IMP4.1@
```

