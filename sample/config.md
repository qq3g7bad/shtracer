# config.md

## Requirement

* **PATH**: "../docs/01_requirements.md"                     <!-- It can be a relative or absolute path. If you use a relative path, this file (config.md) is the starting point. -->
  * **BRIEF**: "Describes requirements as specifications."
  * **TAG FORMAT**: `@REQ[0-9\.]+@`                          <!-- Tag format must be written in ERE (Extended regular expressions) and surrounded backquotes for discriminating other comment blocks in markdown. -->
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1                                  <!-- Relationship between the tag and its title: default is 1 -->

## Architecture

* **PATH**: "../docs/02_architecture.md"
  * **BRIEF**: "Describes the structure of this project."
  * **TAG FORMAT**: `@ARC[0-9\.]+@`
  * **TAG LINE FORMAT**: `<!--.*-->`
  * **TAG-TITLE OFFSET**: 1

## Main scripts

### Implementation

* **PATH**: "../shtracer"
  * **TAG FORMAT**: `@IMP[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "All files are shell scripts."
* **PATH**: "../scripts/main/"
  * **EXTENSION FILTER**: "*.sh"
  * **TAG FORMAT**: `@IMP[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "All files are shell scripts."

### Unit test

<!-- IF THERE ARE TOO MANY TRACE TARGET LIKE SOFTWARE REPOSITORY, -->
<!-- USE DIRECTORY PATHS TO TRACE. -->

* **PATH**: "../scripts/test/"
  * **BRIEF**: "All files are shell scripts."
  * **EXTENSION FILTER**: "*.sh"
  * **IGNORE FILTER**: "shunit2|unittest_sample|testdata|*integration*" <!-- Multiple conditions are acceptable by using "|". -->
  * **TAG FORMAT**: `@UT[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`

## Optional scripts

### Implementation

* **PATH**: "../shtracer"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/optional/"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/optional/"
  * **EXTENSION FILTER**: "*.py"
  * **BRIEF**: "Not implemented yet"

### Unit test

<!-- IF THERE ARE TOO MANY TRACE TARGET LIKE SOFTWARE REPOSITORY, USE DIRECTORY PATHS TO TRACE. -->

* **PATH**: "../scripts/test/optional/"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/test/optional/"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"

## Integration test

* **PATH**: "../scripts/test/"
  * **EXTENSION FILTER**: "*.sh"
  * **IGNORE FILTER**: "shunit2|testdata" <!-- Multiple conditions are acceptable by using "|". -->
  * **TAG FORMAT**: `@IT[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "Integration tests for end-to-end workflows."
* **PATH**: "../.github/workflows/"
  * **EXTENSION FILTER**: "*.yml"
  * **TAG FORMAT**: `@IT[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "CI/CD workflow definitions."
