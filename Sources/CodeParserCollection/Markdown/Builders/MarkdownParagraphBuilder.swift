import Foundation

/// Builds paragraph nodes.
final class MarkdownParagraphBuilder: MarkdownBlockBuilder {
  private let inline = MarkdownInlineParser()
  private let interruptors: [(String) -> Bool]

  init(interruptors: [(String) -> Bool]) {
    self.interruptors = interruptors
  }

  func match(line: String) -> Bool {
    // Paragraph is fallback; always match
    return true
  }

  func build(lines: [String], index: inout Int, root: MarkdownNodeBase) {
    var paraLines: [String] = [lines[index]]
    var i = index + 1
    while i < lines.count {
      let next = lines[i]
      if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
      if interruptors.contains(where: { $0(next) }) { break }
      var text = next
      var removed = 0
      while removed < 4 && text.first == " " {
        text.removeFirst()
        removed += 1
      }
      paraLines.append(text)
      i += 1
    }
    let para = ParagraphNode(range: paraLines[0].startIndex..<paraLines[0].startIndex)
    for (idx, line) in paraLines.enumerated() {
      if idx > 0 { para.append(LineBreakNode()) }
      for node in inline.parse(line) { para.append(node) }
    }
    root.append(para)
    index = i
  }
}
