import Foundation

/// Builds indented code block nodes.
final class MarkdownIndentedCodeBlockBuilder: MarkdownBlockBuilder {
  func match(line: String) -> Bool {
    return line.hasPrefix("    ")
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    var content = String(lines[index].dropFirst(4))
    var i = index + 1
    while i < lines.count {
      let next = lines[i]
      if next.hasPrefix("    ") {
        content.append("\n")
        content.append(String(next.dropFirst(4)))
        i += 1
      } else {
        break
      }
    }
    root.append(CodeBlockNode(source: content))
    index = i
  }
}
