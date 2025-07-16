import Foundation

extension MarkdownLanguage {
    public class BlockTexFormulaBuilder: CodeElementBuilder {
        public init() {}
        
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = context.tokens[context.index] as? Token else { return false }
            
            // Check for $$ at the beginning of a line
            if case .dollar = tok {
                // Check if there's another $ right after
                if context.index + 1 < context.tokens.count,
                   let nextTok = context.tokens[context.index + 1] as? Token,
                   case .dollar = nextTok {
                    return true
                }
            }
            return false
        }
        
        public func build(context: inout CodeContext) {
            let startFirstDollar = (context.tokens[context.index] as? Token)?.range
            let startSecondDollar = (context.tokens[context.index + 1] as? Token)?.range
            context.index += 2 // Skip opening $$
            
            var endFirstDollar: Range<String.Index>? = nil
            var foundClosing = false
            
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .dollar = tok {
                        // Check if this is $$
                        if context.index + 1 < context.tokens.count,
                           let nextTok = context.tokens[context.index + 1] as? Token,
                           case .dollar = nextTok {
                            endFirstDollar = tok.range
                            context.index += 2 // Skip closing $$
                            foundClosing = true
                            break
                        } else {
                            context.index += 1
                        }
                    } else {
                        context.index += 1
                    }
                } else {
                    context.index += 1
                }
            }
            
            if foundClosing, 
               let _ = startFirstDollar, 
               let startSecond = startSecondDollar,
               let endFirst = endFirstDollar {
                // Extract formula content using original input string
                let formulaStart = startSecond.upperBound
                let formulaEnd = endFirst.lowerBound
                let formulaText = String(context.input[formulaStart..<formulaEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                let node = MarkdownBlockTexFormulaNode(formula: formulaText)
                context.currentNode.addChild(node)
            } else {
                // If we reach here, no closing $$ was found, treat as regular text
                let textNode = MarkdownTextNode(value: "$$")
                context.currentNode.addChild(textNode)
            }
        }
    }
}
