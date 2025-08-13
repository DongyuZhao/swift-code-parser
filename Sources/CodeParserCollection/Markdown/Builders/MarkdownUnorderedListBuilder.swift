import Foundation

/// Builds unordered list nodes.
final class MarkdownUnorderedListBuilder: MarkdownBlockBuilder {
  func match(line: String) -> Bool {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " {
      idx = line.index(after: idx)
      spaces += 1
    }
    if spaces >= 4 { return false }
    guard idx < line.endIndex else { return false }
    let bullet = line[idx]
    guard bullet == "-" || bullet == "*" || bullet == "+" else { return false }
    let next = line.index(after: idx)
    return next < line.endIndex && line[next] == " "
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    let list = UnorderedListNode(level: 1)
    let headingBuilder = MarkdownATXHeadingBuilder()
    let thematicBuilder = MarkdownThematicBreakBuilder()
    let codeBuilder = MarkdownIndentedCodeBlockBuilder()
    let paragraphBuilder = MarkdownParagraphBuilder(interruptors: [
      { headingBuilder.match(line: $0) },
      { thematicBuilder.match(line: $0) },
    ])
    let subBuilders: [MarkdownBlockBuilder] = [
      headingBuilder,
      thematicBuilder,
      codeBuilder,
      paragraphBuilder,
    ]

    while index < lines.count {
      let line = lines[index]
      if thematicBuilder.match(line: line) {
        break
      }
      var idxLine = line.startIndex
      var spaces = 0
      while idxLine < line.endIndex && line[idxLine] == " " {
        idxLine = line.index(after: idxLine)
        spaces += 1
      }
      if spaces >= 4 { break }
      guard idxLine < line.endIndex else { break }
      let bullet = line[idxLine]
      guard bullet == "-" || bullet == "*" || bullet == "+" else { break }
      let afterBullet = line.index(after: idxLine)
      guard afterBullet < line.endIndex && line[afterBullet] == " " else { break }
      let content = String(line[line.index(after: afterBullet)...])
      let item = ListItemNode(marker: String(bullet))

      let subLines = [content]
      var subIndex = 0
      while subIndex < subLines.count {
        let subLine = subLines[subIndex]
        if subLine.trimmingCharacters(in: .whitespaces).isEmpty {
          subIndex += 1
          continue
        }
        for b in subBuilders {
          if b.match(line: subLine) {
            b.build(lines: subLines, index: &subIndex, root: item)
            break
          }
        }
      }

      list.append(item)
      index += 1
    }

    root.append(list)
  }
}
