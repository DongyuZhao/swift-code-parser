import CodeParserCore
import Foundation

/// Context passed to inline processors containing shared state
public struct MarkdownContentContext {
  /// The delimiter stack for managing nested constructs
  public var delimiters: MarkdownDelimiterStack

  /// Current inline nodes being built
  public var inlined: [MarkdownNodeBase]

  /// Current token index being processed
  public var current: Int

  /// All tokens in the content
  public let tokens: [any CodeToken<MarkdownTokenElement>]

  public init(tokens: [any CodeToken<MarkdownTokenElement>]) {
    self.delimiters = MarkdownDelimiterStack()
    self.inlined = []
    self.current = 0
    self.tokens = tokens
  }

  /// Helper to add text node or merge with previous text node
  /// Only merges if the last node is not a delimiter in the delimiter stack
  public mutating func add(_ text: String) {
    if let last = inlined.last as? TextNode,
       !isDelimiterTextNode(last) {
      last.content += text
    } else {
      inlined.append(TextNode(content: text))
    }
  }

  /// Check if a text node is associated with a delimiter in the stack
  private func isDelimiterTextNode(_ textNode: TextNode) -> Bool {
    return delimiters.contains(textNode)
  }

  /// Helper to add any inline node
  public mutating func add(_ node: MarkdownNodeBase) {
    inlined.append(node)
  }

  /// Advance the current token index by a delta (can be negative if needed, but use with care).
  /// Typical usage: when a processor aggregates a delimiter run spanning N tokens, it should call
  /// `advance(by: N)` to skip all N tokens completely.
  public mutating func advance(by delta: Int) {
    current += delta
  }
}

// MARK: - Delimiter Stack (Extracted from ContentBuilder)

public enum MarkdownDelimiter: Hashable {
  case asterisk
  case underscore
  case openBracket
  case openImageBracket
  case backtick(count: Int)
  case angleBracket
  case custom(String)
}

public struct MarkdownDelimiterRun {
  public let delimiter: MarkdownDelimiter
  public let length: Int
  public let openable: Bool
  public let closable: Bool
  public let index: Int
  public var isActive: Bool = true

  public init(type: MarkdownDelimiter, length: Int, openable: Bool, closable: Bool, index: Int) {
    self.delimiter = type
    self.length = length
    self.openable = openable
    self.closable = closable
    self.index = index // token index
  }
}

public class MarkdownDelimiterStackNode {
  public var run: MarkdownDelimiterRun
  public var text: TextNode?
  public weak var previous: MarkdownDelimiterStackNode?
  public var next: MarkdownDelimiterStackNode?

  public init(delimiterRun: MarkdownDelimiterRun, textNode: TextNode? = nil) {
    self.run = delimiterRun
    self.text = textNode
  }
}

public class MarkdownDelimiterStack {
  private var head: MarkdownDelimiterStackNode?
  private var tail: MarkdownDelimiterStackNode?

  public init() {}

  public func push(_ delimiterRun: MarkdownDelimiterRun, textNode: TextNode? = nil) {
    let node = MarkdownDelimiterStackNode(delimiterRun: delimiterRun, textNode: textNode)

    if let currentTail = tail {
      currentTail.next = node
      node.previous = currentTail
      tail = node
    } else {
      head = node
      tail = node
    }
  }

  public func remove(_ node: MarkdownDelimiterStackNode) {
    if node.previous != nil {
      node.previous?.next = node.next
    } else {
      head = node.next
    }

    if node.next != nil {
      node.next?.previous = node.previous
    } else {
      tail = node.previous
    }
  }

  public func opener(for type: MarkdownDelimiter, before node: MarkdownDelimiterStackNode?) -> MarkdownDelimiterStackNode? {
    var current = node?.previous ?? tail
    while let currentNode = current {
      if currentNode.run.delimiter == type &&
         currentNode.run.openable &&
         currentNode.run.isActive {
        return currentNode
      }
      current = currentNode.previous
    }
    return nil
  }

  public func clear(after stackBottom: MarkdownDelimiterStackNode?) {
    var current = stackBottom?.next ?? head
    while let node = current {
      let next = node.next
      remove(node)
      current = next
    }
  }

  public var isEmpty: Bool {
    return head == nil
  }

  public func forward(from start: MarkdownDelimiterStackNode?) -> MarkdownDelimiterStackIterator {
    return MarkdownDelimiterStackIterator(current: start ?? head)
  }

