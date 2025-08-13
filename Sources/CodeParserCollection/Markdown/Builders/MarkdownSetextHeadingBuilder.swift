import CodeParserCore
import Foundation

/// Builds setext headings (underline-style) from consecutive lines.
public final class MarkdownSetextHeadingBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let inline = MarkdownInlineParser()
  private let thematic = MarkdownThematicBreakBuilder()

  public init() {}

  private func match(first: String, second: String) -> Int? {
    if thematic.match(line: first) { return nil }
    var idx = second.startIndex
    var spaces = 0
    while idx < second.endIndex && second[idx] == " " {
      idx = second.index(after: idx)
      spaces += 1
    }
    if idx == second.endIndex { return nil }
    let marker = second[idx]
    guard marker == "-" || marker == "=" else { return nil }
    var count = 0
    while idx < second.endIndex && second[idx] == marker {
      count += 1
      idx = second.index(after: idx)
    }
    if idx != second.endIndex { return nil }
    if count < 3 { return nil }
    return marker == "=" ? 1 : 2
  }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let start = context.consuming
    let (firstRaw, firstConsumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: start)
    let firstLine = firstRaw.trimmingCharacters(in: .newlines)
    if firstLine.trimmingCharacters(in: .whitespaces).isEmpty { return false }
    let nextIndex = start + firstConsumed
    guard nextIndex < context.tokens.count else { return false }
    let (secondRaw, secondConsumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: nextIndex)
    let secondLine = secondRaw.trimmingCharacters(in: .newlines)
    guard let level = match(first: firstLine, second: secondLine) else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }
    let heading = HeaderNode(level: level)
    for node in inline.parse(firstLine.trimmingCharacters(in: .whitespaces)) {
      heading.append(node)
    }
    root.append(heading)
    context.consuming = start + firstConsumed + secondConsumed
    return true
  }
}
