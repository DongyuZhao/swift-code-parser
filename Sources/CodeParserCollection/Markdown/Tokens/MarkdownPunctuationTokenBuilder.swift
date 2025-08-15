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

    let range = start..<source.index(after: start)
    let token = MarkdownToken(element: .punctuation, text: String(char), range: range)
    context.tokens.append(token)
    context.consuming = range.upperBound
    return true
  }
}