  public func contains(_ textNode: TextNode) -> Bool {
    var current = head
    while let node = current {
      if node.text === textNode {
        return true
      }
      current = node.next
    }
    return false
  }
}

public struct MarkdownDelimiterStackIterator: IteratorProtocol {
  private var current: MarkdownDelimiterStackNode?

  public init(current: MarkdownDelimiterStackNode?) {
    self.current = current
  }

  public mutating func next() -> MarkdownDelimiterStackNode? {
    let result = current
    current = current?.next
    return result
  }
}

// MARK: - Phase-based Inline Pipeline

public enum MarkdownInlinePhase {
  case scan    // streaming token scan
  case rebuild // token-to-node rebuild after delimiter pairing
}

public protocol MarkdownInlinePhaseProcessor {
  var phase: MarkdownInlinePhase { get }
  var priority: Int { get }

  // Scan phase hooks
  func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool
  func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool

  // Rebuild phase hooks (for unmatched delimiters, etc)
  func canHandleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: MarkdownContentContext) -> Bool
  func handleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: inout MarkdownContentContext) -> Bool

  // Rebuild-time token handling (e.g., newline hard/soft decision)
  func canHandleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool
  func handleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool

  // Pair handling for matched delimiters
  func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool
  // Return value allows processor to extend the consumed range beyond closer (e.g., parse (dest "title")).
  // closerEndOverride: if provided, it's the exclusive end index to consume (>= closerRun.index + closerRun.length).
  func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    allTokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (node: MarkdownNodeBase, closerEndOverride: Int)?
}

public extension MarkdownInlinePhaseProcessor {
  func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool { false }
  func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool { false }
  func canHandleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: MarkdownContentContext) -> Bool { false }
  func handleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: inout MarkdownContentContext) -> Bool { false }
  func canHandleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool { false }
  func handleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool { false }
  func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool { false }
  func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    allTokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (node: MarkdownNodeBase, closerEndOverride: Int)? { nil }
}

// MARK: Default inline phase processors

/// Detect hard/soft line breaks per CommonMark; trims trailing spaces for hard breaks
public struct HardLineBreakRebuildProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int

  public init(priority: Int = 0) { self.priority = priority }

  public func canHandleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .newline
  }

  public func handleRebuildToken(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    // Determine if hard break by scanning backwards
    var i = index - 1
    var trailingSpaces = 0
    while i >= 0 {
      let tok = context.tokens[i]
      switch tok.element {
      case .whitespaces:
        trailingSpaces += tok.text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
        i -= 1
        continue
      case .punctuation:
        // Backslash must be immediately before newline (no trailing spaces)
        if tok.text == "\\" {
          context.add(LineBreakNode(variant: .hard))
          return true
        }
        let isHard = trailingSpaces >= 2
        if isHard { cleanupTrailingSpaces(in: &context, count: 2) }
        context.add(LineBreakNode(variant: isHard ? .hard : .soft))
        return true
      case .characters, .charef:
        let isHard = trailingSpaces >= 2
        if isHard { cleanupTrailingSpaces(in: &context, count: 2) }
        context.add(LineBreakNode(variant: isHard ? .hard : .soft))
        return true
      case .newline, .eof:
        context.add(LineBreakNode(variant: .soft))
        return true
      }
    }
    let isHard = trailingSpaces >= 2
    if isHard { cleanupTrailingSpaces(in: &context, count: 2) }
    context.add(LineBreakNode(variant: isHard ? .hard : .soft))
    return true
  }

  private func cleanupTrailingSpaces(in context: inout MarkdownContentContext, count maxToRemove: Int) {
    guard !context.inlined.isEmpty else { return }
    var idx = context.inlined.count - 1
    var removed = 0
    while idx >= 0 && removed < maxToRemove {
      if let textNode = context.inlined[idx] as? TextNode {
        let text = textNode.content
        if text.allSatisfy({ $0 == " " }) {
          let spaceCount = text.count
          if removed + spaceCount >= maxToRemove {
            let keep = max(0, removed + spaceCount - maxToRemove)
            if keep > 0 { textNode.content = String(repeating: " ", count: keep) } else { context.inlined.remove(at: idx) }
            removed = maxToRemove
            break
          } else {
            removed += spaceCount
            context.inlined.remove(at: idx)
          }
        } else if text.hasSuffix(" ") {
          var endSpaces = 0
          for ch in text.reversed() {
            if ch == " " && removed + endSpaces < maxToRemove { endSpaces += 1 } else { break }
          }
          if endSpaces > 0 {
            textNode.content = String(text.dropLast(endSpaces))
            removed += endSpaces
          }
          break
        } else {
          break
        }
      }
      idx -= 1
    }
  }
}

