import Foundation

extension MarkdownLanguage {
    public class EntityBuilder: CodeElementBuilder {
        public init() {}
        public func accept(context: CodeContext, token: any CodeToken) -> Bool {
            guard let tok = token as? Token else { return false }
            if case .ampersand = tok { return true }
            return false
        }
        public func build(context: inout CodeContext) {
            context.index += 1
            var text = ""
            while context.index < context.tokens.count {
                if let tok = context.tokens[context.index] as? Token {
                    if case .semicolon = tok { context.index += 1; break }
                    else { text += tok.text; context.index += 1 }
                } else { context.index += 1 }
            }
            let decoded = decode(text)
            context.currentNode.addChild(MarkdownEntityNode(value: decoded))
        }

        private func decode(_ entity: String) -> String {
            switch entity {
            case "amp": return "&"
            case "lt": return "<"
            case "gt": return ">"
            case "quot": return "\""
            case "apos": return "'"
            default:
                if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                    let hex = entity.dropFirst(2)
                    if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) {
                        return String(Character(scalar))
                    }
                } else if entity.hasPrefix("#") {
                    let num = entity.dropFirst()
                    if let value = UInt32(num), let scalar = UnicodeScalar(value) {
                        return String(Character(scalar))
                    }
                }
                return "&" + entity + ";"
            }
        }
    }

}
