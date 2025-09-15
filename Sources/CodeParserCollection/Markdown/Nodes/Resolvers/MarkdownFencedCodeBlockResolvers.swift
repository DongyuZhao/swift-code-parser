import CodeParserCore
import Foundation

// MARK: - Fenced Code Block Resolvers

public class MarkdownFencedCodeBlockCreationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    // Do not start a fenced code block when already inside one
    guard context.current.element != .codeBlock else { return false }
    let tokens = context.tokens
    var i = 0
    var indent = 0
    if i < tokens.count, tokens[i].element == .whitespace {
      indent = tokens[i].text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if indent > 3 { return false }
      i += 1
    }
    guard i < tokens.count else { return false }
    if tokens[i].element == .backslash { return false }
    let fenceElem = tokens[i].element
    guard fenceElem == .backtick || fenceElem == .tilde else { return false }
    var fenceCount = 0
    while i < tokens.count, tokens[i].element == fenceElem {
      fenceCount += 1
      i += 1
    }
    guard fenceCount >= 3 else { return false }
    var infoTokens: [any CodeToken<MarkdownTokenElement>] = []
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .newline || t.element == .eof { break }
      infoTokens.append(t)
      i += 1
    }
    if fenceElem == .backtick {
      for t in infoTokens where t.element == .backtick { return false }
    }
    let info = infoTokens.map { $0.text }.joined()
    let lang = info.split { $0 == " " || $0 == "\t" }.first.map(String.init)
    guard let parent = context.current as? MarkdownNodeBase else { return false }
    let code = CodeBlockNode(source: "", language: lang?.isEmpty == false ? lang : nil)
    code.indent = indent
    if let item = ancestorListItem(from: parent) {
      code.indent += item.contentIndent
    }
    code.fenceChar = (fenceElem == .backtick ? "`" : "~").first
    code.fenceCount = fenceCount
    parent.append(code)
    context.current = code
    context.tokens = []
    return true
  }
}

private func ancestorListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
  var cur = node as? MarkdownNodeBase
  while let c = cur {
    if let item = c as? ListItemNode { return item }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}

public class MarkdownFencedCodeBlockContinuationResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let code = context.current as? CodeBlockNode, let fenceChar = code.fenceChar else { return false }
    let tokens = context.tokens
    if tokens.count == 1, tokens.first?.element == .eof {
      while code.source.hasSuffix("\n") { code.source.removeLast() }
      if let parent = code.parent { context.current = parent }
      return false
    }
    var i = 0
    var indent = 0
    if i < tokens.count, tokens[i].element == .whitespace {
      indent = tokens[i].text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      if indent > 3 { return true }
      i += 1
    }
    let expectedElem: MarkdownTokenElement = (fenceChar == "`" ? .backtick : .tilde)
    if i < tokens.count, tokens[i].element == expectedElem {
      var run = 0
      while i < tokens.count, tokens[i].element == expectedElem {
        run += 1
        i += 1
      }
      if run >= code.fenceCount {
        var j = i
        var onlySpace = true
        while j < tokens.count {
          let t = tokens[j]
          if t.element == .newline || t.element == .eof { break }
          if t.element != .whitespace { onlySpace = false; break }
          j += 1
        }
        if onlySpace {
          if let parent = code.parent { context.current = parent }
          context.tokens = []
          return true
        }
      }
    }
    return true
  }
}

public class MarkdownFencedCodeBlockConstructionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard let code = context.current as? CodeBlockNode, code.fenceChar != nil else { return false }
    let tokens = context.tokens
    var i = 0
    var line = ""
    var strip = code.indent
    if i < tokens.count, tokens[i].element == .whitespace {
      var rem = strip
      for ch in tokens[i].text {
        if ch == " " && rem > 0 { rem -= 1; continue }
        line.append(ch)
      }
      i += 1
    }
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .newline {
        line.append("\n")
      } else if t.element != .eof {
        line.append(t.text)
      }
      i += 1
    }
    code.source.append(line)
    return true
  }
}
