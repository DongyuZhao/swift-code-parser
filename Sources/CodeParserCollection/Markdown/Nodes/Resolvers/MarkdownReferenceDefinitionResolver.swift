import CodeParserCore
import Foundation

public class MarkdownReferenceDefinitionResolver: MarkdownBlockResolver {
  public init() {}
  public func resolve(from context: inout MarkdownBlockContext) -> Bool {
    guard context.current.element != .codeBlock else { return false }
    let tokens = context.tokens
    var i = 0
    var indent = 0
    if i < tokens.count, tokens[i].element == .whitespaces {
      indent = tokens[i].text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
      i += 1
    }
    if let item = nearestListItem(from: context.current) {
      if indent > item.contentIndent + 3 { return false }
    } else if indent > 3 { return false }
    guard i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "[" else { return false }
    i += 1
    var label = ""
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .punctuation, t.text == "]" { break }
      label.append(t.text)
      i += 1
    }
    guard i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == "]" else { return false }
    i += 1
    guard i < tokens.count, tokens[i].element == .punctuation, tokens[i].text == ":" else { return false }
    i += 1
    while i < tokens.count, tokens[i].element == .whitespaces { i += 1 }
    var dest = ""
    while i < tokens.count {
      let t = tokens[i]
      if t.element == .newline || t.element == .eof { break }
      dest.append(t.text)
      i += 1
    }
    guard !dest.isEmpty else { return false }
    let ref = ReferenceNode(identifier: label, url: dest, title: "")
    if let item = nearestListItem(from: context.current), let list = item.parent as? MarkdownNodeBase, let parent = list.parent as? MarkdownNodeBase {
      parent.append(ref)
      context.current = list
      context.tokens = []
      return true
    } else if let parent = context.current as? MarkdownNodeBase {
      parent.append(ref)
      context.tokens = []
      return true
    }
    return false
  }
}

private func nearestListItem(from node: CodeNode<MarkdownNodeElement>) -> ListItemNode? {
  var cur = node as? MarkdownNodeBase
  while let c = cur {
    if let item = c as? ListItemNode { return item }
    cur = c.parent as? MarkdownNodeBase
  }
  return nil
}
