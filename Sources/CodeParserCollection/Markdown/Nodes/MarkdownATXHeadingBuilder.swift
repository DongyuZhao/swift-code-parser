import CodeParserCore
import Foundation

/// Parses ATX headings (e.g. `# Heading`).
public class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming

    // Require start of line
    if idx > 0, tokens[idx - 1].element != .newline {
      return false
    }

    // Optional up to 3 spaces
    var spaces = 0
    while idx < tokens.count, tokens[idx].element == .space {
      spaces += 1
      idx += 1
    }
    if spaces > 3 { return false }

    // Count hashes
    var level = 0
    while idx < tokens.count, tokens[idx].element == .hash {
      level += 1
      idx += 1
    }
    if level == 0 || level > 6 { return false }

    // Next must be space, tab, or newline (empty heading)
    if idx < tokens.count {
      let t = tokens[idx]
      if !(t.element == .space || t.element == .tab || t.element == .newline) {
        return false
      }
    }

    // Skip spaces/tabs after markers
    while idx < tokens.count, (tokens[idx].element == .space || tokens[idx].element == .tab) {
      idx += 1
    }

    // Collect content tokens until newline
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == .newline { break }
      contentTokens.append(t)
      idx += 1
    }

    // Trim closing hash sequence
    var end = contentTokens.count
    while end > 0 && contentTokens[end - 1].element == .space { end -= 1 }
    var hashEnd = end
    while hashEnd > 0 && contentTokens[hashEnd - 1].element == .hash { hashEnd -= 1 }
    if hashEnd < end {
      let beforeIndex = hashEnd - 1
      let beforeSpace = beforeIndex >= 0 ? contentTokens[beforeIndex].element == .space : true
      let escaped = beforeIndex >= 1 && contentTokens[beforeIndex - 1].element == .backslash
      if beforeSpace && !escaped {
        end = hashEnd
        while end > 0 && contentTokens[end - 1].element == .space { end -= 1 }
        contentTokens = Array(contentTokens[0..<end])
      }
    } else {
      contentTokens = Array(contentTokens[0..<end])
    }

    let node = HeaderNode(level: level)
    for child in MarkdownInlineParser.parse(contentTokens) { node.append(child) }
    context.current.append(node)

    // Consume newline if present
    if idx < tokens.count, tokens[idx].element == .newline {
      idx += 1
    }
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState {
      state.previousLineBlank = false
    }
    return true
  }
}
