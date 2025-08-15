import CodeParserCore
import Foundation

@preconcurrency
public class MarkdownCharacterTokenBuilder: CodeTokenBuilder {
  public typealias Token = MarkdownTokenElement

  public init() {}

  public func build(from context: inout CodeTokenContext<MarkdownTokenElement>) -> Bool {
    guard context.consuming < context.source.endIndex else { return false }
    let char = context.source[context.consuming]
    guard let element = MarkdownTokenElement(from: char) else { return false }
    let start = context.consuming
    context.consuming = context.source.index(after: context.consuming)
    let token = MarkdownToken(
      element: element, text: String(char), range: start..<context.consuming)
    context.tokens.append(token)
    return true
  }
}

extension MarkdownTokenElement {
  init?(from char: Character) {
    guard let element = MarkdownTokenElement(rawValue: String(char)) else {
      return nil
    }
    self = element
  }
}
