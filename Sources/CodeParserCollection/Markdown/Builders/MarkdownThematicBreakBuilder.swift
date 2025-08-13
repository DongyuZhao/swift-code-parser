import Foundation

/// Builds thematic break nodes (`***`, `---`, `___`).
final class MarkdownThematicBreakBuilder: MarkdownBlockBuilder {
  func match(line: String) -> Bool {
    return parse(line) != nil
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    guard parse(lines[index]) != nil else { return }
    root.append(ThematicBreakNode())
    index += 1
  }

  /// Returns the marker character if the line is a thematic break.
  private func parse(_ line: String) -> Character? {
    var idx = line.startIndex
    var spaces = 0
    while idx < line.endIndex && line[idx] == " " {
      idx = line.index(after: idx)
      spaces += 1
    }
    // Four or more leading spaces turn this into a code block.
    if spaces >= 4 { return nil }
    var marker: Character?
    var count = 0
    while idx < line.endIndex {
      let c = line[idx]
      if c == " " || c == "\t" {
        idx = line.index(after: idx)
        continue
      }
      if c == "*" || c == "-" || c == "_" {
        if marker == nil { marker = c }
        else if marker != c { return nil }
        count += 1
        idx = line.index(after: idx)
      } else {
        return nil
      }
    }
    return count >= 3 ? marker : nil
  }
}
