# Excel Spreadsheet Workflow (Future Feature)

This directory is reserved for examples of using Microsoft Excel spreadsheets (`.xlsx`) as a source for requirements traceability.

## Status: Planned

Excel spreadsheet support is planned for future implementation. This will enable:

- Requirements tables in Excel format
- Traceability matrix management in spreadsheets
- Conversion from `.xlsx` to Markdown for shtracer processing
- Collaboration with stakeholders who prefer Excel

## Challenges

Excel support presents unique challenges compared to Word documents:

1. **Structured data extraction** - Requirements may be organized in tables/rows
2. **Cell comments** - Tags might live in Excel cell comments
3. **Multiple sheets** - Workbooks may contain multiple sheets with different trace targets
4. **Formatting preservation** - Tables, formulas, and conditional formatting
5. **Conversion tools** - Need reliable xlsx → markdown conversion

## Potential Approaches

### Option 1: Cell Comments for Tags

Similar to Word workflow:
- Add `@REQ-001@` as Excel cell comments
- Convert cell comments to Markdown during xlsx → md conversion
- Extract tags from resulting HTML comments

### Option 2: Dedicated Tag Column

Structured approach:
- Use dedicated column for tags (e.g., Column A: "Tag", Column B: "Requirement")
- Convert table rows to Markdown list items or tables
- Extract tags from structured markdown

### Option 3: Hybrid Approach

Combination:
- Support both cell comments and dedicated columns
- Flexible configuration based on spreadsheet structure
- Multiple conversion strategies for different use cases

## Tools Under Consideration

- [pandoc](https://pandoc.org/) - Universal document converter (limited xlsx support)
- [xlsx2csv](https://github.com/dilshod/xlsx2csv) - Convert Excel to CSV
- [openpyxl](https://openpyxl.readthedocs.io/) - Python library for Excel files
- Custom shell script using `unzip` + XML parsing (xlsx files are zipped XML)

## Contributing

If you're interested in Excel workflow support, please:

1. Open an issue describing your use case
2. Share example Excel files showing how you'd like to organize requirements
3. Contribute conversion scripts or tools you've found useful

## Placeholder Files

This directory currently serves as a placeholder. Implementation will be added in future releases.

For now, consider using Word documents (see `../docx_workflow/`) as an alternative format that's well-supported by pandoc-comment-extractor.
