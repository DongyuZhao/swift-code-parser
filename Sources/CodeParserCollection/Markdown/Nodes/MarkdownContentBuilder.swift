import CodeParserCore
import Foundation

/// ContentBuilder that dispatches inline markdown via a phase-based processor pipeline
public class MarkdownContentBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  private let scanPhaseProcessors: [MarkdownInlinePhaseProcessor]
  private let rebuildPhaseProcessors: [MarkdownInlinePhaseProcessor]

  public init() {
    // Assemble phase-based inline processors with priorities
    let inlineProcessors: [MarkdownInlinePhaseProcessor] = [
      // prefer native scan processors first
      EmphasisDelimiterScanProcessor(priority: -300),
      StrikethroughDelimiterScanProcessor(priority: -295),
      CodeSpanDelimiterScanProcessor(priority: -290),
      BracketDelimiterScanProcessor(priority: -285),
      AutolinkDelimiterScanProcessor(priority: -280),
      // rebuild-phase processors
      HardLineBreakRebuildProcessor(priority: 0),
      UnmatchedDelimiterInlineProcessor(priority: 0),
      // pair processors
      ReferenceLinkPairProcessor(priority: 3),
      AutolinkPairProcessor(priority: 4),
      LinkImagePairProcessor(priority: 5),
      CodeSpanPairProcessor(priority: 8), // Higher precedence than emphasis/strong
      EmphasisStrongPairProcessor(priority: 10),
      StrikethroughPairProcessor(priority: 10),
    ]
    self.scanPhaseProcessors = inlineProcessors.filter { $0.phase == .scan }.sorted { $0.priority < $1.priority }
    self.rebuildPhaseProcessors = inlineProcessors.filter { $0.phase == .rebuild }.sorted { $0.priority < $1.priority }
  }

  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    // Store reference to construct state for processors that need access to reference definitions
    let markdownState = context.state as? MarkdownConstructState
    
    // Traverse the AST to parse all the content nodes
    context.root.dfs { node in
      if let node = node as? ContentNode {
        let inlined = process(node.tokens, constructState: markdownState)
        finalize(node: node, with: inlined)
      }
    }
    return true
  }

  /// Process tokens into inline nodes using the configured processors
  /// Internal so processors can reuse it to parse nested content between delimiters.
  func process(_ tokens: [any CodeToken<MarkdownTokenElement>], constructState: MarkdownConstructState? = nil) -> [MarkdownNodeBase] {
    var context = MarkdownContentContext(tokens: tokens, constructState: constructState)

    // Process all tokens via scan-phase processors
    while context.current < tokens.count {
      let token = tokens[context.current]
      var handled = false
      for p in scanPhaseProcessors {
        if p.canHandle(token: token, at: context.current, context: context) {
          if p.handle(token: token, at: context.current, context: &context) {
            handled = true
            break
          }
        }
      }
      if !handled {
        // Fallback: plain text, whitespace, entities, soft line breaks
        switch token.element {
        case .characters, .punctuation, .whitespaces:
          context.add(token.text)
        case .newline:
          context.add(LineBreakNode(variant: .soft))
        case .charef:
          context.add(token.text)
        case .eof:
          break
        }
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

  // Collect all pair processors that can handle this delimiter, in priority order
  let pairHandlers = rebuildPhaseProcessors.filter { $0.canHandlePair(for: closerNode.run.delimiter) }

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
  var built: (node: MarkdownNodeBase, closerEndOverride: Int)? = nil
  for handler in pairHandlers {
    // Try context-aware method first (for processors that need reference definitions)
    if let n = handler.createNodeForPairWithContext(
      delimiter: closerNode.run.delimiter,
      openerRun: openerNode.run,
      closerRun: closerNode.run,
      contentTokens: contentTokens,
      allTokens: context.tokens,
      context: context
    ) { built = n; break }
    
    // Fall back to regular method
    if let n = handler.createNodeForPair(
      delimiter: closerNode.run.delimiter,
      openerRun: openerNode.run,
      closerRun: closerNode.run,
      contentTokens: contentTokens,
      allTokens: context.tokens
    ) { built = n; break }
  }
  if let built = built {
          // Compute a safe closerEnd (exclusive) within token bounds and not before the closer itself
          let minCloserEnd = closerTokenIndex + closerNode.run.length
          var safeCloserEnd = built.closerEndOverride
          if safeCloserEnd < minCloserEnd { safeCloserEnd = minCloserEnd }
          if safeCloserEnd < openerTokenIndex { safeCloserEnd = minCloserEnd }
          if safeCloserEnd > context.tokens.count { safeCloserEnd = context.tokens.count }

          // Store the processed range
          processedRanges.append(ProcessedRange(
            openerStart: openerTokenIndex,
            openerEnd: openerTokenIndex + openerNode.run.length,
            closerStart: closerTokenIndex,
            closerEnd: safeCloserEnd,
            node: built.node
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

    // Sort processed ranges to ensure deterministic rebuild and avoid overlaps
    let orderedRanges = processedRanges.sorted { lhs, rhs in
      if lhs.openerStart != rhs.openerStart { return lhs.openerStart < rhs.openerStart }
      // If same start, consume the longer range first
      return (lhs.closerEnd - lhs.openerStart) > (rhs.closerEnd - rhs.openerStart)
    }

    // Rebuild content with processed ranges
    rebuildContentWithProcessedRanges(context: &context, processedRanges: orderedRanges)
  }

  /// Helper struct for tracking processed delimiter ranges
  private struct ProcessedRange {
    let openerStart: Int
    let openerEnd: Int
    let closerStart: Int
    let closerEnd: Int
    let node: MarkdownNodeBase
  }

  // No legacy processor lookup; all inline semantics are handled by phase processors

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
            var handled = false
            for p in rebuildPhaseProcessors {
              if p.canHandleUnmatchedDelimiter(run: delimiterNode.run, at: tokenIndex, context: context) {
                if p.handleUnmatchedDelimiter(run: delimiterNode.run, at: tokenIndex, context: &context) {
                  handled = true
                  break
                }
              }
            }
            if !handled {
              // Fallback: reconstruct text from original tokens
              let start = max(0, delimiterNode.run.index)
              let end = min(context.tokens.count, delimiterNode.run.index + delimiterNode.run.length)
              if start < end {
                let text = context.tokens[start..<end].map { $0.text }.joined()
                context.add(text)
              }
            }
            tokenIndex += delimiterNode.run.length
            continue
          }
        }

        // Regular token - add as text or other node type (allow rebuild processors to handle)
        let token = context.tokens[tokenIndex]
        var handled = false
        for p in rebuildPhaseProcessors {
          if p.canHandleRebuildToken(token: token, at: tokenIndex, context: context) {
            if p.handleRebuildToken(token: token, at: tokenIndex, context: &context) {
              handled = true
              break
            }
          }
        }
        if !handled {
          switch token.element {
          case .characters, .whitespaces, .punctuation:
            context.add(token.text)
          case .newline:
            context.add(LineBreakNode(variant: .soft))
          case .charef:
            context.add(token.text)
          case .eof:
            break
          }
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