/// Render unmatched delimiters back to text using the original token slice
public struct UnmatchedDelimiterInlineProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 0) { self.priority = priority }

  public func canHandleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: MarkdownContentContext) -> Bool { true }

  public func handleUnmatchedDelimiter(run: MarkdownDelimiterRun, at tokenIndex: Int, context: inout MarkdownContentContext) -> Bool {
    let start = max(0, run.index)
    let end = min(context.tokens.count, run.index + run.length)
    guard start < end else { return false }
    let text = context.tokens[start..<end].map { $0.text }.joined()
    context.add(text)
    return true
  }
}

// MARK: - Scan processors for delimiter runs

/// Scan asterisk/underscore sequences and push delimiter runs into the stack
public struct EmphasisDelimiterScanProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .scan
  public let priority: Int
  public init(priority: Int = -200) { self.priority = priority }

  public func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .punctuation && (token.text == "*" || token.text == "_")
  }

  public func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    guard let ch = token.text.first else { return false }
    let start = index
    var i = index
    var len = 0
    while i < context.tokens.count, context.tokens[i].element == .punctuation, context.tokens[i].text.first == ch {
      len += 1
      i += 1
    }
    let type: MarkdownDelimiter = (ch == "*") ? .asterisk : .underscore
    let run = MarkdownDelimiterRun(type: type, length: len, openable: true, closable: true, index: start)
    context.delimiters.push(run, textNode: nil)
    context.advance(by: len)
    return true
  }
}

/// Scan tilde sequences for GFM strikethrough
public struct StrikethroughDelimiterScanProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .scan
  public let priority: Int
  public init(priority: Int = -195) { self.priority = priority }

  public func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .punctuation && token.text == "~"
  }

  public func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    let start = index
    var i = index
    var len = 0
    while i < context.tokens.count, context.tokens[i].element == .punctuation, context.tokens[i].text == "~" {
      len += 1
      i += 1
    }
    let run = MarkdownDelimiterRun(type: .custom("strikethrough"), length: len, openable: true, closable: true, index: start)
    context.delimiters.push(run, textNode: nil)
    context.advance(by: len)
    return true
  }
}

/// Scan backtick sequences for code spans
public struct CodeSpanDelimiterScanProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .scan
  public let priority: Int
  public init(priority: Int = -190) { self.priority = priority }

  public func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .punctuation && token.text == "`"
  }

  public func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    let start = index
    var i = index
    var len = 0
    while i < context.tokens.count, context.tokens[i].element == .punctuation, context.tokens[i].text == "`" {
      len += 1
      i += 1
    }
    let run = MarkdownDelimiterRun(type: .backtick(count: len), length: len, openable: true, closable: true, index: start)
    context.delimiters.push(run, textNode: nil)
    context.advance(by: len)
    return true
  }
}

// MARK: - Pair processors (create nodes for matched runs)

public struct EmphasisStrongPairProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 0) { self.priority = priority }

  public func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool {
    switch delimiter { case .asterisk, .underscore: return true; default: return false }
  }

  public func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>
  ) -> MarkdownNodeBase? {
    let inner = MarkdownContentBuilder().process(Array(contentTokens))
    let minLen = min(openerRun.length, closerRun.length)
    if minLen >= 2 {
      let strong = StrongNode(content: "")
      inner.forEach { strong.append($0) }
      return strong
    } else {
      let em = EmphasisNode(content: "")
      inner.forEach { em.append($0) }
      return em
    }
  }
}

public struct StrikethroughPairProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 0) { self.priority = priority }

  public func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool {
    if case .custom(let name) = delimiter { return name == "strikethrough" }
    return false
  }

  public func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>
  ) -> MarkdownNodeBase? {
    let inner = MarkdownContentBuilder().process(Array(contentTokens))
    let strike = StrikeNode(content: "")
    inner.forEach { strike.append($0) }
    return strike
  }
}

public struct CodeSpanPairProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 0) { self.priority = priority }

  public func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool {
    if case .backtick = delimiter { return true }
    return false
  }

  public func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    allTokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (node: MarkdownNodeBase, closerEndOverride: Int)? {
    // Code span content is literal; join token text
    let raw = contentTokens.map { $0.text }.joined()
    let code = raw.trimmingCharacters(in: .whitespaces)
    return (CodeSpanNode(code: code), closerRun.index + closerRun.length)
  }
}

