import CodeParserCore
import Foundation

/// ContentBuilder that processes inline markdown using extensible processor architecture
public class MarkdownContentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let processors: [MarkdownContentProcessor]
  private let relations: [Character: [MarkdownContentProcessor]]

  public init() {
    self.processors = [
      MarkdownEmphasisProcessor(),
      // MarkdownLinkProcessor(),
      MarkdownCodeSpanProcessor(),
      // Add more processors here as needed:
      // MarkdownAutoLinkProcessor(),
      // MarkdownHTMLProcessor(),
      // MarkdownStrikethroughProcessor(),
    ]

    // Build delimiter mapping for efficient lookup
    var relations: [Character: [MarkdownContentProcessor]] = [:]
    for processor in self.processors {
      for delimiter in processor.delimiters {
        relations[delimiter, default: []].append(processor)
      }
    }
    self.relations = relations
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Traverse the AST to parse all the content nodes
    context.root.dfs { node in
      if let node = node as? ContentNode {
        let inlined = process(node.tokens)
        finalize(node: node, with: inlined)
      }
    }
    return true
  }

  /// Process tokens into inline nodes using the configured processors
  private func process(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
    var context = MarkdownContentContext(tokens: tokens)

    // Process all tokens
    while context.current < tokens.count {
      let token = tokens[context.current]
      var handled = false

      // Try processors that handle this delimiter
      if token.element == .punctuation, let char = token.text.first {
        if let relatives = relations[char] {
          for processor in relatives {
            if processor.process(token, at: context.current, in: tokens, context: &context) {
              handled = true
              break
            }
          }
        }
      }

      // Default handling if no processor claimed the token
      if !handled {
        switch token.element {
        case .characters, .whitespaces, .punctuation:
          context.add(token.text)
        case .newline:
          context.add(LineBreakNode(variant: .soft))
        case .hardbreak:
          context.add(LineBreakNode(variant: .hard))
        case .charef:
          context.add(token.text) // TODO: Decode entity
        case .eof:
          break
        }
      }

      context.current += 1
    }

    // Finalize processing with all processors
    for processor in processors {
      processor.finalize(context: &context)
    }

    return context.inlined
  }



  private func finalize(node: ContentNode, with inlined: [MarkdownNodeBase]) {
    guard let parent = node.parent as? MarkdownNodeBase else {
      return
    }

    let index = parent.children.firstIndex { $0 === node } ?? 0
    node.remove()

    for (i, inlineNode) in inlined.enumerated() {
      parent.insert(inlineNode, at: index + i)
    }
  }
}