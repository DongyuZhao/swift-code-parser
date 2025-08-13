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
    var first = lines[index]
    var removedFirst = 0
    while removedFirst < 3 && first.first == " " {
      first.removeFirst()
      removedFirst += 1
    }
    var parts: [(text: String, removed: Int)] = [(first, removedFirst)]
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
      parts.append((text, removed))
      i += 1
    }
    if parts.count == 2, parts[1].removed == 4, parts[1].text.first == "#" {
      let para = ParagraphNode(range: parts[0].text.startIndex..<parts[0].text.startIndex)
      for node in inline.parse(parts[0].text) { para.append(node) }
      para.append(LineBreakNode())
      for node in inline.parse(parts[1].text) { para.append(node) }
      root.append(para)
      index = i
      return
    }
    let para = ParagraphNode(range: parts[0].text.startIndex..<parts[0].text.startIndex)
    let joined = parts.map { $0.text }.joined(separator: " ")
    for node in inline.parse(joined) { para.append(node) }
    root.append(para)
    index = i
  }
}
