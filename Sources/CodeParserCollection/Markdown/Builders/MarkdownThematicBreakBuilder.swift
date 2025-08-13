import Foundation

/// Builds thematic break nodes (e.g., ***).
final class MarkdownThematicBreakBuilder: MarkdownBlockBuilder {
  func match(line: String) -> Bool {
    return parse(line)
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    guard parse(lines[index]) else { return }
    root.append(ThematicBreakNode())
    index += 1
  }

  private func parse(_ line: String) -> Bool {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " && spaces < 4 {
      idx = line.index(after: idx)
      spaces += 1
    }
    let rest = line[idx...].replacingOccurrences(of: " ", with: "")
    return rest.count >= 3 && Set(rest).count == 1 && rest.first == "*"
  }
}
