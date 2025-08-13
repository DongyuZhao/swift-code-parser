import Foundation

/// Converts a preceding paragraph to a setext heading when encountering an underline of `===` or `---`.
final class MarkdownSetextHeadingBuilder {
  func match(line: String, previous: MarkdownNodeBase?) -> Bool {
    guard previous is ParagraphNode else { return false }
    return parse(line) != nil
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    guard let marker = parse(lines[index]) else { return }
    guard root.children.count > 0 else { return }
    let lastIndex = root.children.count - 1
    guard let para = root.children[lastIndex] as? ParagraphNode else { return }
    let level = marker == "=" ? 1 : 2
    let header = HeaderNode(level: level)
    for child in para.children {
      if let node = child as? MarkdownNodeBase {
        header.append(node)
      }
    }
    root.remove(at: lastIndex)
    root.append(header)
    index += 1
  }

  private func parse(_ line: String) -> Character? {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " {
      idx = line.index(after: idx)
      spaces += 1
    }
    if spaces >= 4 { return nil }
    var marker: Character?
    var count = 0
    while idx < line.endIndex {
      let c = line[idx]
      if c == " " || c == "\t" {
        idx = line.index(after: idx)
        continue
      }
      if c == "=" || c == "-" {
        if marker == nil { marker = c }
        else if marker != c { return nil }
        count += 1
        idx = line.index(after: idx)
      } else {
        return nil
      }
    }
    return count >= 1 ? marker : nil
  }
}
