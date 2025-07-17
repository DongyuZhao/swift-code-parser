# Markdown Parser

This document provides an overview of the Markdown parser built on top of the SwiftParser core. The parser follows the CommonMark specification and supports various consumers to generate different node types while handling prefix ambiguities.

## Features

### CommonMark Support
- ✅ ATX headers (# Heading)
- ✅ Paragraphs
- ✅ Emphasis (*italic*, **bold**) with nested structures and backtracking
- ✅ Inline code (`code`)
- ✅ Fenced code blocks (```code```)
- ✅ Block quotes (> quote) with multi-line merging
- ✅ Lists (ordered and unordered) with automatic numbering
- ✅ Task lists (- [ ] unchecked, - [x] checked) – GFM extension
- ✅ Links ([text](URL) and reference style)
- ✅ Images (![alt](URL))
- ✅ Autolinks (<URL>)
- ✅ Horizontal rules (---)
- ✅ HTML inline elements
- ✅ Line break handling

### GitHub Flavored Markdown (GFM) Extensions
- ✅ Tables
- ✅ Strikethrough (~~text~~)
- ✅ Task lists (- [ ], - [x])

### Advanced List Features
- ✅ **Unordered lists**: supports `-`, `*`, `+` markers
- ✅ **Ordered lists**: automatic numbering (1. 1. 1. → 1. 2. 3.)
- ✅ **Task lists**: GitHub-style checkboxes (- [ ] and - [x])
- ✅ **Item grouping**: correctly groups items under the same list container
- ✅ **Smart marker detection**: distinguishes list markers from emphasis markers

### Advanced Capabilities
- ✅ Partial node handling for prefix ambiguities
- ✅ Multi-consumer architecture
- ✅ Configurable consumer combinations
- ✅ Error handling and reporting
- ✅ AST traversal and queries
- ✅ Backtracking reorganization for emphasis parsing
- ✅ Global AST rebuilding for complex nesting
- ✅ Best-match strategy favoring strong emphasis
- ✅ Container reuse logic for optimized AST structure

## Basic Usage

### Simple Parsing

```swift
import SwiftParser

let parser = SwiftParser()
let markdown = """
# Heading

This is a paragraph with **bold** and *italic* text.

```swift
let code = "Hello, World!"
```

- Item 1
- Item 2

1. Ordered item 1
1. Ordered item 2
1. Ordered item 3

- [ ] Incomplete task
- [x] Completed task

> Block quote
> Spans multiple lines
"""

let result = parser.parseMarkdown(markdown)

// Inspect the result
if result.hasErrors {
    print("Parse error: \(result.errors)")
} else {
    print("Parse succeeded with \(result.root.children.count) top-level nodes")
}
```

### Finding Specific Elements

```swift
// Find all headers
let headers = result.markdownNodes(ofType: .header1) +
              result.markdownNodes(ofType: .header2)

for header in headers {
    print("Header: \(header.value)")
}

// Find all links
let links = result.markdownNodes(ofType: .link)
for link in links {
    print("Link text: \(link.value)")
    if let url = link.children.first?.value {
        print("URL: \(url)")
    }
}

// Find all code blocks
let codeBlocks = result.markdownNodes(ofType: .fencedCodeBlock)
for codeBlock in codeBlocks {
    if let language = codeBlock.children.first?.value {
        print("Language: \(language)")
    }
    print("Code: \(codeBlock.value)")
}

// Find lists
let unorderedLists = result.markdownNodes(ofType: .unorderedList)
let orderedLists = result.markdownNodes(ofType: .orderedList)
let taskLists = result.markdownNodes(ofType: .taskList)

print("Unordered lists: \(unorderedLists.count)")
print("Ordered lists: \(orderedLists.count)")
print("Task lists: \(taskLists.count)")
```

### Traversing the AST

```swift
// Depth-first traversal
result.root.traverseDepthFirst { node in
    if let mdElement = node.type as? MarkdownElement {
        print("Type: \(mdElement.description), value: \(node.value)")
    }
}

// Breadth-first traversal
result.root.traverseBreadthFirst { node in
    // Handle each node
}

// Find a specific node
let firstParagraph = result.root.first { node in
    (node.type as? MarkdownElement) == .paragraph
}

// Find all list items
let allListItems = result.root.findAll { node in
    let element = node.type as? MarkdownElement
    return element == .listItem || element == .taskListItem
}
```

## Advanced Usage

### Custom Consumer Configuration

```swift
// Create a language that supports only basic CommonMark
let consumers = MarkdownConsumerFactory.createCommonMarkConsumers()
```
