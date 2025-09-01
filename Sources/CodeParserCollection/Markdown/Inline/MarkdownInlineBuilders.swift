import CodeParserCore
import Foundation

/// Markdown hard line break builder
/// Handles hard line breaks (backslash + newline) according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#hard-line-breaks
public class MarkdownHardLineBreakBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 5 }
  public var inlineType: MarkdownNodeElement { return .lineBreak }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count - 1 else { return false }
    let token = tokens[position]
    let nextToken = tokens[position + 1]
    
    // Check for backslash followed by newline
    return token.element == .punctuation && token.text == "\\" &&
           nextToken.element == .newline
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    guard position < tokens.count - 1 else { return nil }
    let token = tokens[position]
    let nextToken = tokens[position + 1]
    
    // Must be backslash followed by newline
    guard token.element == .punctuation && token.text == "\\" &&
          nextToken.element == .newline else {
      return nil
    }
    
    // Consume both tokens
    position += 2
    
    // Create hard line break node
    return LineBreakNode(variant: .hard)
  }
}

/// Markdown link builder
/// Handles inline links [text](url) according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#links
public class MarkdownLinkBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 30 }
  public var inlineType: MarkdownNodeElement { return .link }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count else { return false }
    let token = tokens[position]
    
    // Check for opening bracket
    return token.element == .punctuation && token.text == "["
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    // Simplified link processing - in a complete implementation,
    // this would handle the full CommonMark link parsing algorithm
    // including reference links, nested brackets, etc.
    
    guard position < tokens.count else { return nil }
    let token = tokens[position]
    
    guard token.element == .punctuation && token.text == "[" else {
      return nil
    }
    
    // For now, just treat as text - full link parsing is quite complex
    position += 1
    return TextNode(content: "[")
  }
}

/// Markdown image builder
/// Handles inline images ![alt](url) according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#images
public class MarkdownImageBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 25 }
  public var inlineType: MarkdownNodeElement { return .image }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count - 1 else { return false }
    let token1 = tokens[position]
    let token2 = tokens[position + 1]
    
    // Check for ![ sequence
    return token1.element == .punctuation && token1.text == "!" &&
           token2.element == .punctuation && token2.text == "["
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    // Simplified image processing - in a complete implementation,
    // this would handle the full CommonMark image parsing algorithm
    
    guard position < tokens.count - 1 else { return nil }
    let token1 = tokens[position]
    let token2 = tokens[position + 1]
    
    guard token1.element == .punctuation && token1.text == "!" &&
          token2.element == .punctuation && token2.text == "[" else {
      return nil
    }
    
    // For now, just treat as text - full image parsing is quite complex
    position += 2
    return TextNode(content: "![")
  }
}

/// Markdown HTML inline builder
/// Handles inline HTML tags according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#raw-html
public class MarkdownHTMLInlineBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 40 }
  public var inlineType: MarkdownNodeElement { return .html }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count else { return false }
    let token = tokens[position]
    
    // Check for opening angle bracket
    return token.element == .punctuation && token.text == "<"
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    // Simplified HTML processing - for now just treat as text
    position += 1
    return TextNode(content: "<")
  }
}

/// Markdown entity reference builder
/// Handles HTML entities like &amp; according to CommonMark rules
/// CommonMark Spec: https://spec.commonmark.org/0.31.2/#entity-and-numeric-character-references
public class MarkdownEntityReferenceBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 50 }
  public var inlineType: MarkdownNodeElement { return .text }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    guard position < tokens.count else { return false }
    let token = tokens[position]
    
    // Check for ampersand (start of entity reference)
    return token.element == .punctuation && token.text == "&"
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    // Simplified entity processing - for now just treat as text
    position += 1
    return TextNode(content: "&")
  }
}

/// Markdown text builder (fallback)
/// Handles plain text content
public class MarkdownTextBuilder: MarkdownInlineBuilderProtocol {
  
  public var priority: Int { return 1000 } // Lowest priority - fallback
  public var inlineType: MarkdownNodeElement { return .text }
  
  public init() {}
  
  public func canHandle(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: Int,
    state: MarkdownConstructState
  ) -> Bool {
    // Text builder can handle any token as fallback
    return position < tokens.count
  }
  
  public func process(
    tokens: [any CodeToken<MarkdownTokenElement>],
    position: inout Int,
    delimiterStack: inout [DelimiterEntry],
    state: MarkdownConstructState,
    context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>
  ) -> MarkdownNodeBase? {
    guard position < tokens.count else { return nil }
    let token = tokens[position]
    
    position += 1
    return TextNode(content: token.text)
  }
}