import CodeParserCore
import Foundation

/// Builds unordered list nodes with simple list item parsing.
public final class MarkdownUnorderedListBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let inline = MarkdownInlineParser()
  private let thematic: MarkdownThematicBreakBuilder

  public init(thematic: MarkdownThematicBreakBuilder) {
    self.thematic = thematic
  }

  func match(line: String) -> Bool {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " && spaces < 3 {
      idx = line.index(after: idx)
      spaces += 1
    }
    guard idx < line.endIndex, "-*+".contains(line[idx]) else { return false }
    let markerIndex = idx
    idx = line.index(after: idx)
    guard idx < line.endIndex, line[idx] == " " else { return false }
    let after = line.index(after: idx)
    return after < line.endIndex
      && !(thematic.match(line: String(line[markerIndex...])) && spaces == 0)
  }

  public func build(
    from context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> Bool {
    guard context.consuming < context.tokens.count else { return false }
    let start = context.consuming
    let (raw, consumed) = MarkdownLineReader.nextLine(from: context.tokens, startingAt: start)
    let line = raw.trimmingCharacters(in: .newlines)
    guard match(line: line) else { return false }
    guard let root = context.current as? MarkdownNodeBase else { return false }

    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " && spaces < 3 {
      idx = line.index(after: idx)
      spaces += 1
    }
    let marker = line[idx]
    idx = line.index(after: idx)  // move past marker
    idx = line.index(after: idx)  // skip following space
    let contentStart = idx

    let list = UnorderedListNode(level: 1)
    var total = consumed
    var index = start

    func buildItem(_ content: String) {
      let item = ListItemNode(marker: String(marker))
      if thematic.match(line: content) {
        item.append(ThematicBreakNode())
      } else {
        let para = ParagraphNode(range: content.startIndex..<content.startIndex)
        for node in inline.parse(content) { para.append(node) }
        item.append(para)
      }
      list.append(item)
    }

    buildItem(String(line[contentStart...]))
    index += consumed

    while index < context.tokens.count {
      let (nextRaw, nextConsumed) = MarkdownLineReader.nextLine(
        from: context.tokens, startingAt: index)
      let nextLine = nextRaw.trimmingCharacters(in: .newlines)
      if thematic.match(line: nextLine) { break }
      var i = nextLine.startIndex
      var s = 0
      while i < nextLine.endIndex && nextLine[i] == " " && s < 3 {
        i = nextLine.index(after: i)
        s += 1
      }
      guard i < nextLine.endIndex, nextLine[i] == marker else { break }
      i = nextLine.index(after: i)
      guard i < nextLine.endIndex, nextLine[i] == " " else { break }
      let content = String(nextLine[nextLine.index(after: i)...])
      buildItem(content)
      index += nextConsumed
      total += nextConsumed
    }

    root.append(list)
    context.consuming = start + total
    return true
  }
}
