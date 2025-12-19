# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-12-19

### Added
- Circular reference detection in `join_tag_pairs` function ([c66428d](https://github.com/qq3g7bad/shtracer/commit/c66428d))
  - Prevents infinite loops when tags reference each other
  - Provides clear error messages for debugging
- Comprehensive integration tests ([970c3fc](https://github.com/qq3g7bad/shtracer/commit/970c3fc))
  - End-to-end testing for normal, verify, and change modes
  - Multi-file traceability validation
  - Error handling scenarios
- Git hooks for code quality enforcement ([5f08982](https://github.com/qq3g7bad/shtracer/commit/5f08982))
  - Pre-commit hooks for shellcheck and shfmt
  - Automated code quality checks before commits
  - Development setup documentation

### Changed
- Suppress PRE/POST-EXTRA-SCRIPT output in verify mode ([57ace8e](https://github.com/qq3g7bad/shtracer/commit/57ace8e))
  - Cleaner verification output
  - Only shows actual verification results
- Reorganized test structure ([c6b0a59](https://github.com/qq3g7bad/shtracer/commit/c6b0a59))
  - Renamed test files to follow unittest naming convention
  - Moved unit test data to dedicated `unit_test/` directory
  - **52 tests total - all passing**
- Improved documentation for Git hooks installation ([5f81925](https://github.com/qq3g7bad/shtracer/commit/5f81925))

### Fixed
- Restored tag table output in normal mode ([b883165](https://github.com/qq3g7bad/shtracer/commit/b883165))
  - Tag table was incorrectly suppressed in all modes
  - Now only suppressed in verify mode on success
- Syntax highlight offset error ([20f0677](https://github.com/qq3g7bad/shtracer/commit/20f0677))
  - Corrected line number calculations for syntax highlighting
- Improved HTML output ([ad2b5b8](https://github.com/qq3g7bad/shtracer/commit/ad2b5b8))
  - Better Base64 encoding handling
  - Enhanced UTF-8 support
  - More reliable HTML generation

### Performance
- Optimized absolute path calculation in tag extraction ([a05b827](https://github.com/qq3g7bad/shtracer/commit/a05b827))
  - Reduced redundant path operations
  - Faster tag processing for large codebases

## [0.1.0] - 2025-12-16

### Added
- Comprehensive security considerations section in README ([#978ba61](https://github.com/qq3g7bad/shtracer/commit/978ba61))
  - Warnings about arbitrary code execution via PRE/POST-EXTRA-SCRIPT
  - Best practices for safe usage
  - Examples of dangerous configurations
- Error handling test for invalid config paths (@UT1.21@) ([#0c14383](https://github.com/qq3g7bad/shtracer/commit/0c14383))
- GitHub Actions CI workflow ([#10](https://github.com/qq3g7bad/shtracer/pull/10))
  - Automated testing on Ubuntu and macOS
  - Verification mode checks
  - Sample execution validation
- Comprehensive test cases for core functions ([#11](https://github.com/qq3g7bad/shtracer/pull/11))
  - 15 tests for shtracer_func.sh
  - 6 tests for shtracer_html.sh
  - 21 tests for main shtracer script
- Ignore filter functionality for excluding files/directories
- PRE-EXTRA-SCRIPT and POST-EXTRA-SCRIPT execution support ([#9](https://github.com/qq3g7bad/shtracer/pull/9))

### Changed
- Improved .gitignore with comprehensive patterns ([#efd52d2](https://github.com/qq3g7bad/shtracer/commit/efd52d2))
  - Editor/IDE files (vim, VSCode, IntelliJ)
  - Backup files (*.bak, *.backup, *.tmp)
  - OS-specific files (.DS_Store, Thumbs.db)
  - Test artifacts (*.log)
- Enhanced documentation accuracy
  - Fixed typos: "traceability", "searching", "extension" ([#eae590a](https://github.com/qq3g7bad/shtracer/commit/eae590a))
  - Corrected test script references in test README ([#4bc77d3](https://github.com/qq3g7bad/shtracer/commit/4bc77d3))
  - Expanded implementation details for helper functions
- Decomposed heavy functions into focused helpers ([#12](https://github.com/qq3g7bad/shtracer/pull/12))
  - Improved maintainability while preserving functionality
  - Better code organization and readability

### Fixed
- **Critical**: Resolved CI failures caused by incorrect tag references ([#172a645](https://github.com/qq3g7bad/shtracer/commit/172a645))
  - Removed unnecessary helper function tags (IMP*.*.*)
  - Fixed infinite loops in traceability processing
  - Simplified RTM to REQ → ARC → IMP → TEST flow
- Corrected typo in error_exit function name ([#3a300df](https://github.com/qq3g7bad/shtracer/commit/3a300df))
  - "load_fucntions" → "load_functions"
- Resolved all ShellCheck warnings (SC2181) ([#50d6714](https://github.com/qq3g7bad/shtracer/commit/50d6714))
  - Improved error handling patterns
  - Direct command testing instead of indirect $? checks
- Fixed typo in tag error message: "joine_tag_pairs" → "join_tag_pairs"
- Multiple directory search functionality
- UML flowchart generation issues
- Extension filter handling in HTML output

### Removed
- Helper function traceability tags from documentation and code
  - Internal implementation details no longer clutter the RTM
  - Allows refactoring freedom without documentation updates

### Security
- **Important**: Added comprehensive security warnings about script execution
  - PRE/POST-EXTRA-SCRIPT can execute arbitrary commands
  - Recommendations for trusted environments only
  - Sandboxing suggestions for security-sensitive use cases

## [0.0.2] - 2024-12-28

### Fixed
- Minor warning fixes

## [0.0.1] - 2024-12-15

### Added
- Initial release
- Basic requirements traceability matrix generation
- Markdown-based configuration
- HTML output with Mermaid diagrams
- Tag verification mode
- Tag swap/rename functionality

[Unreleased]: https://github.com/qq3g7bad/shtracer/compare/V0.1.1...HEAD
[0.1.1]: https://github.com/qq3g7bad/shtracer/compare/V0.1.0...V0.1.1
[0.1.0]: https://github.com/qq3g7bad/shtracer/compare/V0.0.2...V0.1.0
[0.0.2]: https://github.com/qq3g7bad/shtracer/compare/V0.0.1...V0.0.2
[0.0.1]: https://github.com/qq3g7bad/shtracer/releases/tag/V0.0.1
