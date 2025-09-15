import CodeParserCore
import Foundation

// MARK: - Paragraph: Creation Resolver
/// Creates a ParagraphNode when encountering a non-blank, non-ATX-heading line.
public class MarkdownParagraphCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Paragraphs cannot start inside code blocks
    guard context.current.element != .codeBlock else { return false }

    let remainingTokens = Array(context.tokens[context.consumed...])
    guard !isBlankLine(remainingTokens) else { return false }

    // If line starts an ATX heading, let the heading resolver handle it.
    if isATXStart(remainingTokens) { return false }
    // Do not create a new paragraph if we're already inside one
    guard context.current.element != .paragraph else { return false }

    if let parent = context.current as? MarkdownNodeBase {
      let paragraph = ParagraphNode(range: remainingTokens.first?.range ?? remainingTokens.last?.range ?? ("".startIndex..<("".startIndex)))
      parent.append(paragraph)
      context.current = paragraph
      return true
    }
    return false
  }
}

// MARK: - Paragraph: Continuation Resolver
/// Keeps the current paragraph for non-blank lines; closes it on blank or ATX-start lines.
public class MarkdownParagraphContinuationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element == .paragraph else { return false }
    let tokens = Array(context.tokens[context.consumed...])

    // Ignore EOF-only line; block builder emits it as its own line
    if tokens.count == 1, tokens.first?.element == .eof { return false }

    // If this line is a thematic break, close the paragraph to allow interruption
    // If this line is a setext underline, handle it before thematic breaks so
    // that underline takes precedence when following a paragraph.
    if isSetextUnderline(tokens) {
      let (bqDepth, _) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
      let level = MarkdownSetextUtils.headingLevel(for: tokens) ?? 0
      if let parent = context.current.parent as? MarkdownNodeBase {
        if parent.element == .blockquote, bqDepth == 0 {
          if level == 2 {
            // Dashes: end blockquote and reprocess outside
            if let grand = parent.parent { context.current = grand } else { context.current = parent }
            context.refreshed = true
            return true
          } else {
            // Equals: keep inside blockquote as normal text
            return true
          }
        }
      }
      // Otherwise, keep paragraph open for heading transformation
      return true
    }

    if MarkdownThematicBreakUtils.isThematicBreakLine(tokens) {
      if let parent = context.current.parent as? MarkdownNodeBase {
        // If we're inside a blockquote and this line does not carry a '>' marker
        // (lazy continuation), end the blockquote as well so the thematic break
        // can be produced at the outer level.
        if parent.element == .blockquote {
          let (bqDepth, _) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
          if bqDepth == 0, let grand = parent.parent {
            context.current = grand
          } else {
            context.current = parent
          }
        } else {
          context.current = parent
        }
      }
      // Yield the same line to creation phase to recognize the break
      context.refreshed = true
      return true
    }

    // If next line starts a blockquote, end the paragraph to allow interruption
    let (bqDepth, _) = MarkdownBlockquoteUtils.parseMarkers(in: tokens)
    if bqDepth > 0 {
      if let parent = context.current.parent { context.current = parent }
      return true
    }

    if MarkdownFenceUtils.isFencedCodeFenceLine(tokens) {
      if let parent = context.current.parent { context.current = parent }
      context.refreshed = true
      return true
    }

    if isBlankLine(tokens) || isATXStart(tokens) {
      // Close paragraph and move current to parent
      if let parent = context.current.parent {
        // If parent is a blockquote and line is blank (no marker), end the blockquote as well
        if isBlankLine(tokens), parent.element == .blockquote, let grand = parent.parent {
          context.current = grand
        } else {
          context.current = parent
        }
      }
      // Request another continuation pass so containers (e.g., blockquote) can react
      context.refreshed = true
      return true
    }
    // Continue within the same paragraph but don't handle content - let construction resolver do that
    return false
  }
}

// MARK: - Paragraph: Construction Resolver
/// Adds line content as ContentNode to the current paragraph. For continued lines,
/// it inserts a LineBreakNode(.soft) between content chunks instead of synthetic spaces.
public class MarkdownParagraphConstructionResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let paragraph = context.current as? MarkdownNodeBase, paragraph.element == .paragraph else {
      return false
    }

    let tokens = Array(context.tokens[context.consumed...])
    guard !isBlankLine(tokens) else { return true }


    // With the consumption mechanism, indentation is already stripped by container resolvers
    // so we can use the tokens as-is without additional whitespace processing
    let contentTokens: [any CodeToken<MarkdownTokenElement>] = tokens
    if let last = paragraph.children.last as? ContentNode {
      last.tokens.append(contentsOf: contentTokens)
    } else {
      paragraph.append(ContentNode(tokens: contentTokens))
    }
    // Consume all tokens from this line since we processed them
    context.consumed = context.tokens.count
    return true
  }
}

// MARK: - Helpers
private func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  var i = 0
  while i < tokens.count {
    let t = tokens[i]
    if t.element == .newline || t.element == .eof { return true }
    if t.element != .whitespace { return false }
    i += 1
  }
  return true
}

private func isATXStart(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  var i = 0
  if i < tokens.count, tokens[i].element == .whitespace {
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    if spaceCount > 3 { return false }
    i += 1
  }
  var level = 0
  if i < tokens.count, tokens[i].element == .backslash { return false }
  while i < tokens.count, tokens[i].element == .hash {
    level += 1
    if level > 6 { break }
    i += 1
  }
  if level == 0 || level > 6 { return false }
  if i >= tokens.count { return false }
  return tokens[i].element == .whitespace || tokens[i].element == .newline || tokens[i].element == .eof
}

private func isSetextUnderline(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  // Mirrors the logic in MarkdownSetextUtils
  var i = 0
  if i < tokens.count, tokens[i].element == .whitespace {
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    if spaceCount > 3 { return false }
    i += 1
  }

  return MarkdownSetextUtils.headingLevel(for: tokens) != nil
}

private func nearestListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
  var cur = node as? MarkdownNodeBase
  while let c = cur {
    if let item = c as? ListItemNode { return item }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}