// MARK: - Bracket scan and link/image pair processors

/// Scan for [ and ] (and detect image opener ![) and push delimiter runs into the stack.
public struct BracketDelimiterScanProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .scan
  public let priority: Int
  public init(priority: Int = -285) { self.priority = priority }

  public func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .punctuation && (token.text == "[" || token.text == "]")
  }

  public func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    if token.text == "[" {
      // Detect image opener if immediately preceded by '!'
      var openerIndex = index
      var length = 1
      if index > 0 {
        let prev = context.tokens[index - 1]
        if prev.element == .punctuation && prev.text == "!" {
          openerIndex = index - 1
          length = 2
        }
      }
      let run = MarkdownDelimiterRun(type: .openBracket, length: length, openable: true, closable: false, index: openerIndex)
      context.delimiters.push(run, textNode: nil)
      // Advance only by 1 because the scan loop index is at '['; the preceding '!' (if any) will be skipped during rebuild via range consumption
      context.advance(by: 1)
      return true
    } else {
      // ']' as closer
      let run = MarkdownDelimiterRun(type: .openBracket, length: 1, openable: false, closable: true, index: index)
      context.delimiters.push(run, textNode: nil)
      context.advance(by: 1)
      return true
    }
  }
}

/// Scan for < and > for autolinks and push delimiter runs into the stack.
public struct AutolinkDelimiterScanProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .scan
  public let priority: Int
  public init(priority: Int = -280) { self.priority = priority }

  public func canHandle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: MarkdownContentContext) -> Bool {
    token.element == .punctuation && (token.text == "<" || token.text == ">")
  }

  public func handle(token: any CodeToken<MarkdownTokenElement>, at index: Int, context: inout MarkdownContentContext) -> Bool {
    if token.text == "<" {
      // '<' as opener
      let run = MarkdownDelimiterRun(type: .angleBracket, length: 1, openable: true, closable: false, index: index)
      context.delimiters.push(run, textNode: nil)
      context.advance(by: 1)
      return true
    } else {
      // '>' as closer
      let run = MarkdownDelimiterRun(type: .angleBracket, length: 1, openable: false, closable: true, index: index)
      context.delimiters.push(run, textNode: nil)
      context.advance(by: 1)
      return true
    }
  }
}

/// Pair processor for links and images using bracket delimiters; supports inline form: [text](dest "title") and ![alt](dest "title")
public struct LinkImagePairProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 5) { self.priority = priority }

  public func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool { delimiter == .openBracket }

  public func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    allTokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (node: MarkdownNodeBase, closerEndOverride: Int)? {
    // Determine if this is image: opener length 2 means '!['
    let isImage = openerRun.length >= 2

    // Build inner inline nodes for link text / alt text
    let inner = MarkdownContentBuilder().process(Array(contentTokens))

    // After closer ']' parse optional inline destination in parentheses
    var idx = closerRun.index + closerRun.length
    // skip spaces
    while idx < allTokens.count, allTokens[idx].element == .whitespaces { idx += 1 }
    guard idx < allTokens.count, allTokens[idx].element == .punctuation, allTokens[idx].text == "(" else {
      // No inline destination -> not handled; let unmatched processor render literally
      return nil
    }

    // Consume '('
    idx += 1
    // Parse destination until matching ')', simple balance of parentheses for non-escaped text
  let destStart = idx
    var depth = 1
    while idx < allTokens.count {
      let t = allTokens[idx]
      if t.element == .punctuation {
        if t.text == "(" { depth += 1 }
        else if t.text == ")" { depth -= 1; if depth == 0 { break } }
      }
      idx += 1
    }
    guard idx < allTokens.count else { return nil }
    let destEnd = idx // position of ')' to close
    // Extract raw inside (could include title; we'll do a best-effort split)
    let inside = allTokens[destStart..<destEnd].map { $0.text }.joined()
    // Naive parse: destination [space+ title]? where title in quotes
    let (dest, title) = Self.splitDestAndTitle(inside: inside)

    // Build node
    if isImage {
      let alt = Self.flattenText(from: inner)
      let image = ImageNode(url: dest, alt: alt, title: title)
      return (image, idx + 1)
    } else {
      let link = LinkNode(url: dest, title: title)
      inner.forEach { link.append($0) }
      return (link, idx + 1)
    }
  }

  private static func flattenText(from nodes: [MarkdownNodeBase]) -> String {
    var out = ""
    func dfs(_ n: MarkdownNodeBase) {
      if let t = n as? TextNode { out += t.content; return }
      for c in n.children { if let m = c as? MarkdownNodeBase { dfs(m) } }
    }
    for n in nodes { dfs(n) }
    return out
  }

  private static func splitDestAndTitle(inside: String) -> (dest: String, title: String) {
    // Trim outer spaces
    let s = inside.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty { return ("", "") }
    // If contains a quoted title at the end
    if let quoteStart = s.lastIndex(where: { $0 == "\"" || $0 == "'" }) {
      let quote = s[quoteStart]
      if quoteStart > s.startIndex, s[quoteStart...] .first == quote, s.last == quote {
        // Title in quotes; split at the preceding space
        let before = s[..<quoteStart]
        if let sp = before.lastIndex(where: { $0.isWhitespace }) {
          let dest = String(before[..<sp]).trimmingCharacters(in: .whitespaces)
          let title = String(s[s.index(after: quoteStart)..<s.index(before: s.endIndex)])
          return (dest, title)
        }
      }
    }
    return (s, "")
  }
}

