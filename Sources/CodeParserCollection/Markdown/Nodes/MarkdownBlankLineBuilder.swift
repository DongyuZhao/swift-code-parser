import CodeParserCore
import Foundation

/// Consumes blank lines and updates parser state without emitting nodes.
public class MarkdownBlankLineBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> Bool {
    guard context.current is DocumentNode else { return false }
    var idx = context.consuming
    while idx < context.tokens.count {
      let tok = context.tokens[idx]
      if tok.element == .space || tok.element == .tab {
        idx += 1
        continue
      }
      if tok.element == .newline {
        context.consuming = idx + 1
        if let state = context.state as? MarkdownConstructState {
          state.previousLineBlank = true
        }
        return true
      }
      return false
    }
    return false
  }
}
