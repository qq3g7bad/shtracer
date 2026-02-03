# Changelog

## [0.1.4] - 2026-01-25

### Changed (BREAKING)
- **Verify mode error messages** now use one-line-per-error format (Unix-style) instead of multi-line format
- **Exit code for dangling tags** changed from 23 to 22
- **Removed bitmask exit codes** (23, 24, 25, 26 no longer used)
- **Verify mode uses priority-based exit**: duplicates (21) → dangling (22) → isolated (20)
- **Error message prefix changed**: From `[shtracer][error][print_verification_result]` to specific error types `[isolated_tags]`, `[duplicated_tags]`, `[dangling_tags]`

### Benefits
- Better Unix philosophy compliance (one-line-per-error)
- Easier to parse with grep/awk/cut
- Simpler exit code logic (3 codes instead of 7)
- Filterable error output for CI/CD integration

### Migration Guide
```bash
# OLD CI/CD script (v0.1.3)
if [ $? -eq 23 ]; then
    echo "Found dangling tags"
fi

# NEW CI/CD script (v0.1.4+)
if [ $? -eq 22 ]; then
    echo "Found dangling tags"
fi

# OLD log parsing
grep "Following tags are duplicated" logfile

# NEW log parsing
grep '\[duplicated_tags\]' logfile
```

### Implementation Details
- Detailed verification files in `shtracer_output/tags/verified/` remain unchanged
- All detected issues still reported to stderr (one line each)
- Exit code reflects only the highest-priority error type
- `print_verification_result()` signature changed to accept 4 separate parameters
- Removed `_calculate_verification_bitmask()` and `get_verification_status()` functions

---
