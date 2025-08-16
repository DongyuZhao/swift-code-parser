import CodeParserCore
import Foundation

// MARK: - Punctuation Token Builder
public class MarkdownPunctuationTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    let start = context.consuming

    guard start < source.endIndex else { return false }
    let char = source[start]
    guard MarkdownPunctuationCharacter.characters.contains(char) else { return false }

    var current = start

    // Handle runs of backticks or tildes specially for code spans/blocks
    if char == "`" || char == "~" {
      var count = 0
      while current < source.endIndex && source[current] == char {
        let next = source.index(after: current)
        let range = current..<next
        let token = MarkdownToken(element: .punctuation, text: String(char), range: range)
        context.tokens.append(token)
        count += 1
        current = next
      }
      context.consuming = current

      if let state = context.state as? MarkdownTokenState {
        if count >= 3 {
          // Fenced code block boundaries
          if state.inFencedCodeBlock && state.modes.top == .code {
            state.modes.pop()
            state.inFencedCodeBlock = false
          } else {
            state.pendingMode = .code
            state.inFencedCodeBlock = true
          }
        } else {
          // Inline code spans
          if state.modes.top == .code {
            state.modes.pop()
          } else {
            state.modes.push(.code)
          }
        }
      }
      return true
    }

    // Default: single punctuation character
    let range = start..<source.index(after: start)
    let token = MarkdownToken(element: .punctuation, text: String(char), range: range)
    context.tokens.append(token)
    context.consuming = range.upperBound

    if let state = context.state as? MarkdownTokenState {
      switch char {
      case "<":
        if state.modes.top != .code {
          state.modes.push(.html)
        }
      case ">":
        if state.modes.top == .html || state.modes.top == .autolink {
          state.modes.pop()
        }
      default:
        break
      }
    }

    return true
  }
}
