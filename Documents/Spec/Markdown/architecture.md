Markdown Parser Architecture

Overview

This document explains the architecture so that contributors—humans, models, and agents—can extend or modify the Markdown parser safely and effectively.

At a high level:

Input String
   │
   ▼
Tokenizer  ──► [Token] (.characters / .punctuation / .whitespaces / .newline / .charef / .eof)
   │
   ▼
Block Phase (MarkdownBlockBuilder + block plugins)
   │                           └─ builds block-level AST; stores inline-eligible spans in ContentNode
   ▼
EOF ▶ Inline Phase (MarkdownContentBuilder + content processors)
                               └─ resolves delimiter runs; replaces ContentNode with inline nodes


⸻

Tokenization

The tokenizer converts the input string into a flat array of tokens:
	•	.characters — A run of non-punctuation characters as defined by the Markdown grammar. This includes escaped punctuation, which must be treated as plain text.
	•	.punctuation — A single Markdown punctuation character (e.g., *, _, [, ], (, ), >, `, !, etc.).
	•	.whitespaces — A run of whitespace characters (spaces or tabs).
	•	.newline — A single newline (\n).
	•	.charef — A character reference token (e.g., &amp;, &#xA0;), already normalized to a scalar value where applicable.
	•	.eof — An explicit end-of-file sentinel.

Tokenizer guarantees
	•	.punctuation tokens are always single-character.
	•	Runs are maximally coalesced for .characters and .whitespaces.
	•	Escaped punctuation is emitted as .characters, never .punctuation.

⸻

AST Construction

The construction stage builds an AST from the token array. It is implemented via CodeNodeBuilder components and a shared context:
	•	context.current — Cursor that allows builders to traverse and mutate the AST.
	•	context.state — A language-specific, mutable state bag for cross-line / cross-node coordination.
	•	Builders may open/close nodes, attach children, and rewrite subtrees as needed.

For Markdown, we use two entry builders:
	•	MarkdownBlockBuilder — Dispatches block parsing and populates the block-level AST.
	•	MarkdownEOFBuilder — On .eof, triggers the inline parsing pass.

Each language can provide its own context.state type to carry whatever transient information is needed.

⸻

Block Parsing

The parser strictly follows Documents/Spec/Markdown/spec-043-phase-1-block-structure.md.

Line model
	•	The token stream is split into lines using .newline as a separator.
	•	The .newline token belongs to the line it terminates.
	•	.eof is not part of any line.

Builder responsibilities

MarkdownBlockBuilder coordinates a set of block node builders (plugins). On each iteration, a builder:
	1.	Examines the current line in the context of the current AST.
	2.	Decides whether to:
	•	Close the last open block node,
	•	Open a new block node, or
	•	Append part/all of the current line to the current open node.
	3.	Emits a ContentNode under the appropriate block node for any text that requires inline parsing later.

Partial consumption & re-entry

To support nested blocks (e.g., lists, block quotes, tables), a builder may:
	•	Consume only a prefix of the line (e.g., "> " in a block quote),
	•	Set context.state.position to the next unconsumed token index, and
	•	Set context.state.refreshed = true to request that MarkdownBlockBuilder re-run dispatch on the remaining slice of the same line.

This allows patterns like:

> # Heading
^ prefix consumed by block-quote builder
  re-dispatch parses a heading on the remainder

No inline work in the block phase

Block builders never perform inline parsing. They only collect inline-eligible tokens into ContentNode placeholders attached to the appropriate block nodes.

Plugin architecture

All block node builders are decoupled from MarkdownBlockBuilder and registered as plugins. Each plugin should be:
	•	Local in scope (single responsibility),
	•	Order-aware where the CommonMark precedence requires it, and
	•	Idempotent when re-entered on the same input slice.

⸻

Inline Parsing

The inline pass is invoked after the block phase reaches .eof, guaranteeing a complete block structure.

Flow
	1.	MarkdownContentBuilder traverses the AST to locate every ContentNode.
	2.	Each ContentNode is handed to the MarkdownContentProcessor pipeline.
	3.	Processors implement a delimiter stack algorithm per Documents/Spec/Markdown/spec-044-phase-2-inline-structure.md:
	•	Aggregate delimiter runs (e.g., *, _, **, __, `...`),
	•	Compute canOpen / canClose per run and resolve pairs,
	•	Build inline nodes (emphasis, strong, code spans, links, images, autolinks, etc.),
	•	Preserve literal text (including escaped punctuation) as text nodes.
	4.	When a ContentNode is fully resolved, it is replaced with the resulting inline node list.

Content processors as plugins

Inline processors are decoupled from MarkdownContentBuilder and registered as plugins. A processor typically declares:
	•	The delimiter characters it handles,
	•	How it aggregates runs and advances the token index,
	•	Any look-behind / look-ahead rules required by the spec.

⸻

Conventions & Contracts
	•	Immutability at the edges: Token arrays are read-only; builders create/replace AST nodes instead of mutating token contents.
	•	Single responsibility: Each builder/processor does one job (e.g., block quote prefix, list item marker, code span).
	•	No hidden inline logic: Inline semantics belong exclusively to the inline phase.
	•	Determinism: Given the same token stream, the combined pass must produce a stable AST.

⸻

Notes
	•	Naming: .charef stands for character reference. If desired, consider .charRef or .characterReference for readability.
	•	Newline handling: Keeping .newline on the terminating line simplifies paragraph and setext-heading closure logic.
	•	EOF handling: .eof is a sentinel to flush open structures and trigger the inline phase; it never appears inside a line.

⸻

Extending the Parser

To add a new block or inline feature:
	1.	Block feature: Implement a block builder plugin.
	•	Detect your construct on the current line.
	•	Consume any leading syntax (update context.state.position).
	•	Open/close the correct block node(s).
	•	Store inline-eligible spans in a ContentNode.
	2.	Inline feature: Implement a content processor plugin.
	•	Register handled delimiters.
	•	Use the delimiter-stack protocol to pair runs.
	•	Emit the appropriate inline nodes.

Both plugin types should avoid global assumptions and rely on context.current and context.state exclusively.
