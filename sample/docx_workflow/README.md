# Word Document Workflow Example

This example demonstrates how to use Microsoft Word documents as the source for requirements traceability with shtracer.

## Overview

**Key Concept**: Add shtracer tags as Word comments, convert to Markdown, then trace with shtracer.

- **Word file is the master** - Both technical and non-technical team members edit `requirements.docx`
- **Tags in comments** - Add `@REQ-001@` or `@REQ-002@ (FROM: @REQ-001@)` as Word comments
- **Automatic conversion** - Use pandoc-comment-extractor to convert to Markdown
- **No manual editing** - Tags automatically appear in HTML comments

## Workflow

```text
requirements.docx
  └─ Word Comment: "@REQ-001@" attached to heading
         ↓
[./convert.sh]
         ↓
requirements.md
  └─ <!-- [Author] @REQ-001@ -->
         ↓
[shtracer config.md]
         ↓
Traceability matrix
```

## Files in This Example

- **README.md** - This file
- **requirements.docx** - Example Word document with tags in comments (you need to create this)
- **requirements.md** - Example of converted Markdown file
- **convert.sh** - Conversion script using pandoc-comment-extractor
- **config.md** - Shtracer configuration for this example

## Prerequisites

1. **Pandoc 2.0+**
   ```bash
   # macOS
   brew install pandoc

   # Ubuntu/Debian
   sudo apt-get install pandoc
   ```

2. **pandoc-comment-extractor**
   ```bash
   git clone https://github.com/qq3g7bad/pandoc-comment-extractor.git
   # Update the path in convert.sh to point to your clone
   ```

## How to Use

### Step 1: Create Word Document with Tags

Create `requirements.docx` with the following structure:

1. Write heading: **"User Authentication"**
2. Select the heading, add Word comment: `@REQ-001@`
3. Write heading: **"Password Requirements"**
4. Select the heading, add Word comment: `@REQ-002@ (FROM: @REQ-001@)`

### Step 2: Convert to Markdown

```bash
# Edit convert.sh to set the correct path to pandoc-comment-extractor
# Then run:
./convert.sh
```

This generates `requirements.md` with tags in HTML comments.

### Step 3: Run shtracer

```bash
../../shtracer config.md
```

This generates the traceability matrix from the converted Markdown file.

### Step 4: View Results

```bash
# View traceability chains
cat shtracer_output/tags/04_tag_table

# Generate HTML report
../../shtracer --html config.md > report.html
```

## Example Output

After conversion, `requirements.md` looks like:

```markdown
<!-- [Alice] @REQ-001@ -->
## User Authentication

Users must authenticate before accessing the system.

<!-- [Alice] @REQ-002@ (FROM: @REQ-001@) -->
## Password Requirements

Passwords must be at least 8 characters long.
```

Shtracer extracts these tags and builds the traceability matrix.

## Tips

- **Tag format**: Use consistent patterns like `@REQ-001@`, `@REQ-002@`
- **FROM notation**: Specify upstream tags with `@REQ-002@ (FROM: @REQ-001@)`
- **Comment position**: Attach Word comments to headings for clear association
- **Mixed comments**: Regular review comments and tag comments can coexist
- **Version control**: Commit both `.docx` (master) and `.md` (for git diffs)

## Next Steps

After mastering Word document workflow, you can:

1. **Add architecture tags** - Create `architecture.docx` with `@ARC-001@` tags
2. **Link to code** - Add `(FROM: @ARC-001@)` in your shell scripts
3. **Full traceability** - Track from requirements → architecture → implementation → tests
4. **CI/CD integration** - Automate conversion and validation in your pipeline

For more details, see the main [README.md](../../README.md) section "Working with Word Documents".
