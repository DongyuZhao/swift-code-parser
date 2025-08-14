import CodeParserCore
import Foundation

/// Parses thematic breaks like `---` or `***`.
public class MarkdownThematicBreakBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    let tokens = context.tokens
    var idx = context.consuming

    // Start of line check
    if idx > 0, tokens[idx - 1].element != .newline { return false }

    // Up to 3 spaces
    let (spaces, afterIndent) = consumeIndentation(tokens, start: idx)
    if spaces > 3 { return false }
    idx = afterIndent
    guard idx < tokens.count else { return false }

    let first = tokens[idx]
    guard first.element == .asterisk || first.element == .dash || first.element == .underscore else {
      return false
    }
    let marker = first.element
    var markerCount = 0
    var content = ""
    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == marker {
        markerCount += 1
        content.append(t.text)
        idx += 1
      } else if t.element == .space || t.element == .tab {
        content.append(t.text)
        idx += 1
      } else if t.element == .newline {
        break
      } else {
        return false
      }
    }
    if markerCount < 3 { return false }
    guard idx < tokens.count, tokens[idx].element == .newline else { return false }

    let node = ThematicBreakNode(marker: content.trimmingCharacters(in: .whitespaces))
    context.current.append(node)
    idx += 1
    context.consuming = idx
    if let state = context.state as? MarkdownConstructState {
      state.previousLineBlank = false
    }
    return true
  }

  /// Utility used by other builders to check if a line is a thematic break
  static func isThematicBreak(tokens: [any CodeToken<MarkdownTokenElement>], start: Int) -> Bool {
    var idx = start
    let (spaces, afterIndent) = consumeIndentation(tokens, start: idx)
    if spaces > 3 { return false }
    idx = afterIndent
    guard idx < tokens.count else { return false }
    let first = tokens[idx]
    guard first.element == .asterisk || first.element == .dash || first.element == .underscore else {
      return false
    }
    let marker = first.element
    var markerCount = 0
    while idx < tokens.count {
      let t = tokens[idx]
      if t.element == marker {
        markerCount += 1
        idx += 1
      } else if t.element == .space || t.element == .tab {
        idx += 1
      } else if t.element == .newline {
        break
      } else {
        return false
      }
    }
    if markerCount < 3 { return false }
    return true
  }
}
