# 🐚 shtracer

[![CI Tests](https://github.com/qq3g7bad/shtracer/actions/workflows/test.yml/badge.svg)](https://github.com/qq3g7bad/shtracer/actions/workflows/test.yml)
[![License](https://img.shields.io/github/license/qq3g7bad/shtracer)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-POSIX-green.svg)](https://pubs.opengroup.org/onlinepubs/9699919799/)

**Zero-dependency requirements traceability for modern development workflows**

Track requirements → architecture → implementation → tests using simple markdown tags. Built with pure POSIX shell for maximum portability and CI/CD integration.

---

## 🎯 Why shtracer?

Traditional requirements traceability tools are **heavy, proprietary, and hard to integrate** into modern development workflows. shtracer takes a different approach:

### ✨ Key Benefits

**🔗 CI/CD Native**

- **Structured JSON output** for seamless pipeline integration
- Parse, validate, and enforce traceability in your CI checks
- No databases, no servers—just pipe JSON to any tool you want

**📦 Zero Dependencies**

- Pure POSIX shell—works on Linux, macOS, Windows (Git Bash/WSL)
- No Python, Node.js, or runtime environments required
- Clone and run: `./shtracer ./sample/config.md`

**📝 Developer-Friendly**

- Write requirements in **plain Markdown**—no proprietary formats
- Simple `@TAG@` syntax in comments: `<!-- @REQ-001@ -->`
- Version control friendly: diffs are readable, merges are clean

**🔄 Automated Maintenance**

- **Change mode**: Rename tags across entire codebase in one command
- **Verify mode**: Detect orphaned or duplicate tags automatically
- Keep your traceability matrix accurate as requirements evolve

---

## 🚀 Quick Start

```bash
# Clone and run (no installation needed)
git clone https://github.com/qq3g7bad/shtracer.git
cd shtracer
chmod +x ./shtracer

# Generate traceability matrix
./shtracer ./sample/config.md

# Output structured JSON for CI/CD
./shtracer ./sample/config.md > traceability.json

# Generate interactive HTML report
./shtracer --html ./sample/config.md > report.html

# Generate markdown report
./shtracer --markdown ./sample/config.md > report.md
```

---

## 📖 How It Works

### 1. Tag your documents and code

**requirements.md**

```markdown
<!-- @REQ-001@ -->
## User Authentication
Users must be able to log in with email and password.
```

**architecture.md**

```markdown
<!-- @ARCH-101@ (FROM: @REQ-001@) -->
## Authentication Service
Implements OAuth 2.0 with JWT tokens.
```

**auth.sh**

```bash
# @IMPL-201@ (FROM: @ARCH-101@)
function authenticate_user() {
    # Implementation
}
```

**auth_test.sh**

```bash
# @TEST-301@ (FROM: @IMPL-201@)
test_authenticate_user() {
    # Test implementation
}
```

### 2. Generate traceability matrix

```bash
./shtracer ./sample/config.md
```

### 3. Integrate with CI/CD

```yaml
# .github/workflows/traceability.yml
- name: Validate traceability
  run: |
    ./shtracer config.md | jq '[.chains[] | select(. | length < 5 and .[0] != "NONE")]' > incomplete.json
    if [ "$(cat incomplete.json)" != "[]" ]; then
      echo "❌ Found incomplete traceability chains"
      exit 1
    fi
```

---

## 📷 Screenshots

### Interactive HTML Report

#### Coverage

![type](./docs/img/type.png)

#### Full trace

![full](./docs/img/full.png)

#### Sortable matrix with interactive tabs

![matrix](./docs/img/matrix.png)

*Visualize requirement flows from requirements to tests. Click badges to jump to source files.*

**New: Interactive Tab UI for Cross-Reference Tables**

The HTML viewer now includes a tab-based interface to explore traceability relationships at different levels:

- **All** - Complete traceability matrix (requirements → architecture → implementation → tests)
- **REQ↔ARC** - Requirements vs Architecture cross-reference
- **ARC↔IMP** - Architecture vs Implementation cross-reference
- **IMP↔UT** - Implementation vs Unit Tests cross-reference
- **UT↔IT** - Unit Tests vs Integration Tests cross-reference

**Features:**

- 🔗 **Clickable tags** - All tags link to source files (opens on right side)
- 📊 **Sparse matrices** - "x" markers show direct traceability links between adjacent levels
- 🔄 **Dynamic generation** - Tabs automatically adapt to your config.md structure

---

## ⚙️ Usage

### Basic Commands

```bash
# Generate traceability artifacts (tag table + JSON files)
./shtracer ./sample/config.md

# Export structured JSON to stdout (CI/CD friendly)
./shtracer --json ./sample/config.md

# Generate standalone HTML report
./shtracer --html ./sample/config.md > report.html

# Rename tags across entire project
./shtracer -c @OLD-TAG@ @NEW-TAG@ ./sample/config.md

# Verify traceability (detect orphaned/duplicate tags)
./shtracer -v ./sample/config.md

# Run unit tests
./shtracer -t
```

### Configuration File Format

The `config.md` file defines which files to trace and how to organize traceability links. It uses markdown format with structured properties for each traceability target.

**Example `config.md`:**

```markdown
# config.md

## Requirement

* **PATH**: "./docs/01_requirements.md"
  * **BRIEF**: "Describes requirements as specifications."
  * **TAG FORMAT**: `@REQ[0-9\.]+@`
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1

## Architecture

* **PATH**: "./docs/02_architecture.md"
  * **BRIEF**: "Describes the structure of this project."
  * **TAG FORMAT**: `@ARC[0-9\.]+@`
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1

## Implementation

* **PATH**: "./src/"
  * **EXTENSION FILTER**: "*.sh"
  * **TAG FORMAT**: `@IMP[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "Implementation files"

## Unit test

* **PATH**: "./tests/"
  * **EXTENSION FILTER**: "*.sh"
  * **IGNORE FILTER**: "integration*"
  * **TAG FORMAT**: `@UT[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "Unit test files"
```

**Key Points:**

- Each section header (`## Requirement`, `## Architecture`, etc.) defines a traceability level
- `**PATH**`: File or directory path (relative to config file location)
- `**TAG FORMAT**`: ERE (Extended Regular Expression) pattern for tags, enclosed in backticks
- `**TAG LINE FORMAT**`: ERE pattern for lines containing tags (e.g., `#.*` for shell comments, `<!--.*-->` for markdown)
- `**EXTENSION FILTER**`: Optional file extension filter (e.g., `*.sh`)
- `**IGNORE FILTER**`: Optional ignore pattern using `|` for multiple conditions
- `**TAG-TITLE OFFSET**`: Optional offset between tag and title (default: 1)
- `**BRIEF**`: Optional description of the traceability target

For a complete example, see [`./sample/config.md`](./sample/config.md).

### Cross-Reference Tables

**Automatically generated for every traceability run** (when using normal mode), cross-reference tables show the relationships between adjacent traceability levels in an easy-to-read matrix format.

**Generated tables** (based on your `config.md` structure):

- `output/cross_reference/01_REQ_ARC.md` - Requirements vs Architecture
- `output/cross_reference/02_ARC_IMP.md` - Architecture vs Implementation
- `output/cross_reference/03_IMP_UT.md` - Implementation vs Unit Tests
- `output/cross_reference/04_IMP_IT.md` - Implementation vs Integration Tests

**Example output:**

```markdown
# Cross-Reference Table: REQ vs ARC

**Legend**:
- Row headers: REQ tags
- Column headers: ARC tags
- `x` indicates a traceability link exists
- Click tag IDs to navigate to source location

. | [@ARC1.1@](../docs/02_architecture.md#L64) | [@ARC2.1@](../docs/02_architecture.md#L122) |
--- | --- | --- |
[@REQ1.1@](../docs/01_requirements.md#L6) |   | x |
[@REQ1.2@](../docs/01_requirements.md#L14) |   | x |
[@REQ2.1@](../docs/01_requirements.md#L77) |   | x |

---

**Statistics**:
- Total REQ tags: 24
- Total ARC tags: 10
- Total links: 28
- Coverage: 100.0% (10/10 ARC tags have upstream links)
- Orphaned REQ tags: 2 (no links)
```

**Key features:**

- **Clickable hyperlinks**: Each tag ID links directly to the source file and line number (GitHub/GitLab compatible)
- **Coverage statistics**: See at a glance which requirements are fully traced and which are orphaned
- **Sparse matrix**: Empty cells indicate no direct traceability link
- **Dynamic generation**: Tables adapt automatically to your `config.md` structure

**Use cases:**

- Quick visual verification of traceability coverage
- Gap analysis for requirements without downstream implementation
- Documentation for compliance audits
- Inclusion in design review documents

---

## 🔧 Command Reference

```text
Usage: shtracer <configfile> [options]

Options:
  -c <old_tag> <new_tag>           Change mode: swap or rename trace target tags
  -v                               Verify mode: detect duplicate or isolated tags
  -t                               Test mode: execute unit tests
  --html                           Export a single HTML document to stdout (JSON -> viewer)
  --markdown                       Export a print-friendly Markdown report to stdout (JSON -> markdown)
  --summary                        Print traceability summary to stdout (direct links only)
  --debug                          Keep  and output tag table to stderr
  -h, --help                       Show this help message

Examples:
  1. Normal mode (JSON output)
     $ ./shtracer ./sample/config.md
     $ ./shtracer ./sample/config.md > output.json

  2. Change mode (swap or rename tags)
     $ ./shtracer -c old_tag new_tag ./sample/config.md

  3. Verify mode (check for duplicate or isolated tags)
     $ ./shtracer -v ./sample/config.md

  4. Test mode
     $ ./shtracer -t

  5. Summary mode
     $ ./shtracer --summary ./sample/config.md

  6. HTML mode
     $ ./shtracer --html ./sample/config.md > output.html

  7. Markdown mode
     $ ./shtracer --markdown ./sample/config.md > report.md

  8. Debug mode (JSON + tag table to stderr)
     $ ./shtracer --debug ./sample/config.md > output.json

Note:
  - Arguments can be specified in any order.
  - Only one option can be used at a time.
```

---

## 💡 Use Cases

### 1️⃣ **Continuous Compliance Validation**

Enforce traceability in your CI pipeline with **specific exit codes**:

```yaml
# GitHub Actions example
jobs:
  traceability:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Verify traceability
        run: |
          chmod +x ./shtracer

          # Run verification mode
          ./shtracer -v config.md
          exit_code=$?

          # Handle specific error types
          case $exit_code in
            0)
              echo "✅ All traceability checks passed"
              ;;
            20)
              echo "❌ Found isolated tags (no downstream references)"
              exit 1
              ;;
            21)
              echo "❌ Found duplicate tags"
              exit 1
              ;;
            22)
              echo "❌ Found both isolated and duplicate tags"
              exit 1
              ;;
            *)
              echo "❌ Verification failed with exit code $exit_code"
              exit 1
              ;;
          esac

      - name: Check JSON output for completeness
        run: |
          ./shtracer config.md > trace.json

          # Ensure all requirements are traced to tests
          incomplete=$(jq '[.chains[] | select(. | length < 5 and .[0] != "NONE")] | length' trace.json)
          if [ "$incomplete" -gt 0 ]; then
            echo "❌ Found $incomplete incomplete trace chains"
            exit 1
          fi
```

**Available Exit Codes for CI/CD:**

- `0` - Success
- `1` - Invalid usage or arguments
- `2` - Config file not found
- `10` - Failed to extract tags
- `11` - Failed to create tag table
- `12` - Failed to generate JSON
- `20` - Found isolated tags (verify mode)
- `21` - Found duplicate tags (verify mode)
- `22` - Found both isolated and duplicate tags (verify mode)

### 2️⃣ **Automated Documentation**

Generate up-to-date traceability reports on every commit:

```bash
# In your CI/CD pipeline
./shtracer --html config.md > docs/traceability.html
git add docs/traceability.html
git commit -m "docs: update traceability matrix [skip ci]"
```

### 3️⃣ **Requirements Refactoring (Change Mode)**

Safely rename requirements across your entire project:

```bash
# Rename REQ-001 to REQ-AUTH-001 everywhere
./shtracer -c @REQ-001@ @REQ-AUTH-001@ config.md
```

**Use cases:**

- Renaming requirements during refactoring
- Swapping test case identifiers
- Reorganizing architecture tags

### 4️⃣ **Quality Audits (Verify Mode)**

Detect traceability issues before they become problems:

```bash
# Run verification mode
./shtracer -v config.md

# View health indicators in markdown report
./shtracer --markdown config.md > report.md

# View health indicators in HTML report
./shtracer --html config.md > report.html

# Query health data programmatically
./shtracer config.md | jq '.health.isolated_tag_list'
./shtracer config.md | jq '.health.dangling_reference_list'
```

**Detects:**

<details>
<summary><strong>Duplicate Tags</strong></summary>

Tags that appear in multiple locations with the same identifier.

```markdown
<!-- file1.md -->
<!-- @REQ-001@ -->
## Feature A

<!-- file2.md -->
<!-- @REQ-001@ -->  <!-- ❌ Duplicate! -->
## Feature B
```

**Exit code:** `21` (verify mode)

</details>

<details>
<summary><strong>Isolated Tags</strong></summary>

Tags with no downstream traceability - nothing references them via `(FROM: @TAG@)` syntax.

```markdown
<!-- architecture.md -->
<!-- @ARC-999@ -->  <!-- ⚠️ Nothing references this -->
## Isolated Component

<!-- Expected but missing: -->
<!-- # @IMP-X.X@ (FROM: @ARC-999@) in implementation files -->
```

**Why it matters:**
- Indicates unused specifications
- Incomplete implementation
- Orphaned requirements that should be traced

**How to fix:**
- Add implementation/test tags that reference the isolated tag
- Remove the isolated tag if no longer needed
- Update FROM: references to connect to the traceability chain

**Exit code:** `20` (verify mode)

**Where to find:**
- Markdown report: "Isolated Tags" section with file:line references
- HTML report: "Traceability Health" section with clickable links
- JSON output: `health.isolated_tag_list` array

</details>

<details>
<summary><strong>Dangling References</strong></summary>

Tags that reference non-existent parent tags via `(FROM: @PARENT@)` syntax.

```markdown
<!-- implementation.sh -->
# @IMP1.1@ (FROM: @ARC-999@)  <!-- ❌ @ARC-999@ doesn't exist! -->
function my_feature() {
    ...
}
```

**Why it matters:**
- Indicates broken traceability links
- Typos in tag references
- Deleted/renamed requirements without updating references

**How to fix:**
- Correct the FROM: reference to point to the right parent tag
- Create the missing parent tag if it should exist
- Remove the FROM: reference if it's no longer needed

**Exit code:** `23` (verify mode)

**Where to find:**
- Markdown report: "Dangling References" table showing child → missing parent
- HTML report: "Traceability Health" section with interactive table
- JSON output: `health.dangling_reference_list` array

**Example JSON:**
```json
{
  "health": {
    "dangling_references": 2,
    "dangling_reference_list": [
      {
        "child_tag": "@IMP1.1@",
        "missing_parent": "@ARC-999@",
        "file_id": 2,
        "line": 69
      }
    ]
  }
}
```

</details>

<details>
<summary><strong>Exit Codes for CI/CD Integration</strong></summary>

Use exit codes to fail builds when traceability issues are detected:

- `20` - Isolated tags found
- `21` - Duplicate tags found
- `23` - Dangling references found
- `25` - Duplicate tags and dangling references found
- `26` - Multiple issues found (combinations of isolated, duplicate, and dangling)

**Example CI pipeline:**
```bash
# Fail build if any traceability issues exist
./shtracer -v config.md
if [ $? -ne 0 ]; then
    echo "❌ Traceability issues detected!"
    exit 1
fi
```

</details>

---

## 🛠️ Development & Testing

### System Requirements

**POSIX-Compliant Shell** (bash, dash, zsh, etc.)

- ✅ Linux/macOS: Built-in by default
- ✅ Windows: Git Bash, WSL, MinGW, or Cygwin

**Optional Dependencies**

- [shUnit2](https://github.com/kward/shunit2) - Unit testing framework
- [shellcheck](https://www.shellcheck.net/) - Shell script linter
- [shfmt](https://github.com/mvdan/sh) - Shell script formatter

### Running Tests

```bash
# Run all unit tests (66 unit tests)
./shtracer -t

# Run integration tests (32 tests)
./scripts/test/integration/shtracer_integration_test.sh

# Lint shell scripts
shellcheck ./shtracer ./scripts/main/*.sh

# Format shell scripts (use v3.8.0 to match CI)
shfmt -w -i 2 -ci -bn ./shtracer ./scripts/main/*.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
