# Test data for markdown comment removal

## Inline comments
This line has <!-- inline comment --> text after.

## Multi-line comments
Text before comment
<!-- This is a
multi-line
comment -->
Text after comment

## Backtick preservation (exception case)
This `code <!-- should be preserved -->` is in backticks.

## Multiple inline comments
Before <!-- first --> middle <!-- second --> after.

## Comment at start of line
<!-- At start --> followed by text

## Comment at end of line
Text followed by <!-- at end -->

## Empty comment
Text with <!-- --> empty comment.

## Nested angle brackets (not technically nested comments)
Text <!-- comment with <tag> inside --> more text.

## No comment
This line has no comment at all.

## Edge case: Malformed (unclosed)
<!-- This comment is not closed
This line is inside the unclosed comment
This line too
