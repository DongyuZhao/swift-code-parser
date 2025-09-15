import CodeParserCore
import Foundation

/// Minimal indented code block resolvers to satisfy tests:
/// - Creation: first line with >= 4 leading spaces becomes code block.
/// - Continuation: subsequent lines with >= 4 spaces continue; other lines end the block.
/// - Construction: appends the current line's code content (after removing 4 leading spaces) to the code block source; preserves newline if present.
public class MarkdownIndentedCodeBlockCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let remainingTokens = Array(context.tokens[context.consumed...])
    // Do not start an indented code block inside a paragraph or another code block
    guard context.current.element != .paragraph,
          context.current.element != .codeBlock else { 
      return false 
    }

    // Count leading spaces with single-character tokens
    var spaceCount = 0
    var i = 0
    while i < remainingTokens.count && remainingTokens[i].element == .whitespace && remainingTokens[i].text == " " {
      spaceCount += 1
      i += 1
    }

    // Always need exactly 4+ spaces for an indented code block
    guard spaceCount >= 4 else { 
      return false 
    }

    if let parent = context.current as? MarkdownNodeBase {
      let code = CodeBlockNode(source: "")
      // Code blocks always have base indent of 0 - list indentation is handled by list resolvers
      code.indent = 0
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
    let remainingTokens = Array(context.tokens[context.consumed...])
    if remainingTokens.count == 1, remainingTokens.first?.element == .eof {
      if let code = context.current as? CodeBlockNode {
        while code.source.hasSuffix("\n") { code.source.removeLast() }
        if !code.source.isEmpty && !code.source.hasSuffix("```") && !code.source.hasSuffix("~~~") {
          code.source.append("\n")
        }
      }
      if let parent = context.current.parent { context.current = parent }
      return false
    }

    guard context.current.element == .codeBlock else { return false }
    
    // Count leading spaces with single-character tokens
    var spaceCount = 0
    var i = 0
    while i < remainingTokens.count && remainingTokens[i].element == .whitespace && remainingTokens[i].text == " " {
      spaceCount += 1
      i += 1
    }

    // Code block continues if line has 4+ spaces
    if spaceCount >= 4 {
      return true
    }

    // Blank line continues the code block
    var isBlank = true
    for t in remainingTokens { if t.element != .whitespace && t.element != .newline && t.element != .eof { isBlank = false; break } }
    if isBlank { return true }

    // Otherwise, end the code block and move current to parent
    if let parent = context.current.parent { context.current = parent }
    return true
  }
}


public class MarkdownIndentedCodeBlockConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let code = context.current as? CodeBlockNode else { return false }
    let remainingTokens = Array(context.tokens[context.consumed...])

    // Always strip exactly 4 spaces for indented code blocks
    let stripCount = 4

    // Strip leading spaces with single-character tokens
    var i = 0
    var stripped = 0
    while i < remainingTokens.count && remainingTokens[i].element == .whitespace && remainingTokens[i].text == " " && stripped < stripCount {
      i += 1
      stripped += 1
    }

    // Build the line from remaining tokens
    var line = ""
    while i < remainingTokens.count {
      let t = remainingTokens[i]
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

    // Consume all tokens from this line
    context.consumed = context.tokens.count
    return true
  }
}
