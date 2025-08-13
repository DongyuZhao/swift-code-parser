import Foundation

/// Builds ATX heading nodes.
final class MarkdownATXHeadingBuilder: MarkdownBlockBuilder {
  private let inline = MarkdownInlineParser()

  func match(line: String) -> Bool {
    return parse(line) != nil
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    guard let heading = parse(lines[index]) else { return }
    root.append(heading)
    index += 1
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
    // Optional closing sequence
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
