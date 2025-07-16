import Foundation

extension MarkdownLanguage {
    public class UnorderedListBuilder: CodeElementBuilder {
        public init() {}

        private func lineIndent(before idx: Int, in context: CodeContext) -> Int? {
            if idx == 0 { return 0 }
            var i = idx - 1
            var count = 0
            while i >= 0 {
                guard let tok = context.tokens[i] as? Token else { return nil }
                switch tok {
                case .newline:
                    return count
                case .text(let s, _) where s.allSatisfy({ $0 == " " }):
                    count += s.count
                    i -= 1
                default:
                    return nil
                }
            }
            return count
        }

        private func isBullet(_ tok: Token) -> Bool {
            switch tok {
            case .dash, .star, .plus: return true
            default: return false
            }
        }

        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token, isBullet(tok) else { return false }
            guard context.index + 1 < context.tokens.count,
                  let next = context.tokens[context.index + 1] as? Token,
                  case .text(let s, _) = next, s.first?.isWhitespace == true else {
                return false
            }
            if let ind = lineIndent(before: context.index, in: context) { return ind >= 0 } else { return false }
        }

        public func build(context: inout CodeContext) {
            func parseList(_ indent: Int, _ depth: Int) -> CodeNode {
                let list = MarkdownUnorderedListNode(value: "", level: depth)
                var isLoose = false
                while context.index < context.tokens.count {
                    guard let bullet = context.tokens[context.index] as? Token, isBullet(bullet), lineIndent(before: context.index, in: context) == indent else { break }
                    let (node, loose) = parseItem(indent, depth)
                    if loose { isLoose = true }
                    list.addChild(node)
                }
                list.value = isLoose ? "loose" : "tight"
                return list
            }

            func parseItem(_ indent: Int, _ depth: Int) -> (CodeNode, Bool) {
                var loose = false
                // skip bullet and following whitespace
                context.index += 1
                if context.index < context.tokens.count,
                   let t = context.tokens[context.index] as? Token,
                   case .text(let s, _) = t, s.first?.isWhitespace == true {
                    context.index += 1
                }

                let node = MarkdownListItemNode(value: "")
                var text = ""
                itemLoop: while context.index < context.tokens.count {
                    guard let tok = context.tokens[context.index] as? Token else { context.index += 1; continue }
                    switch tok {
                    case .newline:
                        context.index += 1
                        // Check for blank line
                        if context.index < context.tokens.count, let nl = context.tokens[context.index] as? Token, case .newline = nl {
                            loose = true
                            context.index += 1
                        }
                        let start = context.index
                        var spaces = 0
                        if start < context.tokens.count, let sTok = context.tokens[start] as? Token, case .text(let s, _) = sTok, s.allSatisfy({ $0 == " " }) {
                            spaces = s.count
                            context.index += 1
                        }
                        if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, isBullet(next), spaces > indent {
                            let sub = parseList(spaces, depth + 1)
                            node.addChild(sub)
                            if context.index < context.tokens.count, let nextTok = context.tokens[context.index] as? Token, isBullet(nextTok), (lineIndent(before: context.index, in: context) ?? 0) <= indent {
                                break itemLoop
                            }
                        } else if context.index < context.tokens.count, let next = context.tokens[context.index] as? Token, isBullet(next), spaces == indent {
                            context.index = start
                            break itemLoop
                        } else if spaces > indent {
                            text += "\n"
                        } else if spaces < indent {
                            context.index = start
                            break itemLoop
                        } else {
                            text += "\n"
                        }
                    case .eof:
                        context.index += 1
                        break itemLoop
                    default:
                        text += tok.text
                        context.index += 1
                    }
                }
                node.value = text.trimmingCharacters(in: .whitespaces)
                return (node, loose)
            }

            if let ind = lineIndent(before: context.index, in: context) {
                let list = parseList(ind, 1)
                context.currentNode.addChild(list)
            }
        }
    }

}
