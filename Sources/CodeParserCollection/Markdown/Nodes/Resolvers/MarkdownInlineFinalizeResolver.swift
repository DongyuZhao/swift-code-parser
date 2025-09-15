import CodeParserCore
import Foundation

/// Finalization resolver that converts ContentNode tokens into inline AST nodes
/// using a simplified delimiter stack algorithm (emphasis/strong and code spans).
public class MarkdownInlineFinalizeResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Find root by walking up from current
    var root: CodeNode<MarkdownNodeElement> = context.current
    while let parent = root.parent { root = parent }

    // Recursively process content nodes per parent to adjust trailing line breaks
    func finalize(_ node: MarkdownNodeBase) {
      var index = 0
      while index < node.children.count {
        guard let child = node.children[index] as? MarkdownNodeBase else {
          index += 1
          continue
        }

        if let contentNode = child as? ContentNode, let parent = contentNode.parent as? MarkdownNodeBase {
          var inlineNodes = parseInline(tokens: contentNode.tokens)
          // If this is the last ContentNode under parent, drop trailing line break if present
          let hasNextContent = parent.children[(index+1)..<parent.children.count].contains { $0.element == .content }
          if !hasNextContent, let last = inlineNodes.last, last.element == .lineBreak {
            _ = inlineNodes.popLast()
          }

          // Replace content node with produced inline nodes
          parent.remove(at: index)
          var insertIndex = index
          for n in inlineNodes {
            parent.insert(n, at: insertIndex)
            insertIndex += 1
          }
          // Continue from after the inserted nodes
          index = insertIndex
          continue
        }

        // Recurse into non-content children
        finalize(child)
        index += 1
      }
    }

    if let rootNode = root as? MarkdownNodeBase {
      finalize(rootNode)
    }
    return true
  }

  // MARK: - Inline Parsing (simplified)

  private struct Delim {
    var char: Character
    var length: Int
    var index: Int // index in output node list where content started
  }

  private func parseInline(tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
    var nodes: [MarkdownNodeBase] = []
    var textBuffer = String()

    func flushText() {
      if !textBuffer.isEmpty {
        nodes.append(TextNode(content: textBuffer))
        textBuffer.removeAll(keepingCapacity: false)
      }
    }

    var i = 0
    var stack: [Delim] = []

    func handleEmphasis(runChar: Character, runLen: Int) {
      // Try close with nearest matching delimiter
      if let j = stack.lastIndex(where: { $0.char == runChar }) {
        // Determine whether to create strong or emphasis
        let opener = stack.remove(at: j)
        let useStrong = (opener.length >= 2 && runLen >= 2)
        // Wrap nodes from opener.index to end into a container
        let wrapper: MarkdownNodeBase = useStrong ? StrongNode(content: "") : EmphasisNode(content: "")
        let tail = Array(nodes[opener.index..<nodes.count])
        nodes.removeSubrange(opener.index..<nodes.count)
        for child in tail { wrapper.append(child) }
        nodes.append(wrapper)
        // If opener had extra length beyond used, ignore leftovers (simplification)
      } else {
        // Push as potential opener
        stack.append(Delim(char: runChar, length: runLen, index: nodes.count))
      }
    }

    func readRun(of target: Character, from start: Int) -> Int {
      var idx = start
      var count = 0
      while idx < tokens.count, tokens[idx].element == .punctuation, tokens[idx].text == String(target) {
        count += 1
        idx += 1
      }
      return count
    }

    while i < tokens.count {
      let t = tokens[i]
      switch t.element {
      case .characters, .charef, .whitespaces:
        textBuffer.append(t.text)
        i += 1
      case .punctuation:
        if t.text == "`" {
          flushText()
          let runLen = readRun(of: "`", from: i)
          var j = i + runLen
          var code = String()
          var found = false
          while j < tokens.count {
            let tk = tokens[j]
            if tk.element == .punctuation {
              let closeRun = readRun(of: "`", from: j)
              if closeRun >= runLen {
                found = true
                j += closeRun
                break
              }
            }
            if tk.element == .newline {
              code.append("\n")
              j += 1
              continue
            }
            if tk.element == .eof { break }
            code.append(tk.text)
            j += 1
          }
          if found {
            var content = code.replacingOccurrences(of: "\n", with: " ")
            if content.count >= 2, content.first == " ", content.last == " " {
              content.removeFirst()
              content.removeLast()
            }
            nodes.append(CodeSpanNode(code: content))
            i = j
          } else {
            textBuffer.append(String(repeating: "`", count: runLen))
            i += runLen
          }
        } else if t.text == "*" || t.text == "_" {
          let ch = Character(t.text)
          let runLen = readRun(of: ch, from: i)
          let prev = i > 0 ? tokens[i - 1] : nil
          let next = i + runLen < tokens.count ? tokens[i + runLen] : nil
          let prevIsWS = prev == nil || prev!.element == .whitespaces || prev!.element == .newline
          let nextIsWS = next == nil || next!.element == .whitespaces || next!.element == .newline
          if (ch == "_" && (prevIsWS || nextIsWS)) || (ch == "*" && prevIsWS && nextIsWS) {
            textBuffer.append(String(repeating: ch, count: runLen))
          } else {
            flushText()
            handleEmphasis(runChar: ch, runLen: runLen)
          }
          i += runLen
        } else {
          textBuffer.append(t.text)
          i += 1
        }
      case .newline:
        // If a line ends with a backslash and this newline is the final token,
        // the backslash should be preserved literally (used in setext headings).
        if textBuffer.hasSuffix("\\"), i + 1 == tokens.count {
          // Do not produce a line break; keep the backslash
          i += 1
          continue
        }
        // Decide hard vs soft line break
        // Hard break if textBuffer ends with a backslash (\\) or with two or more spaces
        let (isHardBreak, _): (Bool, Int) = {
          if textBuffer.hasSuffix("\\") {
            // Remove the trailing backslash used for hard break
            _ = textBuffer.popLast()
            return (true, 0)
          }
          // Count trailing spaces
          var count = 0
          var idx = textBuffer.endIndex
          while idx > textBuffer.startIndex {
            idx = textBuffer.index(before: idx)
            if textBuffer[idx] == " " { count += 1 } else { break }
          }
          if count >= 2 {
            // Remove all trailing spaces (common behavior)
            textBuffer.removeSubrange(textBuffer.index(textBuffer.endIndex, offsetBy: -count)..<textBuffer.endIndex)
            return (true, count)
          }
          if count == 1 {
            // Remove the single trailing space before a soft line break
            textBuffer.removeLast()
            return (false, 1)
          }
          return (false, 0)
        }()
        flushText()
        nodes.append(LineBreakNode(variant: isHardBreak ? .hard : .soft))
        i += 1
      case .eof:
        // Ignore EOF, just flush
        flushText()
        i += 1
      }
    }

    // Flush residual text
    flushText()

    // Convert any remaining unmatched delimiters to literal text
    // We need to do this in reverse order to maintain proper indices
    for delim in stack.reversed() {
      let text = String(repeating: delim.char, count: delim.length)
      nodes.insert(TextNode(content: text), at: delim.index)
    }

    return nodes
  }
}
