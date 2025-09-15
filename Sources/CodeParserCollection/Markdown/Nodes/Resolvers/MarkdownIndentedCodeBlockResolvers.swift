import CodeParserCore
import Foundation

/// Minimal indented code block resolvers to satisfy tests:
/// - Creation: first line with >= 4 leading spaces becomes code block.
/// - Continuation: subsequent lines with >= 4 spaces continue; other lines end the block.
/// - Construction: appends the current line's code content (after removing 4 leading spaces) to the code block source; preserves newline if present.
public class MarkdownIndentedCodeBlockCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let tokens = context.tokens
    var i = 0
    // Do not start an indented code block inside a paragraph or another code block
    guard context.current.element != .paragraph,
          context.current.element != .codeBlock else { return false }
    guard i < tokens.count, tokens[i].element == .whitespaces else { return false }
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    if let item = ancestorListItem(from: context.current) {
      guard spaceCount >= item.contentIndent + 4 else { return false }
    } else {
      guard spaceCount >= 4 else { return false }
    }

    if let parent = context.current as? MarkdownNodeBase {
      let code = CodeBlockNode(source: "")
      if let item = ancestorListItem(from: parent) {
        code.indent = item.contentIndent
      }
      parent.append(code)
      context.current = code
      return true
    }
    return false
  }
}

public class MarkdownIndentedCodeBlockContinuationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element == .codeBlock else { return false }
    let tokens = context.tokens
    if tokens.count == 1, tokens.first?.element == .eof {
      if let code = context.current as? CodeBlockNode {
        while code.source.hasSuffix("\n") { code.source.removeLast() }
        if !code.source.isEmpty && !code.source.hasSuffix("```") && !code.source.hasSuffix("~~~") {
          code.source.append("\n")
        }
      }
      if let parent = context.current.parent { context.current = parent }
      return false
    }
    // Continue only if current line has required indentation or is blank
    var i = 0
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if let item = ancestorListItem(from: context.current) {
        if spaceCount >= item.contentIndent + 4 { return true }
      } else if spaceCount >= 4 {
        return true
      }
    }
    // Blank line continues the code block
    var isBlank = true
    for t in tokens { if t.element != .whitespaces && t.element != .newline && t.element != .eof { isBlank = false; break } }
    if isBlank { return true }

    // Otherwise, end the code block and move current to parent
    var leading = 0
    if let t = tokens.first, t.element == .whitespaces {
      leading = t.text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    }
    if leading == 0, let code = context.current as? CodeBlockNode, code.source.hasSuffix("\n") {
      code.source.removeLast()
    }
    if let parent = context.current.parent { context.current = parent }
    return true
  }
}

private func ancestorListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
  var cur = node as? MarkdownNodeBase
  while let c = cur {
    if let item = c as? ListItemNode { return item }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}

public class MarkdownIndentedCodeBlockConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let code = context.current as? CodeBlockNode else { return false }
    let tokens = context.tokens
    // Determine leading spaces to strip: list item indent + 4, or up to 4 normally
    var i = 0
    var stripCount = 0
    var base = 4
    if let item = ancestorListItem(from: context.current) {
      base = item.contentIndent + 4
    }
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      stripCount = min(base, spaceCount)
      // Rebuild whitespace after stripping leading spaces, if any remain
    }
    var line = ""
    var remainingToStrip = stripCount
    if i < tokens.count, tokens[i].element == .whitespaces {
      for ch in tokens[i].text {
        if ch == " " && remainingToStrip > 0 { remainingToStrip -= 1; continue }
        line.append(ch)
      }
      i += 1
    }
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .newline {
        line.append("\n")
      } else if t.element == .eof {
        // Do not append anything
      } else {
        line.append(t.text)
      }
      i += 1
    }
    code.source.append(line)
    return true
  }
}
