import CodeParserCore
import Foundation

// MARK: - Markdown Inline Parser
/// An inline parser that produces leaf Markdown nodes from a slice of tokens.
/// Implements CodeNodeBuilder so block builders can delegate inline content
/// construction using a nested build with a scoped context.
public struct MarkdownInlineBuilder: CodeNodeBuilder {
  public typealias Node = MarkdownNodeElement
  public typealias Token = MarkdownTokenElement

  public init() {}

  /// Build inline nodes from the provided tokens in the given context.
  /// Assumes the entire token list of the context represents inline content.
  public func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var i = tokens.startIndex

  // Inline sub-builders
  let html = MarkdownInlineHTMLBuilder()
  let autolink = MarkdownInlineAutolinkBuilder()
  let url = MarkdownInlineURLBuilder()
  let strongEmphasis = MarkdownStrongEmphasisBuilder()

    var buffer = ""
    var inFailedAngleBracket = false

    while i < tokens.endIndex {
      let t = tokens[i]

      if t.element == .newline {
        if !buffer.isEmpty { context.current.append(TextNode(content: buffer)) ; buffer.removeAll() }
        context.current.append(LineBreakNode(variant: .soft))
        i = tokens.index(after: i)
        continue
      }

      // Try HTML first
      if t.element == .punctuation && t.text == "<" {
        let preCount = context.current.count
        context.consuming = i
        if html.build(from: &context) {
          if context.current.count > preCount {
            if !buffer.isEmpty { context.current.insert(TextNode(content: buffer), at: preCount); buffer.removeAll() }
            i = context.consuming
            inFailedAngleBracket = false
            continue
          }
        }
      }

      // Then try angle-bracket autolink
      if t.element == .punctuation && t.text == "<" {
        let preCount = context.current.count
        context.consuming = i
        if autolink.build(from: &context) {
          if context.current.count > preCount {
            if !buffer.isEmpty { context.current.insert(TextNode(content: buffer), at: preCount); buffer.removeAll() }
            i = context.consuming
            inFailedAngleBracket = false
            continue
          }
        } else {
          inFailedAngleBracket = true
        }
      }

      // Reset failed angle bracket when '>' reached
      if inFailedAngleBracket && t.element == .punctuation && t.text == ">" { inFailedAngleBracket = false }

      // Bare URLs/emails (skip when in failed angle bracket)
      if !inFailedAngleBracket && t.element == .characters {
        let preCount = context.current.count
        context.consuming = i
        if url.build(from: &context) {
          if context.current.count > preCount {
            if !buffer.isEmpty { context.current.insert(TextNode(content: buffer), at: preCount); buffer.removeAll() }
            i = context.consuming
            continue
          }
        }
      }

      // Strong/Emphasis
      if t.element == .punctuation && (t.text == "*" || t.text == "_") {
        let preCount = context.current.count
        context.consuming = i
        if strongEmphasis.build(from: &context) {
          if context.current.count > preCount {
            if !buffer.isEmpty { context.current.insert(TextNode(content: buffer), at: preCount); buffer.removeAll() }
            i = context.consuming
            continue
          }
        }
      }

      // Fallback to buffer
      buffer.append(t.text)
      i = tokens.index(after: i)
    }

    if !buffer.isEmpty { context.current.append(TextNode(content: buffer)) }
    context.consuming = tokens.count
    return true
  }
}

// Inline helper functions have been moved into dedicated sub-builders (HTML, Autolink, URL, Emphasis)
// to avoid duplication here.
