import CodeParserCore
import Foundation

// MARK: - Characters Token Builder (handles backslash escapes)
public class MarkdownCharactersTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    var current = context.consuming
    let start = current
    var resultText = ""

    guard current < source.endIndex else { return false }

    // Determine if we are in a special mode (code, HTML, autolink, etc.)
    let inSpecialMode: Bool
    if let state = context.state as? MarkdownTokenState {
      switch state.modes.top {
      case .code, .html, .autolink:
        inSpecialMode = true
      default:
        inSpecialMode = false
      }
    } else {
      inSpecialMode = false
    }

    while current < source.endIndex {
      let char = source[current]

      if char == "\\" {
        let nextIndex = source.index(after: current)

        if !inSpecialMode {
          if nextIndex < source.endIndex && source[nextIndex] == "\n" {
            // Backslash followed by newline -> line break, consume backslash only
            current = nextIndex
            break
          }

          if nextIndex >= source.endIndex {
            resultText.append("\\")
            current = nextIndex
            break
          }

          let nextChar = source[nextIndex]
          if MarkdownPunctuationCharacter.characters.contains(nextChar) {
            resultText.append(nextChar)
            current = source.index(after: nextIndex)
          } else {
            resultText.append("\\")
            current = nextIndex
          }
        } else {
          if nextIndex >= source.endIndex {
            resultText.append("\\")
            current = nextIndex
            break
          }
          let nextChar = source[nextIndex]
          resultText.append("\\")
          if MarkdownPunctuationCharacter.characters.contains(nextChar) {
            resultText.append(nextChar)
            current = source.index(after: nextIndex)
          } else {
            current = nextIndex
          }
          continue
        }
      } else {
        if MarkdownWhitespaceCharacter.characters.contains(char) ||
           MarkdownPunctuationCharacter.characters.contains(char) {
          break
        }

        resultText.append(char)
        current = source.index(after: current)
      }
    }

    guard !resultText.isEmpty else { return false }

    let range = start..<current
    let token = MarkdownToken(element: .characters, text: resultText, range: range)
    context.tokens.append(token)
    context.consuming = current
    return true
  }
}
