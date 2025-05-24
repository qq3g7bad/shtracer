# 🐚 shtracer

Open source traceability matrix generator written in shell scripts.

## 🚩 About

ShellTracer (**shtracer**) is a project for creating a [requirements traceability matrix](https://en.wikipedia.org/wiki/Traceability_matrix) (RTM) easily.

* For maximum extensibility and easy version control, simplify the input/output files as text files.
* For portability, use only shell scripts to create RTMs.

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

opt_input --> targetfiles : pre-extra-scripts
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
rtm --> opt_output : post-extra-scripts
rtm --> html_output
uml --> html_output

```

## 📷 Screenshots

### HTML output

![sample](./docs/img/sample.png)

### Text output

* Each row traces documents and source files by tags.

```text
@REQ1.2@ @ARC2.1@ @IMP2.1@ @UT1.1@ @IT1.1@
@REQ1.2@ @ARC3.1@ @IMP3.1@ @UT1.2@ @IT1.1@
@REQ1.4@ @ARC2.1@ @IMP2.1@ @UT2.1@ @IT1.1@
```
### UML

* Drawn by Mermaid.

```mermaid
flowchart TB

start[Start]
id1([Requirement])
id2([Architecture])
id3_1_1([Implementation])
id3_1_2([Unit test])
id3_2_1([Implementation])
id3_2_2([Unit test])
id4([Integration test])
stop[End]

start --> id1
id1 --> id2
id2 --> id3_1_1
subgraph "Main scripts"
id3_1_1 --> id3_1_2
end
id2 --> id3_2_1
subgraph "Optional scripts"
id3_2_1 --> id3_2_2
end
id3_1_2 --> id4
id3_2_2 --> id4
id4 --> stop
```

## 🥅 Goal

* Make the requirements traceability matrix (RTM) through markdown formatted text files.
* Use only normal shell scripts and no other programs.

## ⚽ Getting started

1. Open bash.
1. Set the current directory at this repository.
1. Enter the following commands.

```bash
# Change mode
chmod +x ./shtracer

# Read a configuration file and create a traceability matrix
./shtracer ./sample/config.md
```

## 🚀 Usage

```text
Usage: shtracer <configfile> [options]

Options:
  -c <before_tag> <after_tag>      Change mode: swap or rename trace target tags
  -v                               Verify mode: detect duplicate or isolated tags
  -t                               Test mode: execute unit tests
  -h, --help                       Show this help message

Examples:
  1. Normal mode
     $ ./shtracer ./sample/config.md

  2. Change mode (swap or rename tags).
     $ ./shtracer ./sample/config.md -c old_tag new_tag.

  3. Verify mode (check for duplicate or isolated tags).
     $ ./shtracer ./sample/config.md -v

  4. Test mode
     $ ./shtracer -t

Note:
  - The <configfile> argument must always be specified before options.

```

### Change tag mode

* Change tags written in all trace targets.
* This function is useful when requirements are updated or revised.

### Verify tag mode

* Verify whether tags are duplicated or isolated.

<details>
<summary>Duplicated</summary>

#### Duplicated

```markdown
<!-- in file1 -->
<!-- @TAG1@ -->
## TEST TARGET 1
```

```markdown
<!-- in file2 -->
<!-- @TAG1@ -->
## TEST TARGET 2
```

</details>

<details>
<summary>Isolated</summary>

#### Isolated

```markdown
<!-- in file1 -->
<!-- @TAG1@ -->
## TEST TARGET 1
```

* Except for this, `@TAG1@` never appears in the trace targets.

</details>

## 🗂️ Features

* Create traceability markdown files from following input files.
  * Markdown files which include contents to trace.
  * These contents are indexed by their own IDs.
  * Connections between files are specified by IDs.
  * These IDs are written in each markdown file as comment blocks.
* (Optional) Use markdown files as intermediate products.
  * Create intermediate markdown files from other file format by using some scripts.
  * Create non-markdown output files by using some scripts.

For details, see documents in `./docs/` directory.

## 🌏 Requirements

* **POSIX-Compliant Shell**:
  * shtracer is written in POSIX-compliant shell scripting, ensuring compatibility across a wide range of systems. Although it is commonly used with bash, it should work with any POSIX-compliant shell.
  * **Linux/macOS**:
    * A POSIX shell is typically included by default on Linux and macOS systems.
  * **Windows**:
    * Windows does not include a POSIX-compliant shell natively. To use shtracer on Windows, you can install one of the following:
      * Git Bash
      * MinGW
      * Cygwin

### Optional

* [shUnit2](https://github.com/kward/shunit2) (for unit testing)
* [highlight.js](https://highlightjs.org/) (for syntax highlighting)
* [mermaid.js](https://mermaid.js.org/) (for showing UMLs)

## 📝 Contribution

* RTM is important not only in software field but also in other fields, so that contributions from other fields are welcomed.
* Consider using [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) rules for creating explicit and meaningful commit messages.

## ✅ TODO

* Use custom css files for html output.
* Use OR condition in the extension filter.

