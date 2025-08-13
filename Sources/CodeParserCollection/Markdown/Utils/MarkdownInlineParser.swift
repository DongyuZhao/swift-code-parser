import Foundation

/// Parses inline Markdown elements like escapes and emphasis.
struct MarkdownInlineParser {
  func parse(_ text: String) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var buffer = ""
    let chars = Array(text)
    var i = 0
    func flush() {
      if !buffer.isEmpty {
        nodes.append(TextNode(content: buffer))
        buffer.removeAll(keepingCapacity: true)
      }
    }
    while i < chars.count {
      let c = chars[i]
      if c == "\\" {
        if i + 1 < chars.count {
          buffer.append(chars[i + 1])
          i += 2
        } else {
          i += 1
        }
      } else if c == "*" {
        var j = i + 1
        var found = false
        while j < chars.count {
          if chars[j] == "\\" {
            j += 2
            continue
          }
          if chars[j] == "*" {
            found = true
            break
          }
          j += 1
        }
        if found && j > i + 1 {
          flush()
          let inner = String(chars[(i + 1)..<j])
          let em = EmphasisNode(content: inner)
          em.append(TextNode(content: inner))
          nodes.append(em)
          i = j + 1
        } else {
          buffer.append(c)
          i += 1
        }
      } else {
        buffer.append(c)
        i += 1
      }
    }
    flush()
    return nodes
  }
}
