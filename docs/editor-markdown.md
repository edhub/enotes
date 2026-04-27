# Editor Markdown

## Supported syntax

Block:
- headings `#` … `######`
- blockquote `>`
- unordered list `-` `*` `+`
- ordered list `1.`
- horizontal rule `---` `***` `___`

Inline:
- bold `*...*` `**...**` `***...***` `_..._` `__...__`
- strikethrough `~~...~~`
- highlight `==...==`
- inline code `` `...` ``
- link `[text](url)`

## Intentional limits

- no fenced code block mode
- no italic-only style; single `*` / `_` is treated as bold
- no cross-line inline matching

## Visual rules

- heading emphasis = color + semibold, not large scale jumps
- raw markdown delimiters stay visible
- search highlighting is a post-process over parsed spans
