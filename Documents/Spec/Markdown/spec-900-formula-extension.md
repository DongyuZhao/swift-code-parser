# Formula Extension (Internal Spec)

Status: Internal extension for this repository. Not part of CommonMark/GFM.

## Overview

This extension adds math formula parsing to Markdown with both inline and display forms. The resulting AST introduces two node kinds:
- `FormulaNode` (inline): element `.formula`, property `expression: String`
- `FormulaBlockNode` (block): element `.formulaBlock`, property `expression: String`

Unless stated otherwise, plain text outside formulas follows the standard CommonMark rules.

## Delimiters and rules

1) Inline dollar form `$ ... $`
- Syntax: a pair of dollar signs delimiting the expression, no unescaped newlines inside.
- Whitespace directly inside the delimiters is not allowed; the following MUST NOT parse:
  - `$ x$`, `$x $`
- Escaped dollar is allowed inside the expression and preserved in `expression` (e.g. `$a\$b$` -> `expression: "a\\$b"`).
- Unclosed single `$` does not start a formula and remains literal text.

2) Display dollar form `$$ ... $$`
- Syntax: a pair of double dollar signs delimiting a block-level formula.
- Newlines inside are allowed and preserved in `expression` (modulo any implementation normalization of spaces/newlines).
- If the closing `$$` is missing, the formula block consumes until EOF (no second block is created by subsequent backslash delimiters).

3) Backslash inline form `\( ... \)`
- Recognized as an inline formula.
- Implementation note: the inline builder currently preserves the delimiters in `expression`. Example: input `Before \(a+b\) end` yields a `FormulaNode` with `expression: "\\(a+b\\)"`.

4) Backslash display form `\[ ... \]`
- Recognized as a block formula (`FormulaBlockNode`).
- Delimiters are trimmed from `expression`. Example: input `\[ x^2 + y^2 \]` yields `expression: "x^2 + y^2"`.

5) Interaction with other inline constructs
- Code spans take precedence and suppress formula parsing inside backticks: `` `$a$` and $b$ `` produces only one inline formula with `expression: "b"`.
- Adjacent inline formulas are allowed: `Text$A$B$C$Text` produces two formulas (`A` and `C`).

## Examples (informative)

- Inline: `Euler: $e^{i\\pi}+1=0$`
  - AST excerpt: `paragraph[text("Euler: "),formula("e^{i\\pi}+1=0")]`

- Display: `$$x^2 +\n y^2$$`
  - AST excerpt: `formula_block("x^2 +\n y^2")`

- Unclosed display: `$$x + 1\nNext line\n\\[ y+2`
  - AST excerpt: one `formula_block` containing `x + 1\nNext line\n\\[ y+2`

- Invalid inline whitespace: `$ x$`, `$x $` -> not parsed as formula; remain text.

- Backslash inline: `Before \\(a+b\\) end`
  - AST excerpt: `paragraph[text("Before "),formula("\\(a+b\\)"),text(" end")]`

- Backslash display: `\\[ x^2 + y^2 \\]`
  - AST excerpt: `formula_block("x^2 + y^2")`

## Rationale

These rules are chosen to be predictable and to avoid ambiguity with CommonMark inline parsing (notably code spans). The whitespace restriction for `$...$` mirrors common math markdown conventions and helps reduce accidental captures.

## Conformance

The test suite `MarkdownFormulaTests.swift` is the authoritative reference for this extension’s behavior. This document summarizes those expectations for easier maintenance.
