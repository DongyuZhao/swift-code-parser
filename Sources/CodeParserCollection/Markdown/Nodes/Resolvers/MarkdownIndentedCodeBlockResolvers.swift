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
    guard context.current.element != .paragraph, context.current.element != .codeBlock else { return false }
    guard i < tokens.count, tokens[i].element == .whitespaces else { return false }
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    guard spaceCount >= 4 else { return false }

    if let parent = context.current as? MarkdownNodeBase {
      let code = CodeBlockNode(source: "")
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
      // Nothing to do at EOF; leave as-is
      return false
    }
    // Continue only if current line has >= 4 leading spaces or is blank
    var i = 0
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if spaceCount >= 4 { return true }
    }
    // Blank line continues the code block
    var isBlank = true
    for t in tokens { if t.element != .whitespaces && t.element != .newline && t.element != .eof { isBlank = false; break } }
    if isBlank { return true }

    // Otherwise, end the code block by trimming trailing newline and moving current to parent
    if let code = context.current as? CodeBlockNode {
      if code.source.hasSuffix("\n") {
        code.source.removeLast()
      }
    }
    if let parent = context.current.parent { context.current = parent }
    return true
  }
}

public class MarkdownIndentedCodeBlockConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let code = context.current as? CodeBlockNode else { return false }
    let tokens = context.tokens
    // Determine leading spaces to strip (up to 4)
    var i = 0
    var stripCount = 0
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      stripCount = min(4, ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) })
      // Rebuild whitespace after stripping 4 spaces, if any remain
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
