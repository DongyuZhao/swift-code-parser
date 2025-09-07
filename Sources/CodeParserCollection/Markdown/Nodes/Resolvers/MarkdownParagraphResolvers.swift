import CodeParserCore
import Foundation

// MARK: - Paragraph: Creation Resolver
/// Creates a ParagraphNode when encountering a non-blank, non-ATX-heading line.
public class MarkdownParagraphCreationResolver: MarkdownBlockResolver {
  public init() {}

  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    let tokens = context.tokens
    guard !isBlankLine(tokens) else { return false }
    // If line starts an ATX heading, let the heading resolver handle it.
    if isATXStart(tokens) { return false }
    // Do not create a new paragraph if we're already inside one
    guard context.current.element != .paragraph else { return false }

    if let parent = context.current as? MarkdownNodeBase {
      let paragraph = ParagraphNode(range: tokens.first?.range ?? tokens.last?.range ?? ("".startIndex..<("".startIndex)))
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
    let tokens = context.tokens

    // Ignore EOF-only line; block builder emits it as its own line
    if tokens.count == 1, tokens.first?.element == .eof { return false }

    // If this line is a thematic break, close the paragraph to allow interruption
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

    // If this line is a setext underline:
    // - Do NOT end the paragraph here; leave it as current so the creation
    //   resolver can transform it only when it immediately follows the paragraph.
    // - Additionally, prevent transformation if we're inside a blockquote and the
    //   line is a lazy continuation (no '>'): in that case, keep the paragraph
    //   open so the underline is treated as literal text or other block (e.g. thematic break).
    if isSetextUnderline(tokens) {
      if let parent = context.current.parent as? MarkdownNodeBase, parent.element == .blockquote {
        if bqDepth == 0 {
          // Lazy continuation within blockquote: keep the paragraph open
          return true
        }
      }
      // Keep paragraph as current; creation resolver will handle transformation
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
    // Continue within the same paragraph
    return true
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

    let tokens = context.tokens
    guard !isBlankLine(tokens) else { return true }

    var i = 0
    // Determine if this is a continued line within an existing paragraph
    let hasPriorContent = paragraph.children.contains { $0.element == .content }
    if i < tokens.count, tokens[i].element == .whitespaces {
      let ws = tokens[i].text
      let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if hasPriorContent {
        // For continuation lines, strip up to 4 spaces of indentation
        if spaceCount <= 4 { i += 1 }
      } else {
        // For the first line, skip at most three spaces
        if spaceCount <= 3 { i += 1 }
      }
    }

    // Include all remaining tokens (including .newline/.eof) for inline processing
    let contentTokens: [any CodeToken<MarkdownTokenElement>] = Array(tokens[i...])
    paragraph.append(ContentNode(tokens: contentTokens))
    return true
  }
}

// MARK: - Helpers
private func isBlankLine(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  var i = 0
  while i < tokens.count {
    let t = tokens[i]
    if t.element == .newline || t.element == .eof { return true }
    if t.element != .whitespaces { return false }
    i += 1
  }
  return true
}

private func isATXStart(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  var i = 0
  if i < tokens.count, tokens[i].element == .whitespaces {
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    if spaceCount > 3 { return false }
    i += 1
  }
  var level = 0
  while i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "#" {
    level += 1
    if level > 6 { break }
    i += 1
  }
  if level == 0 || level > 6 { return false }
  if i >= tokens.count { return false }
  return tokens[i].element == .whitespaces || tokens[i].element == .newline || tokens[i].element == .eof
}

private func isSetextUnderline(_ tokens: [any CodeToken<MarkdownTokenElement>]) -> Bool {
  // Mirrors the logic in MarkdownSetextUtils
  var i = 0
  if i < tokens.count, tokens[i].element == .whitespaces {
    let ws = tokens[i].text
    let spaceCount = ws.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    if spaceCount > 3 { return false }
    i += 1
  }

  return MarkdownSetextUtils.headingLevel(for: tokens) != nil
}
