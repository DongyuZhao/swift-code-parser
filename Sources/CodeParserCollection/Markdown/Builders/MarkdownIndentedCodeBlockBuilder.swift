import CodeParserCore
import Foundation

/// Builds indented code block nodes.
public final class MarkdownIndentedCodeBlockBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  func match(line: String) -> Bool {
    line.hasPrefix("    ") || line.hasPrefix("\t")
  }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let (firstRaw, firstConsumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: context.consuming)
    let firstLine = firstRaw.trimmingCharacters(in: .newlines)
    guard match(line: firstLine) else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }

    var content =
      firstLine.hasPrefix("\t")
      ? String(firstLine.dropFirst(1))
      : String(firstLine.dropFirst(4))
    var total = firstConsumed
    var index = context.consuming + firstConsumed
    while index < context.tokens.count {
      let (nextRaw, consumed) = MarkdownLineReader.nextLine(from: context.tokens, startingAt: index)
      let endToken = context.tokens[min(index + consumed - 1, context.tokens.count - 1)]
      if endToken.element == .eof { break }
      var line = nextRaw.trimmingCharacters(in: .newlines)
      if line.isEmpty {
        content.append("\n")
        total += consumed
        index += consumed
        continue
      }
      if match(line: line) {
        line = line.hasPrefix("\t") ? String(line.dropFirst(1)) : String(line.dropFirst(4))
        content.append("\n")
        content.append(line)
        total += consumed
        index += consumed
      } else {
        break
      }
    }

    root.append(CodeBlockNode(source: content))
    context.consuming += total
    return true
  }
}
