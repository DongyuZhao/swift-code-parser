import CodeParserCore
import Foundation

// MARK: - Characters Token Builder (no escape or entity handling)
// Emits a run of non-whitespace, non-punctuation characters as a single .characters token.
public class MarkdownCharactersTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    let start = context.consuming
    var current = start

    // Must have at least one character available
    guard current < source.endIndex else { return false }

    // First character must be a non-boundary (not whitespace, not punctuation)
    let first = source[current]
    guard !MarkdownWhitespaceCharacter.characters.contains(first),
          !MarkdownPunctuationCharacter.characters.contains(first) else {
      return false
    }

    // Advance at least one character, then continue until a boundary
    current = source.index(after: current)
    while current < source.endIndex {
      let ch = source[current]
      if MarkdownWhitespaceCharacter.characters.contains(ch) ||
         MarkdownPunctuationCharacter.characters.contains(ch) {
        break
      }
      current = source.index(after: current)
    }

    let range = start..<current
    // Safety: if no progress was made, do not consume to avoid stalling
    guard range.lowerBound < range.upperBound else { return false }
    let token = MarkdownToken(element: .characters, text: String(source[range]), range: range)
    context.tokens.append(token)
    context.consuming = current
    return true
  }
}
