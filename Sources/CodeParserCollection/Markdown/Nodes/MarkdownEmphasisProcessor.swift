import CodeParserCore
import Foundation

/// Processes emphasis (*text*) and strong emphasis (**text**)
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis
public class MarkdownEmphasisProcessor: MarkdownContentProcessor {
  public let delimiters: Set<Character> = ["*", "_"]

  // Temporary storage for processed emphasis ranges
  private var pendingEmphasis: [EmphasisRange] = []

  public init() {}

  public func process(
    _ token: any CodeToken<MarkdownTokenElement>,
    at index: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> Bool {
    guard token.element == .punctuation,
          let char = token.text.first,
          delimiters.contains(char) else {
      return false
    }

    // Aggregate consecutive delimiter tokens into a run
    let runInfo = buildDelimiterRun(
      startingAt: index,
      with: char,
      in: tokens,
      context: &context
    )

    // Create and push delimiter run to stack (no text node yet)
    let delimiterType: MarkdownDelimiter = (char == "*") ? .asterisk : .underscore
    let delimiterRun = MarkdownDelimiterRun(
      type: delimiterType,
      length: runInfo.length,
      openable: runInfo.canOpen,
      closable: runInfo.canClose,
      index: context.current // Use current token index, not inlined index
    )

    context.delimiters.push(delimiterRun, textNode: nil)

    // Advance past all processed tokens
    print("DEBUG: MarkdownEmphasisProcessor advancing by \(runInfo.length) (runInfo.length = \(runInfo.length))")
    context.advance(by: runInfo.length)

    return true
  }

  public func createNode(
    for delimiterType: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>
  ) -> MarkdownNodeBase? {
    // Only handle emphasis delimiters
    guard delimiterType == .asterisk || delimiterType == .underscore else {
      return nil
    }

    // Determine emphasis type based on delimiter run lengths
    let useLength = min(openerRun.length, closerRun.length)
    let isStrong = useLength >= 2

    // Create emphasis or strong node with recursively parsed children
    let emphasisNode: MarkdownNodeBase = isStrong ? StrongNode(content: "") : EmphasisNode(content: "")

    let builder = MarkdownContentBuilder()
    let inner = builder.process(Array(contentTokens))
    for child in inner {
      emphasisNode.append(child)
    }

    return emphasisNode
  }

  private func buildDelimiterRun(
    startingAt index: Int,
    with char: Character,
    in tokens: [any CodeToken<MarkdownTokenElement>],
    context: inout MarkdownContentContext
  ) -> (length: Int, canOpen: Bool, canClose: Bool) {

    var length = 0
    var currentIndex = index

    // Count consecutive delimiter characters
    while currentIndex < tokens.count,
          tokens[currentIndex].element == .punctuation,
          tokens[currentIndex].text == String(char) {
      length += 1
      currentIndex += 1
    }

    // Determine if this run can open or close emphasis based on flanking rules
    let canOpen = isLeftFlanking(
      delimiterIndex: index,
      runLength: length,
      in: tokens
    )

    let canClose = isRightFlanking(
      delimiterIndex: index,
      runLength: length,
      in: tokens
    )

    return (length: length, canOpen: canOpen, canClose: canClose)
  }

  private func isLeftFlanking(
    delimiterIndex: Int,
    runLength: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> Bool {
    let afterIndex = delimiterIndex + runLength

    // A delimiter run is left-flanking if:
    // 1. It is not followed by Unicode whitespace
    // 2. And either:
    //    a. It is not followed by a punctuation character
    //    b. Or it is followed by a punctuation character and preceded by whitespace or punctuation

    // Check what follows
    guard afterIndex < tokens.count else {
      // End of input - not left-flanking
      return false
    }

    let afterToken = tokens[afterIndex]

    // Rule 1: Not followed by whitespace
    if afterToken.element == .whitespaces {
      return false
    }

    // Rule 2a: Not followed by punctuation - can open
    if afterToken.element != .punctuation {
      return true
    }

    // Rule 2b: Followed by punctuation, check what precedes
    let beforeIndex = delimiterIndex - 1
    if beforeIndex < 0 {
      // Start of input - can open
      return true
    }

    let beforeToken = tokens[beforeIndex]
    return beforeToken.element == .whitespaces || beforeToken.element == .punctuation
  }

  private func isRightFlanking(
    delimiterIndex: Int,
    runLength: Int,
    in tokens: [any CodeToken<MarkdownTokenElement>]
  ) -> Bool {
    let beforeIndex = delimiterIndex - 1

    // A delimiter run is right-flanking if:
    // 1. It is not preceded by Unicode whitespace
    // 2. And either:
    //    a. It is not preceded by a punctuation character
    //    b. Or it is preceded by a punctuation character and followed by whitespace or punctuation

    // Check what precedes
    guard beforeIndex >= 0 else {
      // Start of input - not right-flanking
      return false
    }

    let beforeToken = tokens[beforeIndex]

    // Rule 1: Not preceded by whitespace
    if beforeToken.element == .whitespaces {
      return false
    }

    // Rule 2a: Not preceded by punctuation - can close
    if beforeToken.element != .punctuation {
      return true
    }

    // Rule 2b: Preceded by punctuation, check what follows
    let afterIndex = delimiterIndex + runLength
    if afterIndex >= tokens.count {
      // End of input - can close
      return true
    }

    let afterToken = tokens[afterIndex]
    return afterToken.element == .whitespaces || afterToken.element == .punctuation
  }

  // Store processed emphasis information for token order rebuilding
  private struct EmphasisRange {
    let openerStart: Int
    let openerEnd: Int
    let closerStart: Int
    let closerEnd: Int
    let emphasisNode: MarkdownNodeBase
  }

  private func processEmphasisDelimiters(context: inout MarkdownContentContext) {
    // Process delimiter pairs to collect emphasis information
    var currentDelimiterNode = context.delimiters.forward(from: nil)

    while let closerNode = currentDelimiterNode.next() {
      guard closerNode.run.closable,
            closerNode.run.isActive,
            (closerNode.run.delimiter == .asterisk || closerNode.run.delimiter == .underscore) else {
        continue
      }

      // Look for opener
      if let openerNode = context.delimiters.opener(for: closerNode.run.delimiter, before: closerNode) {
        // Ensure opener and closer are different nodes (shouldn't match with self)
        guard openerNode !== closerNode else {
          continue
        }

        // Determine emphasis type based on delimiter run lengths
        let useLength = min(openerNode.run.length, closerNode.run.length)
        let isStrong = useLength >= 2

        // Create emphasis or strong node with content
        let emphasisNode: MarkdownNodeBase = isStrong ? StrongNode(content: "") : EmphasisNode(content: "")

        // Add content between delimiters to emphasis node
        let openerTokenIndex = openerNode.run.index
        let closerTokenIndex = closerNode.run.index
        let contentStart = openerTokenIndex + openerNode.run.length
        let contentEnd = closerTokenIndex

        // Validate range before using it (opener must come before closer)
        guard contentStart <= contentEnd else {
          continue
        }

        for i in contentStart..<contentEnd {
          let token = context.tokens[i]
          switch token.element {
          case .characters, .whitespaces, .punctuation:
            emphasisNode.append(TextNode(content: token.text))
          case .newline:
            emphasisNode.append(LineBreakNode(variant: .soft))
          case .charef:
            emphasisNode.append(TextNode(content: token.text)) // TODO: Decode entity
          case .eof:
            break
          }
        }

        // Store the emphasis range info for later insertion during rebuild
        let emphasisRange = EmphasisRange(
          openerStart: openerTokenIndex,
          openerEnd: openerTokenIndex + openerNode.run.length,
          closerStart: closerTokenIndex,
          closerEnd: closerTokenIndex + closerNode.run.length,
          emphasisNode: emphasisNode
        )

        // Store emphasis info temporarily on the processor instance
        self.pendingEmphasis.append(emphasisRange)

        // Mark delimiters as processed
        openerNode.run.isActive = false
        closerNode.run.isActive = false

        // Clean up delimiter stack
        context.delimiters.clear(after: openerNode)

        // Restart from the beginning after modifying the delimiter stack
        currentDelimiterNode = context.delimiters.forward(from: nil)
      }
    }
  }

  private func rebuildContentInTokenOrder(context: inout MarkdownContentContext) {
    // Clear the existing inlined content - we'll rebuild everything in proper token order
    context.inlined.removeAll()

    var tokenIndex = 0

    while tokenIndex < context.tokens.count {
      // Check if we're at the start of an emphasis range
      if let emphasisRange = pendingEmphasis.first(where: { $0.openerStart == tokenIndex }) {
        // Insert the emphasis node
        context.add(emphasisRange.emphasisNode)

        // Skip all tokens covered by this emphasis (opener + content + closer)
        tokenIndex = emphasisRange.closerEnd
        continue
      }

      // Check if this token is part of any emphasis range (should be skipped)
      let isPartOfEmphasis = pendingEmphasis.contains { emphasisRange in
        tokenIndex >= emphasisRange.openerStart && tokenIndex < emphasisRange.closerEnd
      }

      if !isPartOfEmphasis {
        // Check if this token is an unmatched delimiter
        if let delimiterNode = findDelimiterAtIndex(tokenIndex, in: context.delimiters) {
          if delimiterNode.run.isActive {
            // Add unmatched delimiter as text
            let delimiterChar = delimiterNode.run.delimiter == .asterisk ? "*" : "_"
            let delimiterText = String(repeating: delimiterChar, count: delimiterNode.run.length)
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

  private func findDelimiterAtIndex(_ index: Int, in delimiterStack: MarkdownDelimiterStack) -> MarkdownDelimiterStackNode? {
    var current = delimiterStack.forward(from: nil)
    while let delimiterNode = current.next() {
      if delimiterNode.run.index == index {
        return delimiterNode
      }
    }
    return nil
  }
}