import CodeParserCore
import Foundation

/// Builds paragraph nodes.
public final class MarkdownParagraphBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let inline = MarkdownInlineParser()
  private let interruptors: [(String) -> Bool]

  public init(interruptors: [(String) -> Bool]) {
    self.interruptors = interruptors
  }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let (firstRaw, firstConsumed) = MarkdownLineReader.nextLine(
      from: context.tokens, startingAt: context.consuming)
    var firstLine = firstRaw.trimmingCharacters(in: .newlines)
    if firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
      context.consuming += firstConsumed
      return true
    }
    guard let root = context.current as? MarkdownNodeBase else { return false }

    var removedFirst = 0
    while removedFirst < 3 && firstLine.first == " " {
      firstLine.removeFirst()
      removedFirst += 1
    }
    var parts: [(text: String, removed: Int)] = [(firstLine, removedFirst)]
    var total = firstConsumed
    var index = context.consuming + firstConsumed

    while index < context.tokens.count {
      let (nextRaw, consumed) = MarkdownLineReader.nextLine(from: context.tokens, startingAt: index)
      var nextLine = nextRaw.trimmingCharacters(in: .newlines)
      if nextLine.trimmingCharacters(in: .whitespaces).isEmpty {
        total += consumed
        break
      }
      if interruptors.contains(where: { $0(nextLine) }) {
        break
      }
      var removed = 0
      while removed < 4 && nextLine.first == " " {
        nextLine.removeFirst()
        removed += 1
      }
      parts.append((nextLine, removed))
      total += consumed
      index += consumed
    }

    let para = ParagraphNode(range: parts[0].text.startIndex..<parts[0].text.startIndex)
    if parts.count == 2, parts[1].removed == 4, parts[1].text.first == "#" {
      for node in inline.parse(parts[0].text) { para.append(node) }
      para.append(LineBreakNode())
      for node in inline.parse(parts[1].text) { para.append(node) }
    } else {
      let joined = parts.map { $0.text }.joined(separator: " ")
      for node in inline.parse(joined) { para.append(node) }
    }
    root.append(para)
    context.consuming += total
    return true
  }
}
