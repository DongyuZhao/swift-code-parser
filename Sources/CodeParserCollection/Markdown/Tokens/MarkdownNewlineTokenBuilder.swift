import CodeParserCore
import Foundation

// MARK: - Newline Token Builder
public class MarkdownNewlineTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<Token>) -> Bool {
    let source = context.source
    let start = context.consuming

    guard start < source.endIndex, source[start] == "\n" else { return false }

    let range = start..<source.index(after: start)
    let token = MarkdownToken(element: .newline, text: "\n", range: range)
    context.tokens.append(token)
    context.consuming = range.upperBound
    return true
  }
}
