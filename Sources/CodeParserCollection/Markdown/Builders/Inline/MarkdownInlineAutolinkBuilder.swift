import CodeParserCore
import Foundation

/// Build autolinks in angle brackets: <scheme:...> and <local@domain>
struct MarkdownInlineAutolinkBuilder: CodeNodeBuilder {
  typealias Node = MarkdownNodeElement
  typealias Token = MarkdownTokenElement

  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var i = context.consuming
    guard i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "<" else { return false }

    // Use a slice view for helper logic
    let slice = tokens[i..<tokens.count]
    let (node, nextIdxInSlice) = parseAutolink(slice, startIndex: slice.startIndex)
    guard let n = node else { return false }

    // Map slice index back to absolute index
    let advanced = slice.distance(from: slice.startIndex, to: nextIdxInSlice)
    let nextAbs = i + advanced
    context.current.append(n)
    context.consuming = nextAbs
    return true
  }

  // MARK: - Helpers (scoped to this builder)
  private func isValidScheme(_ scheme: String) -> Bool {
    if scheme.count < 2 || scheme.count > 32 { return false }
    guard let first = scheme.first, first.isLetter else { return false }
    for char in scheme {
      if !char.isLetter && !char.isNumber && char != "+" && char != "-" && char != "." { return false }
    }
    return true
  }

  private func isValidEmailLocal(_ local: String) -> Bool {
    if local.isEmpty { return false }
    for char in local {
      if !char.isLetter && !char.isNumber && char != "." && char != "-" && char != "_" && char != "+" { return false }
    }
    return true
  }

  private func isValidEmailDomain(_ domain: String) -> Bool {
    if domain.isEmpty { return false }
    let parts = domain.split(separator: ".")
    if parts.count < 2 { return false }
    for part in parts {
      if part.isEmpty { return false }
      if part.first == "-" || part.first == "_" || part.last == "-" || part.last == "_" { return false }
      for char in part { if !char.isLetter && !char.isNumber && char != "-" && char != "_" { return false } }
    }
    return true
  }

  private func parseAutolink(
    _ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    startIndex: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index
  ) -> (MarkdownNodeBase?, ArraySlice<any CodeToken<MarkdownTokenElement>>.Index) {
    guard startIndex < tokens.endIndex,
          tokens[startIndex].element == .punctuation,
          tokens[startIndex].text == "<" else {
      return (nil, startIndex)
    }

    var i = tokens.index(after: startIndex)
    var contentTokens: [any CodeToken<MarkdownTokenElement>] = []
    var found = false

    while i < tokens.endIndex {
      let token = tokens[i]
      if token.element == .punctuation && token.text == ">" { found = true; break }
      if token.element == .whitespaces || token.element == .newline { return (nil, startIndex) }
      contentTokens.append(token)
      i = tokens.index(after: i)
    }
    if !found || contentTokens.isEmpty { return (nil, startIndex) }

    var hasColon = false, colonIndex = -1
    var hasAt = false, atIndex = -1
    var hasBackslash = false
    for (index, token) in contentTokens.enumerated() {
      if token.element == .punctuation {
        if token.text == ":" && !hasColon { hasColon = true; colonIndex = index }
        else if token.text == "@" && !hasAt { hasAt = true; atIndex = index }
      } else if token.element == .characters, token.text.contains("\\") { hasBackslash = true }
    }

    let content = tokensToString(contentTokens[contentTokens.startIndex..<contentTokens.endIndex])
    if hasColon && colonIndex > 0 {
      let schemeTokens = contentTokens[0..<colonIndex]
      let scheme = tokensToString(schemeTokens[schemeTokens.startIndex..<schemeTokens.endIndex])
      if isValidScheme(scheme) {
        let encodedURL = content
          .replacingOccurrences(of: "\\", with: "%5C")
          .replacingOccurrences(of: "[", with: "%5B")
          .replacingOccurrences(of: "]", with: "%5D")
        let link = LinkNode(url: encodedURL, title: "")
        link.append(TextNode(content: content))
        return (link, tokens.index(after: i))
      }
    }

    if hasAt && atIndex > 0 && atIndex < contentTokens.count - 1 {
      if hasBackslash { return (nil, startIndex) }
      let localTokens = contentTokens[0..<atIndex]
      let domainTokens = contentTokens[(atIndex + 1)...]
      let local = tokensToString(localTokens[localTokens.startIndex..<localTokens.endIndex])
      let domain = tokensToString(domainTokens[domainTokens.startIndex..<domainTokens.endIndex])
      if isValidEmailLocal(local) && isValidEmailDomain(domain) {
        let link = LinkNode(url: "mailto:" + content, title: "")
        link.append(TextNode(content: content))
        return (link, tokens.index(after: i))
      }
    }

    return (nil, startIndex)
  }
}
