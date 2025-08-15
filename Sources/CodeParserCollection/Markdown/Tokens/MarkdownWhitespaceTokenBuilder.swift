import CodeParserCore
import Foundation

// MARK: - Whitespace Token Builder (excluding newline)
public class MarkdownWhitespaceTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  // Collects a run of whitespace characters excluding newline.
  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    var current = context.consuming
    let start = current

    guard current < source.endIndex else { return false }
    guard MarkdownWhitespaceCharacter.characters.contains(source[current]),
          source[current] != "\n" else { return false }

    // Gather consecutive non-newline whitespace characters
    while current < source.endIndex,
          MarkdownWhitespaceCharacter.characters.contains(source[current]),
          source[current] != "\n" {
      current = source.index(after: current)
    }

    let range = start..<current
    let token = MarkdownToken(element: .whitespaces, text: String(source[range]), range: range)
    context.tokens.append(token)
    context.consuming = current
    return true
  }
}
