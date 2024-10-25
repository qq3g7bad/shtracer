# config.md

## Requirement

* **PATH**: "../docs/01_requirements.md"                     <!-- It can be a relative or absolute path. If you use a relative path, this file is the starting point. -->
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

## (fork)

<!-- TO SPLIT THE TRACE TARGET FLOW, USE "(fork)" AS A SECTION TITLE -->

### Main scripts

#### Implementation

<!-- IF THERE ARE MULTIPLE TRACE TARGETS BUT YOU DON'T WANT TO SPLIT THE TRACE FLOW, -->
<!-- YOU DON'T NEED TO USE "(fork)" AND JUST ENTER MULTIPLE PATHS. -->

* **PATH**: "../shtracer"
  * **TAG FORMAT**: `@IMP[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "All files are shell scripts."
* **PATH**: "../scripts/main/"
  * **EXTENSION FILTER**: "*.sh"
  * **TAG FORMAT**: `@IMP[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`
  * **BRIEF**: "All files are shell scripts."

#### Unit test

<!-- IF THERE ARE TOO MANY TRACE TARGET LIKE SOFTWARE REPOSITORY, -->
<!-- USE DIRECTORY PATHS TO TRACE. -->

* **PATH**: "../scripts/test/"
  * **BRIEF**: "All files are shell scripts."
  * **EXTENSION FILTER**: "*.sh"
  * **TAG FORMAT**: `@UT[0-9\.]+@`
  * **TAG LINE FORMAT**: `#.*`

### Optional scripts

#### Implementation

<!-- IF THERE ARE MULTIPLE TRACE TARGETS BUT YOU DON'T WANT TO SPLIT THE TRACE FLOW, -->
<!-- YOU DON'T NEED TO USE "(fork)" AND JUST ENTER MULTIPLE PATHS. -->

* **PATH**: "../shtracer"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/optional/"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/optional/"
  * **EXTENSION FILTER**: "*.py"
  * **BRIEF**: "Not implemented yet"

#### Unit test

<!-- IF THERE ARE TOO MANY TRACE TARGET LIKE SOFTWARE REPOSITORY, USE DIRECTORY PATHS TO TRACE. -->

* **PATH**: "../scripts/test/optional/"
  * **BRIEF**: "Not implemented yet"
* **PATH**: "../scripts/test/optional/"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"

## Integration test

* **PATH**: "../scripts/test/integration/"
  * **EXTENSION FILTER**: "*.sh"
  * **BRIEF**: "Not implemented yet"
