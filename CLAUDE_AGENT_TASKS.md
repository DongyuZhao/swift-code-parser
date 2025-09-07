# Swift Code Parser - Comprehensive Task Documentation for AI Agents

This document provides a complete understanding of the Swift code parser repository architecture, current state, and detailed tasks for AI agents (Claude, Copilot, Codex) to complete the implementation.

## Repository Architecture Overview

### Core Design Principles
1. **Token-based AST Construction**: Two-phase parsing (Source → Tokens → AST)
2. **Mutable AST as Single Source of Truth**: Direct AST editing during parsing
3. **Line-by-line Incremental Processing**: Process one line at a time with yield-back pattern
4. **Context Pointer Manipulation**: Use `context.current` for AST navigation
5. **Pluggable Builder Architecture**: Extensible token and node builders

### Violate these constrains will leads to a death penalty to you.
1. All of the AST construction should only using tokens as source. You should never merge them back to string and do a string based parse.
2. Backslash escaping has been processed by tokenizer, any content inside .characters should not be considered as its original semantic. You should only use .punctuation as delimiter.
3. AST is editatble, so you can always update the AST nodes when new token come in. Do not try to advance or peak lines, the AST should accurate reflect the processed line snippet and should be updated when new line come in.
4. MarkdownBlockBuilder and MarkdownInlineProcessor are designed as a pure pluggable dispatcher, there should be no any grammar or node related logic in side them.

### Project Structure
```
Sources/
├── CodeParserCore/           # Generic parsing framework
│   ├── CodeParser.swift      # Main orchestrator
│   ├── CodeTokenizer.swift   # Character → Token conversion
│   ├── CodeConstructor.swift # Token → AST conversion
│   ├── CodeNode.swift        # Mutable AST nodes
│   └── CodeDebugUtils.swift  # Debug utilities (ADDED)
└── CodeParserCollection/
    └── Markdown/             # Markdown language implementation
        ├── MarkdownLanguage.swift
        ├── MarkdownConstructState.swift  # State management
        ├── Nodes/
        │   ├── MarkdownBlockBuilder.swift      # Main AST builder
        │   ├── MarkdownBlockBuilderProtocol.swift
        │   ├── MarkdownATXHeadingBuilder.swift # WORKING
        │   ├── MarkdownFencedCodeBlockBuilder.swift # NEEDS FIXES
        │   ├── MarkdownBlockquoteBuilder.swift     # NEEDS FIXES
        │   └── [Other builders...]
        └── Tokens/
            └── [Token builders...]

Tests/
└── CodeParserCollectionTests/Markdown/Nodes/
    ├── DebugTests.swift      # Debug test suite (ADDED)
    └── [Spec test suites...] # Many failing tests
```