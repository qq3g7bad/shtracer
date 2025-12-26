# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Section Sequence Swapping** ([2d052f3](https://github.com/qq3g7bad/shtracer/commit/2d052f3))
  - New feature to swap the order of sections in the output
  - Improves flexibility in organizing traceability documentation

### Changed
- **Output Directory Cleanup** ([cec6b0e](https://github.com/qq3g7bad/shtracer/commit/cec6b0e))
  - Output directory is now cleaned up by default before generation
  - Prevents stale files from accumulating
  - Can be disabled with `--debug` flag ([a74d2bb](https://github.com/qq3g7bad/shtracer/commit/a74d2bb))
- **Documentation Updates**
  - Updated screenshots in README ([d553739](https://github.com/qq3g7bad/shtracer/commit/d553739))
  - Updated README.md content ([3e6136a](https://github.com/qq3g7bad/shtracer/commit/3e6136a), [08d229b](https://github.com/qq3g7bad/shtracer/commit/08d229b))

### Fixed
- **Viewer Improvements**
  - Stack multiple targets from same source vertically ([9ab676f](https://github.com/qq3g7bad/shtracer/commit/9ab676f))
  - Stabilize traceability flow diagram sizing ([3155be4](https://github.com/qq3g7bad/shtracer/commit/3155be4))
  - Fix viewer hardcoding issues ([d3bd8f3](https://github.com/qq3g7bad/shtracer/commit/d3bd8f3))
- **Parser and Output Fixes**
  - Allow TAG-TITLE OFFSET value of 0 for table format tags ([74e92bb](https://github.com/qq3g7bad/shtracer/commit/74e92bb))
  - Fix JSON parse escape error ([7735763](https://github.com/qq3g7bad/shtracer/commit/7735763))
  - Fix output directory naming ([4f576fe](https://github.com/qq3g7bad/shtracer/commit/4f576fe))
- **Testing**
  - Restore original shunit2; remove incorrect reimplementation ([71c5042](https://github.com/qq3g7bad/shtracer/commit/71c5042))

## [0.1.2] - 2025-12-23

### Added
- **GitHub-Style UI Theme**
  - Light/dark mode toggle with familiar GitHub color scheme
  - Smooth theme transitions with CSS variables
  - Theme preference saved to localStorage
  - GitHub-inspired fonts: `ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas`
- **GitHub-Style Syntax Highlighting**
  - Light theme: Official GitHub light color scheme
  - Dark theme: Official GitHub dark color scheme
  - Proper color coding for keywords, strings, comments, functions, etc.
  - Applied to all code elements (code, pre, kbd, samp, tt)

### Changed
- **Improved Traceability Matrix Column Order**
  - Matrix columns now match config.md definition order (Requirement → Architecture → Implementation → Unit test → Integration test)
  - Order dynamically extracted from config.md headings
  - No hardcoded type ordering
  - Consistent with Traceability Flow (Type) diagram
- **Enhanced README**
  - Removed outdated Mermaid diagrams
  - Added detailed HTML viewer feature descriptions
  - Updated TODO section to reflect completed styling improvements

### Fixed
- Removed external highlight.js CSS dependency (now uses embedded GitHub-style CSS)

## [0.2.0] - TBD

### ⚠️ Breaking Changes

- **Removed PRE/POST-EXTRA-SCRIPT support** ([a49baa2](https://github.com/qq3g7bad/shtracer/commit/a49baa2))
  - Security risk: arbitrary code execution from config files
  - **Migration**: Remove `PRE-EXTRA-SCRIPT` and `POST-EXTRA-SCRIPT` sections from config files
  - Alternative: Use shell scripts to wrap shtracer calls if pre/post processing is needed
  - See [Migration Guide](#migration-from-v01x-to-v020) below

### Added

- **Modern Sankey Diagram Visualization** ([aeaf156](https://github.com/qq3g7bad/shtracer/commit/aeaf156), [bc9434b](https://github.com/qq3g7bad/shtracer/commit/bc9434b))
  - Replaced basic flowcharts with interactive D3.js Sankey diagrams
  - Shows traceability flow with proportional link widths
  - Improved node type colors and hover interactions
  - Better layout and spacing for complex traceability matrices
- **Self-Contained HTML Output** ([bd59a89](https://github.com/qq3g7bad/shtracer/commit/bd59a89))
  - Inline CSS and JavaScript assets directly into HTML
  - No external dependencies required
  - Single-file HTML can be shared and viewed anywhere
- **JSON-First Output Mode** ([a8330d9](https://github.com/qq3g7bad/shtracer/commit/a8330d9))
  - `--json` flag now writes structured JSON to stdout
  - Enables better integration with external tools
  - HTML viewer can consume JSON directly
- **Per-File Coverage Statistics** ([67f4104](https://github.com/qq3g7bad/shtracer/commit/67f4104), [0daf1c7](https://github.com/qq3g7bad/shtracer/commit/0daf1c7))
  - Shows coverage breakdown for each traced file
  - Unified coverage definition across CLI and viewer
  - Helps identify gaps in traceability
- **Colorized Matrix and Badge UI** ([f5f2ace](https://github.com/qq3g7bad/shtracer/commit/f5f2ace))
  - Tag type badges with distinctive colors
  - Improved visual hierarchy in HTML output
  - Better readability for large matrices
- **Comprehensive JSON Unit Tests** ([297a33d](https://github.com/qq3g7bad/shtracer/commit/297a33d))
  - Added `shtracer_json_unittest.sh` with 20+ test cases
  - Validates JSON output structure and content
  - Ensures parser correctness
- **Flexible Argument Order** ([483a4ca](https://github.com/qq3g7bad/shtracer/commit/483a4ca))
  - Options can now be specified before or after the config file
  - Examples: `shtracer --json config.md` and `shtracer config.md --json` both work
  - Full backward compatibility maintained
  - Clearer error messages for invalid option combinations

### Changed

- **Major Refactoring: Viewer Separation** ([3569ea8](https://github.com/qq3g7bad/shtracer/commit/3569ea8))
  - Split `shtracer_html.sh` (553 lines) → `shtracer_viewer.sh` (2209 lines)
  - Integrated `--html` pipeline directly into viewer
  - Better separation of concerns: core logic vs. visualization
- **Standardized Development Tools** ([242aa1f](https://github.com/qq3g7bad/shtracer/commit/242aa1f))
  - Locked shfmt version to 3.8.0 (matches CI)
  - Use shfmt v3.8.0 (matches CI)
  - Updated pre-commit hooks to use shfmt from PATH when available
  - Prevents formatting conflicts between environments
- **Improved Test Organization** ([4607b51](https://github.com/qq3g7bad/shtracer/commit/4607b51), [297a33d](https://github.com/qq3g7bad/shtracer/commit/297a33d))
  - Made test runner CWD-agnostic (can run from any directory)
  - Dropped extra-script test assertions (feature removed)
  - Added debug test helper (`debug_test.sh`)
- **Updated Documentation** ([054fba5](https://github.com/qq3g7bad/shtracer/commit/054fba5))
  - Removed "(fork)" annotations from config examples
  - Clarified that configs are project-specific, not fork-specific
- **Argument Parsing** ([483a4ca](https://github.com/qq3g7bad/shtracer/commit/483a4ca))
  - Switched from case pattern matching to two-pass while-loop parsing
  - Enables flexible argument ordering
  - Single-option-only constraint enforced more explicitly
  - Better error messages for invalid combinations

### Fixed

- **Critical: macOS Compatibility** ([242aa1f](https://github.com/qq3g7bad/shtracer/commit/242aa1f))
  - Fixed awk newline handling (macOS awk doesn't support `\n` in `-v` variables)
  - Changed to file-based input for multiline content
  - Removed POSIX-incompatible `local` keyword
  - Added proper temp file cleanup with `trap`
- **Portability: mktemp Usage** ([393af6f](https://github.com/qq3g7bad/shtracer/commit/393af6f))
  - Fallback to `-t` flag for systems without GNU mktemp
  - Ensures compatibility across Linux and macOS
- **Robustness: sed Argument Limit** ([bf79a07](https://github.com/qq3g7bad/shtracer/commit/bf79a07))
  - Avoid sed argument limit when injecting large tables
  - Use awk-based injection instead
  - Prevents failures with very large traceability matrices
- **Security: swap_tags Safety** ([68cebff](https://github.com/qq3g7bad/shtracer/commit/68cebff))
  - Made `swap_tags` portable and safe
  - Better escaping and validation
  - Prevents injection attacks
- **Timing: Tag Link Construction** ([d63198e](https://github.com/qq3g7bad/shtracer/commit/d63198e))
  - Build tag links during table rendering (not after)
  - Fixes race conditions and improves performance
- **Test Isolation** ([f36ac5f](https://github.com/qq3g7bad/shtracer/commit/f36ac5f))
  - Prevent `SHUNIT_PARENT` leakage to subtests
  - Fixes sporadic test failures

### Performance

- **Optimized CI Workflow** ([bb56ff3](https://github.com/qq3g7bad/shtracer/commit/bb56ff3))
  - Aligned workflow with JSON-first output
  - Reduced redundant processing

### Security

- **Eliminated Arbitrary Code Execution** ([a49baa2](https://github.com/qq3g7bad/shtracer/commit/a49baa2))
  - Removed dangerous PRE/POST-EXTRA-SCRIPT feature
  - Config files no longer execute arbitrary shell commands
  - Significantly reduces attack surface

### Migration from v0.1.x to v0.2.0

If your config files use `PRE-EXTRA-SCRIPT` or `POST-EXTRA-SCRIPT`:

**Before (v0.1.x):**
```markdown
## PRE-EXTRA-SCRIPT
echo "Starting trace..."

## POST-EXTRA-SCRIPT
echo "Trace complete!"
```

**After (v0.2.0):**
Remove those sections entirely. If you need pre/post processing:

```bash
#!/bin/bash
# wrapper.sh
echo "Starting trace..."
./shtracer config.md --html
echo "Trace complete!"
```

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
  - 6 tests for viewer HTML helpers
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

[Unreleased]: https://github.com/qq3g7bad/shtracer/compare/V0.1.2...HEAD
[0.1.2]: https://github.com/qq3g7bad/shtracer/compare/V0.1.1...V0.1.2
[0.2.0]: https://github.com/qq3g7bad/shtracer/compare/V0.1.1...V0.2.0
[0.1.1]: https://github.com/qq3g7bad/shtracer/compare/V0.1.0...V0.1.1
[0.1.0]: https://github.com/qq3g7bad/shtracer/compare/V0.0.2...V0.1.0
[0.0.2]: https://github.com/qq3g7bad/shtracer/compare/V0.0.1...V0.0.2
[0.0.1]: https://github.com/qq3g7bad/shtracer/releases/tag/V0.0.1
