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
      MarkdownStrikethroughProcessor(),
      MarkdownEmphasisProcessor(),
      // MarkdownLinkProcessor(),
      MarkdownCodeSpanProcessor(),
      // Add more processors here as needed:
      // MarkdownAutoLinkProcessor(),
      // MarkdownHTMLProcessor(),
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
  /// Internal so processors can reuse it to parse nested content between delimiters.
  func process(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> [MarkdownNodeBase] {
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
        case .charef:
          context.add(token.text) // TODO: Decode entity
        case .eof:
          break
        }
        // Only advance by 1 if no processor handled the token
        context.current += 1
      }
    }

    // Finalize processing by matching delimiter pairs and creating nodes
    finalizeDelimiters(context: &context)

    return context.inlined
  }

  /// Finalize delimiter processing by matching pairs and creating nodes
  private func finalizeDelimiters(context: inout MarkdownContentContext) {
    // Process delimiter pairs following CommonMark algorithm
    var currentDelimiterNode = context.delimiters.forward(from: nil)
    var processedRanges: [ProcessedRange] = []

    while let closerNode = currentDelimiterNode.next() {
      guard closerNode.run.closable, closerNode.run.isActive else {
        continue
      }

      // Find appropriate processor for this delimiter type
      guard let processor = findProcessor(for: closerNode.run.delimiter) else {
        continue
      }

      // Look for matching opener
      if let openerNode = context.delimiters.opener(for: closerNode.run.delimiter, before: closerNode) {
        guard openerNode !== closerNode else { continue }

        // Get content tokens between delimiters
        let openerTokenIndex = openerNode.run.index
        let closerTokenIndex = closerNode.run.index
        let contentStart = openerTokenIndex + openerNode.run.length
        let contentEnd = closerTokenIndex

        guard contentStart <= contentEnd else { continue }

        // Get content tokens
        let contentTokens = context.tokens[contentStart..<contentEnd]

  // Validate pair and ask processor to create the node
  if processor.canPair(opener: openerNode.run, closer: closerNode.run, tokens: context.tokens),
     let node = processor.createNode(
          for: closerNode.run.delimiter,
          openerRun: openerNode.run,
          closerRun: closerNode.run,
          contentTokens: contentTokens
        ) {
          // Store the processed range
          processedRanges.append(ProcessedRange(
            openerStart: openerTokenIndex,
            openerEnd: openerTokenIndex + openerNode.run.length,
            closerStart: closerTokenIndex,
            closerEnd: closerTokenIndex + closerNode.run.length,
            node: node
          ))

          // Mark delimiters as processed and remove only the matched pair
          openerNode.run.isActive = false
          closerNode.run.isActive = false

          // Remove closer then opener to keep links valid
          context.delimiters.remove(closerNode)
          context.delimiters.remove(openerNode)

          // Restart from the beginning to find further pairs (including outers)
          currentDelimiterNode = context.delimiters.forward(from: nil)
        }
      }
    }

    // Rebuild content with processed ranges
    rebuildContentWithProcessedRanges(context: &context, processedRanges: processedRanges)
  }

  /// Helper struct for tracking processed delimiter ranges
  private struct ProcessedRange {
    let openerStart: Int
    let openerEnd: Int
    let closerStart: Int
    let closerEnd: Int
    let node: MarkdownNodeBase
  }

  /// Find the processor that handles a specific delimiter type
  private func findProcessor(for delimiter: MarkdownDelimiter) -> MarkdownContentProcessor? {
    // Prefer processors that explicitly support the delimiter
    if case .custom(let name) = delimiter {
      // For custom delimiters, allow processors to opt-in by delimiter name convention
      // Here we try a simple mapping for strikethrough: name == "strikethrough" -> "~"
      if name == "strikethrough" {
        return processors.first { $0.delimiters.contains("~") }
      }
    }

    return processors
      .filter { $0.supports(delimiter: delimiter) }
      .sorted { $0.priority < $1.priority }
      .first
  }

  /// Rebuild content incorporating processed delimiter ranges
  private func rebuildContentWithProcessedRanges(
    context: inout MarkdownContentContext,
    processedRanges: [ProcessedRange]
  ) {
    // Clear existing content
    context.inlined.removeAll()

    var tokenIndex = 0

    while tokenIndex < context.tokens.count {
      // Check if we're at the start of a processed range
      if let range = processedRanges.first(where: { $0.openerStart == tokenIndex }) {
        // Insert the processed node
        context.add(range.node)
        // Skip all tokens covered by this range
        tokenIndex = range.closerEnd
        continue
      }

      // Check if this token is part of any processed range
      let isPartOfProcessedRange = processedRanges.contains { range in
        tokenIndex >= range.openerStart && tokenIndex < range.closerEnd
      }

      if !isPartOfProcessedRange {
        // Check if this token is an unmatched delimiter
        if let delimiterNode = findDelimiterAtTokenIndex(tokenIndex, in: context.delimiters) {
          if delimiterNode.run.isActive {
            // Add unmatched delimiter as text
            let delimiterText = reconstructDelimiterText(for: delimiterNode.run)
            context.add(delimiterText)
            // Skip the delimiter tokens
            tokenIndex += delimiterNode.run.length
            continue
          }
        }

        // Regular token - add as text or other node type
        let token = context.tokens[tokenIndex]
        switch token.element {
        case .characters, .whitespaces, .punctuation:
          context.add(token.text)
        case .newline:
          context.add(LineBreakNode(variant: .soft))
        case .charef:
          context.add(token.text) // TODO: Decode entity
        case .eof:
          break
        }
      }

      tokenIndex += 1
    }
  }

  /// Find delimiter at specific token index
  private func findDelimiterAtTokenIndex(_ index: Int, in delimiterStack: MarkdownDelimiterStack) -> MarkdownDelimiterStackNode? {
    var current = delimiterStack.forward(from: nil)
    while let delimiterNode = current.next() {
      if delimiterNode.run.index == index {
        return delimiterNode
      }
    }
    return nil
  }

  /// Reconstruct delimiter text for unmatched delimiters
  private func reconstructDelimiterText(for delimiterRun: MarkdownDelimiterRun) -> String {
    switch delimiterRun.delimiter {
    case .asterisk:
      return String(repeating: "*", count: delimiterRun.length)
    case .underscore:
      return String(repeating: "_", count: delimiterRun.length)
    case .custom(let name):
      if name == "strikethrough" {
        return String(repeating: "~", count: delimiterRun.length)
      }
      return ""
    case .backtick:
      return String(repeating: "`", count: delimiterRun.length)
    default:
      return ""
    }
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