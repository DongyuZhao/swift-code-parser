import CodeParserCore
import Foundation

/// Builds ATX heading nodes from a token stream.
public final class MarkdownATXHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let inline = MarkdownInlineParser()

  public init() {}

  // Exposed for paragraph interruptor checks
  func match(line: String) -> Bool { parse(line) != nil }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let (rawLine, consumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: context.consuming)
    let line = rawLine.trimmingCharacters(in: .newlines)
    guard let heading = parse(line) else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }
    root.append(heading)
    context.consuming += consumed
    return true
  }

  private func parse(_ line: String) -> HeaderNode? {
    var idx = line.startIndex
    var leadingSpaces = 0
    while idx < line.endIndex && line[idx] == " " && leadingSpaces < 4 {
      idx = line.index(after: idx)
      leadingSpaces += 1
    }
    if leadingSpaces > 3 { return nil }
    var level = 0
    while idx < line.endIndex && line[idx] == "#" && level < 7 {
      idx = line.index(after: idx)
      level += 1
    }
    if level == 0 || level > 6 { return nil }
    if idx < line.endIndex && line[idx] != " " { return nil }
    if idx < line.endIndex { idx = line.index(after: idx) }
    var content = String(line[idx...]).trimmingCharacters(in: .whitespaces)
    var trimmed = content
    while trimmed.last == " " { trimmed.removeLast() }
    var count = 0
    while trimmed.last == "#" {
      trimmed.removeLast()
      count += 1
    }
    if count > 0 {
      if trimmed.isEmpty || trimmed.last == " " {
        while trimmed.last == " " { trimmed.removeLast() }
        content = trimmed
      }
    }
    let heading = HeaderNode(level: level)
    for node in inline.parse(content) { heading.append(node) }
    return heading
  }
}
