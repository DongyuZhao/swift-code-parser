import CodeParserCore
import Foundation

// MARK: - Whitespace Token Builder (excluding newline)
public class MarkdownWhitespaceTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  // Emits a single whitespace character token (excluding newline).
  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    let current = context.consuming

    guard current < source.endIndex else { return false }
    guard MarkdownWhitespaceCharacter.characters.contains(source[current]),
          source[current] != "\n" else { return false }

    // Emit single whitespace character token
    let next = source.index(after: current)
    let range = current..<next
    let token = MarkdownToken(element: .whitespace, text: String(source[range]), range: range)
    context.tokens.append(token)
    context.consuming = next

    return true
  }
}