/// Pair processor for autolinks using angle bracket delimiters; supports autolink form: <url> and <email>
public struct AutolinkPairProcessor: MarkdownInlinePhaseProcessor {
  public let phase: MarkdownInlinePhase = .rebuild
  public let priority: Int
  public init(priority: Int = 4) { self.priority = priority } // Higher priority than LinkImagePairProcessor

  public func canHandlePair(for delimiter: MarkdownDelimiter) -> Bool { delimiter == .angleBracket }

  public func createNodeForPair(
    delimiter: MarkdownDelimiter,
    openerRun: MarkdownDelimiterRun,
    closerRun: MarkdownDelimiterRun,
    contentTokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    allTokens: [any CodeToken<MarkdownTokenElement>]
  ) -> (node: MarkdownNodeBase, closerEndOverride: Int)? {
    // Extract content between angle brackets
    let content = contentTokens.map { $0.text }.joined()
    
    // Validate autolink content
    guard isValidAutolink(content) else { return nil }
    
    // Determine URL and create LinkNode
    let url: String
    if isEmailAddress(content) {
      url = "mailto:" + content
    } else {
      url = content
    }
    
    let link = LinkNode(url: url, title: "")
    let textNode = TextNode(content: content)
    link.append(textNode)
    
    return (link, closerRun.index + closerRun.length)
  }
  
  private func isValidAutolink(_ content: String) -> Bool {
    // Check for invalid characters (spaces, newlines, control characters)
    if content.isEmpty || content.contains(" ") || content.contains("\n") || content.contains("\r") || content.contains("\t") {
      return false
    }
    
    // Check if it's either a valid URI or email
    return isValidURI(content) || isEmailAddress(content)
  }
  
  private func isValidURI(_ content: String) -> Bool {
    // Check for scheme:path pattern according to CommonMark spec
    guard let colonIndex = content.firstIndex(of: ":") else { return false }
    
    let scheme = String(content[..<colonIndex])
    let path = String(content[content.index(after: colonIndex)...])
    
    // Scheme must be 2-32 characters: [A-Za-z][A-Za-z0-9.+-]{1,31}
    guard scheme.count >= 2 && scheme.count <= 32 else { return false }
    guard scheme.first?.isLetter == true else { return false }
    
    // Check remaining characters in scheme
    for char in scheme.dropFirst() {
      if !char.isLetter && !char.isNumber && char != "." && char != "+" && char != "-" {
        return false
      }
    }
    
    // Path must not be empty and must not contain unescaped < or >
    guard !path.isEmpty else { return false }
    
    // Basic validation - no unescaped angle brackets
    if path.contains("<") || path.contains(">") {
      return false
    }
    
    return true
  }
  
  private func isEmailAddress(_ content: String) -> Bool {
    // Simple email validation according to CommonMark spec
    guard let atIndex = content.firstIndex(of: "@") else { return false }
    
    let local = String(content[..<atIndex])
    let domain = String(content[content.index(after: atIndex)...])
    
    // Local part must not be empty and must contain valid characters
    guard !local.isEmpty && !domain.isEmpty else { return false }
    
    // Basic validation - contains @ and has reasonable structure
    let emailRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$")
    let range = NSRange(location: 0, length: content.count)
    return emailRegex.firstMatch(in: content, options: [], range: range) != nil
  }
}
