import CodeParserCore
import Foundation

/// Build bare URLs and emails (www., http(s)://, ftp://, local@domain)
struct MarkdownInlineURLBuilder: CodeNodeBuilder {
  typealias Node = MarkdownNodeElement
  typealias Token = MarkdownTokenElement

  func build(from context: inout CodeConstructContext<Node, Token>) -> Bool {
    let tokens = context.tokens
    var i = context.consuming
    guard i < tokens.count else { return false }
    // Accept characters start for URL/email sequence
    guard tokens[i].element == .characters else { return false }

    let slice = tokens[i..<tokens.count]
    let (node, nextIdxInSlice) = parseBareAutolink(slice, startIndex: slice.startIndex)
    guard let n = node else { return false }
    let advanced = slice.distance(from: slice.startIndex, to: nextIdxInSlice)
    context.current.append(n)
    context.consuming = i + advanced
    return true
  }

  // MARK: - Helpers (scoped to this builder)
  private func isValidURLDomain(_ domain: String) -> Bool {
    if domain.isEmpty { return false }
    let parts = domain.split(separator: "/")
    guard let firstPart = parts.first else { return false }
    let domainParts = firstPart.split(separator: ".")
    if domainParts.count < 2 { return false }
    for part in domainParts {
      if part.isEmpty { return false }
      for char in part { if !char.isLetter && !char.isNumber && char != "-" { return false } }
    }
    return true
  }

  private func trimHTMLEntities(
    _ content: String,
    _ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    _ endIndex: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index
  ) -> (String, ArraySlice<any CodeToken<MarkdownTokenElement>>.Index) {
    if let ampIndex = content.lastIndex(of: "&") {
      let afterAmp = content[content.index(after: ampIndex)...]
      if !afterAmp.isEmpty && afterAmp.allSatisfy({ $0.isLetter || $0.isNumber }) {
        if endIndex < tokens.endIndex && tokens[endIndex].element == .punctuation && tokens[endIndex].text == ";" {
          let truncatedContent = String(content[..<ampIndex])
          var currentIndex = tokens.startIndex
          var builtContent = ""
          while currentIndex < endIndex {
            let nextContent = builtContent + tokens[currentIndex].text
            if nextContent.count > truncatedContent.count { return (truncatedContent, currentIndex) }
            if nextContent == truncatedContent { return (truncatedContent, tokens.index(after: currentIndex)) }
            builtContent = nextContent
            currentIndex = tokens.index(after: currentIndex)
          }
          return (truncatedContent, endIndex)
        }
      }
      if afterAmp.range(of: "^[a-zA-Z0-9]+;", options: .regularExpression) != nil {
        let truncatedContent = String(content[..<ampIndex])
        var currentIndex = tokens.startIndex
        var builtContent = ""
        while currentIndex < endIndex {
          let nextContent = builtContent + tokens[currentIndex].text
          if nextContent.count > truncatedContent.count { return (truncatedContent, currentIndex) }
          if nextContent == truncatedContent { return (truncatedContent, tokens.index(after: currentIndex)) }
          builtContent = nextContent
          currentIndex = tokens.index(after: currentIndex)
        }
        return (truncatedContent, endIndex)
      }
    }
    return (content, endIndex)
  }

  private func balanceParentheses(
    _ content: String,
    _ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    _ endIndex: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index
  ) -> (String, ArraySlice<any CodeToken<MarkdownTokenElement>>.Index) {
    var openCount = 0, closeCount = 0
    for ch in content { if ch == "(" { openCount += 1 } else if ch == ")" { closeCount += 1 } }
    if closeCount > openCount {
      let excess = closeCount - openCount
      var adjustedContent = content
      var adjustedEnd = endIndex
      var removed = 0
      while removed < excess && !adjustedContent.isEmpty && adjustedContent.last == ")" {
        adjustedContent.removeLast()
        adjustedEnd = tokens.index(before: adjustedEnd)
        removed += 1
      }
      return (adjustedContent, adjustedEnd)
    }
    return (content, endIndex)
  }

  private func parseBareAutolink(
    _ tokens: ArraySlice<any CodeToken<MarkdownTokenElement>>,
    startIndex: ArraySlice<any CodeToken<MarkdownTokenElement>>.Index
  ) -> (MarkdownNodeBase?, ArraySlice<any CodeToken<MarkdownTokenElement>>.Index) {
    guard startIndex < tokens.endIndex else { return (nil, startIndex) }
    let startToken = tokens[startIndex]
    guard startToken.element == .characters else { return (nil, startIndex) }

    var i = startIndex
    var urlTokens: [any CodeToken<MarkdownTokenElement>] = []
    while i < tokens.endIndex {
      let token = tokens[i]
      if token.element == .characters { urlTokens.append(token) }
      else if token.element == .punctuation {
        if ".:/?&=#+-%_@()".contains(token.text) { urlTokens.append(token) }
        else if token.text == " " { break }
        else { break }
      } else if token.element == .whitespaces { break }
      else { break }
      i = tokens.index(after: i)
    }
    if urlTokens.isEmpty { return (nil, startIndex) }

    let content = tokensToString(urlTokens[urlTokens.startIndex..<urlTokens.endIndex])

    if let atIndex = content.firstIndex(of: "@") {
      let local = String(content[..<atIndex])
      let domain = String(content[content.index(after: atIndex)...])
      if isEmailLocalValid(local) && isEmailDomainValid(domain) {
        var actualContent = content
        var actualEnd = i
        while !actualContent.isEmpty && ",.;:!?".contains(actualContent.last!) {
          actualContent.removeLast()
          actualEnd = tokens.index(before: actualEnd)
        }
        let link = LinkNode(url: "mailto:" + actualContent, title: "")
        link.append(TextNode(content: actualContent))
        return (link, actualEnd)
      }
    }

    if content.lowercased().hasPrefix("www.") && content.contains(".") {
      let (balancedContent, balancedEnd) = balanceParentheses(content, tokens, i)
      let (entityContent, entityEnd) = trimHTMLEntities(balancedContent, tokens, balancedEnd)
      var actualContent = entityContent
      var actualEnd = entityEnd
      while !actualContent.isEmpty && ",.;:!?".contains(actualContent.last!) {
        actualContent.removeLast()
        actualEnd = tokens.index(before: actualEnd)
      }
      let domain = String(actualContent.dropFirst(4))
      if isValidURLDomain(domain) {
        let link = LinkNode(url: "http://" + actualContent, title: "")
        link.append(TextNode(content: actualContent))
        return (link, actualEnd)
      }
    }

    if content.hasPrefix("http://") || content.hasPrefix("https://") || content.hasPrefix("ftp://") {
      let (balancedContent, balancedEnd) = balanceParentheses(content, tokens, i)
      let (entityContent, entityEnd) = trimHTMLEntities(balancedContent, tokens, balancedEnd)
      var actualContent = entityContent
      var actualEnd = entityEnd
      while !actualContent.isEmpty && ",.;:!?".contains(actualContent.last!) {
        actualContent.removeLast()
        actualEnd = tokens.index(before: actualEnd)
      }
      let link = LinkNode(url: actualContent, title: "")
      link.append(TextNode(content: actualContent))
      return (link, actualEnd)
    }

    return (nil, startIndex)
  }

  private func isEmailLocalValid(_ local: String) -> Bool {
    if local.isEmpty { return false }
    for char in local { if !char.isLetter && !char.isNumber && char != "." && char != "-" && char != "_" && char != "+" { return false } }
    return true
  }
  private func isEmailDomainValid(_ domain: String) -> Bool {
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
}
