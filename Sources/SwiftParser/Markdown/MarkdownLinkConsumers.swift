import Foundation

/// Consumer for handling links
public class MarkdownLinkConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .leftBracket {
            // Check if it's a footnote or citation pattern, and skip if so
            if context.tokens.count >= 2 {
                if let nextToken = context.tokens[1] as? MarkdownToken {
                    if nextToken.kind == .caret || nextToken.kind == .atSign {
                        return false // Let the footnote or citation consumer handle it
                    }
                }
            }
            return consumeLink(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeLink(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // Create a partial link node to handle prefix ambiguity
        let partialLinkNode = CodeNode(type: MarkdownElement.partialLink, value: "", range: token.range)
        
        context.tokens.removeFirst() // Remove [
        
        var linkText = ""
        var foundClosingBracket = false
        
        // Collect link text until a ] is found
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightBracket {
                context.tokens.removeFirst()
                foundClosingBracket = true
                break
            }
            
            linkText += currentToken.text
            context.tokens.removeFirst()
        }
        
        if !foundClosingBracket {
            // No closing bracket found, treat as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
        
        // Check for a (url) part
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftParen {
            return consumeInlineLink(context: &context, linkText: linkText, startToken: token, partialNode: partialLinkNode)
        }
        
        // Check for a reference link [text][ref] or [text][]
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftBracket {
            return consumeReferenceLink(context: &context, linkText: linkText, startToken: token, partialNode: partialLinkNode)
        }
        
        // Could be a simplified reference link [text], treat it as a partial node
        partialLinkNode.value = linkText
        context.currentNode.addChild(partialLinkNode)
        return true
    }
    
    private func consumeInlineLink(context: inout CodeContext, linkText: String, startToken: MarkdownToken, partialNode: CodeNode) -> Bool {
        context.tokens.removeFirst() // Remove (
        
        var url = ""
        var title = ""
        var foundClosingParen = false
        var inTitle = false
        var titleQuote: Character = "\""
        
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightParen2 && !inTitle {
                context.tokens.removeFirst()
                foundClosingParen = true
                break
            }
            
            let char = currentToken.text.first
            
            if !inTitle && (char == "\"" || char == "'" || char == "(") {
                // Start of title
                inTitle = true
                titleQuote = char == "(" ? ")" : char!
                context.tokens.removeFirst()
                continue
            }
            
            if inTitle && char == titleQuote {
                // End of title
                inTitle = false
                context.tokens.removeFirst()
                continue
            }
            
            if inTitle {
                title += currentToken.text
            } else if currentToken.kind != .whitespace || !url.isEmpty {
                url += currentToken.text
            }
            
            context.tokens.removeFirst()
        }
        
        if foundClosingParen {
            let linkNode = CodeNode(type: MarkdownElement.link, value: linkText, range: startToken.range)
            
            // Add URL and title as attributes or child nodes
            if !url.isEmpty {
                let urlNode = CodeNode(type: MarkdownElement.text, value: url.trimmingCharacters(in: .whitespaces))
                linkNode.addChild(urlNode)
            }
            if !title.isEmpty {
                let titleNode = CodeNode(type: MarkdownElement.text, value: title)
                linkNode.addChild(titleNode)
            }
            
            context.currentNode.addChild(linkNode)
            return true
        } else {
            // No closing parenthesis found, treat as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText + "](" + url + title, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
    
    private func consumeReferenceLink(context: inout CodeContext, linkText: String, startToken: MarkdownToken, partialNode: CodeNode) -> Bool {
        context.tokens.removeFirst() // Remove the second [
        
        var refLabel = ""
        var foundClosingBracket = false
        
        // Collect the reference label
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightBracket {
                context.tokens.removeFirst()
                foundClosingBracket = true
                break
            }
            
            refLabel += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosingBracket {
            let linkNode = CodeNode(type: MarkdownElement.link, value: linkText, range: startToken.range)
            
            // If the reference label is empty, use the link text as the reference
            let actualRef = refLabel.isEmpty ? linkText : refLabel
            let refNode = CodeNode(type: MarkdownElement.text, value: actualRef)
            linkNode.addChild(refNode)
            
            context.currentNode.addChild(linkNode)
            return true
        } else {
            // No closing bracket found, treat as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText + "][" + refLabel, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// Consumer for handling images
public class MarkdownImageConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .exclamation {
            // Check if the next token is [
            if context.tokens.count > 1,
               let nextToken = context.tokens[1] as? MarkdownToken,
               nextToken.kind == .leftBracket {
                return consumeImage(context: &context, token: mdToken)
            }
        }
        
        return false
    }
    
    private func consumeImage(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove !
        context.tokens.removeFirst() // Remove [
        
        var altText = ""
        var foundClosingBracket = false
        
        // Collect alt text until ] is found
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightBracket {
                context.tokens.removeFirst()
                foundClosingBracket = true
                break
            }
            
            altText += currentToken.text
            context.tokens.removeFirst()
        }
        
        if !foundClosingBracket {
            // No closing bracket found, treat as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "![" + altText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
        
        // Check for a (url) part
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftParen {
            return consumeInlineImage(context: &context, altText: altText, startToken: token)
        }
        
        // Check for a reference image ![alt][ref] or ![alt][]
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftBracket {
            return consumeReferenceImage(context: &context, altText: altText, startToken: token)
        }
        
        // Simplified reference image ![alt], create a partial node
        let partialImageNode = CodeNode(type: MarkdownElement.partialImage, value: altText, range: token.range)
        context.currentNode.addChild(partialImageNode)
        return true
    }
    
    private func consumeInlineImage(context: inout CodeContext, altText: String, startToken: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove (
        
        var url = ""
        var title = ""
        var foundClosingParen = false
        var inTitle = false
        var titleQuote: Character = "\""
        
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightParen2 && !inTitle {
                context.tokens.removeFirst()
                foundClosingParen = true
                break
            }
            
            let char = currentToken.text.first
            
            if !inTitle && (char == "\"" || char == "'" || char == "(") {
                inTitle = true
                titleQuote = char == "(" ? ")" : char!
                context.tokens.removeFirst()
                continue
            }
            
            if inTitle && char == titleQuote {
                inTitle = false
                context.tokens.removeFirst()
                continue
            }
            
            if inTitle {
                title += currentToken.text
            } else if currentToken.kind != .whitespace || !url.isEmpty {
                url += currentToken.text
            }
            
            context.tokens.removeFirst()
        }
        
        if foundClosingParen {
            let imageNode = CodeNode(type: MarkdownElement.image, value: altText, range: startToken.range)
            
            // Add URL and title
            if !url.isEmpty {
                let urlNode = CodeNode(type: MarkdownElement.text, value: url.trimmingCharacters(in: .whitespaces))
                imageNode.addChild(urlNode)
            }
            if !title.isEmpty {
                let titleNode = CodeNode(type: MarkdownElement.text, value: title)
                imageNode.addChild(titleNode)
            }
            
            context.currentNode.addChild(imageNode)
            return true
        } else {
            let textNode = CodeNode(type: MarkdownElement.text, value: "![" + altText + "](" + url + title, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
    
    private func consumeReferenceImage(context: inout CodeContext, altText: String, startToken: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove the second [
        
        var refLabel = ""
        var foundClosingBracket = false
        
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightBracket {
                context.tokens.removeFirst()
                foundClosingBracket = true
                break
            }
            
            refLabel += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosingBracket {
            let imageNode = CodeNode(type: MarkdownElement.image, value: altText, range: startToken.range)
            
            let actualRef = refLabel.isEmpty ? altText : refLabel
            let refNode = CodeNode(type: MarkdownElement.text, value: actualRef)
            imageNode.addChild(refNode)
            
            context.currentNode.addChild(imageNode)
            return true
        } else {
            let textNode = CodeNode(type: MarkdownElement.text, value: "![" + altText + "][" + refLabel, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// Consumer for handling autolinks
public class MarkdownAutolinkConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .leftAngle {
            return consumeAutolink(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeAutolink(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove <
        
        var linkContent = ""
        var foundClosing = false
        var isValidAutolink = false
        
        // Collect content until >
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightAngle {
                context.tokens.removeFirst()
                foundClosing = true
                break
            }
            
            // Check for whitespace (autolinks cannot contain whitespace)
            if currentToken.kind == .whitespace {
                break
            }
            
            linkContent += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosing {
            // Check if it's a valid URL or email
            if isValidURL(linkContent) || isValidEmail(linkContent) {
                isValidAutolink = true
            }
        }
        
        if isValidAutolink {
            let autolinkNode = CodeNode(type: MarkdownElement.autolink, value: linkContent, range: token.range)
            context.currentNode.addChild(autolinkNode)
            return true
        } else {
            // Not a valid autolink, treat as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "<" + linkContent + (foundClosing ? ">" : ""), range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        // Simplified URL validation
        let urlPrefixes = ["http://", "https://", "ftp://", "ftps://"]
        return urlPrefixes.contains { string.lowercased().hasPrefix($0) }
    }
    
    private func isValidEmail(_ string: String) -> Bool {
        // Simplified email validation
        return string.contains("@") && string.contains(".") && !string.hasPrefix("@") && !string.hasSuffix("@")
    }
}

/// Consumer for handling inline HTML elements
public class MarkdownHTMLInlineConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .htmlTag {
            let htmlNode = CodeNode(type: MarkdownElement.htmlInline, value: mdToken.text, range: mdToken.range)
            context.currentNode.addChild(htmlNode)
            context.tokens.removeFirst()
            return true
        }
        
        return false
    }
}

/// Consumer for handling line breaks
public class MarkdownLineBreakConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .newline {
            context.tokens.removeFirst()
            
            // Check for a hard line break (preceded by two spaces)
            var hasHardBreak = false
            if context.currentNode.children.count > 0 {
                let lastChild = context.currentNode.children.last!
                if lastChild.value.hasSuffix("  ") {
                    hasHardBreak = true
                    // Remove trailing spaces
                    lastChild.value = String(lastChild.value.dropLast(2))
                }
            }
            
            if hasHardBreak {
                // Hard line break: create a lineBreak node
                let breakNode = CodeNode(type: MarkdownElement.lineBreak, value: "\n", range: mdToken.range)
                context.currentNode.addChild(breakNode)
                return true
            } else {
                // Soft line break: check if the next line is empty or starts a new block-level element
                if let nextToken = context.tokens.first as? MarkdownToken {
                    if nextToken.kind == .newline {
                        // Blank line, do not handle (let other consumers handle it)
                        return false
                    } else if isBlockElementStart(nextToken) {
                        // Next line is a block-level element, do not handle
                        return false
                    } else {
                        // Soft line break within a paragraph, do not create a node, let the paragraph consumer handle it
                        return false
                    }
                } else {
                    // End of file, do not handle
                    return false
                }
            }
        }
        
        return false
    }
    
    private func isBlockElementStart(_ token: MarkdownToken) -> Bool {
        return (token.kind == .hash && token.isAtLineStart) ||
               (token.kind == .greaterThan && token.isAtLineStart) ||
               (token.kind == .backtick && token.isAtLineStart) ||
               ((token.kind == .asterisk || token.kind == .dash || token.kind == .plus) && token.isAtLineStart) ||
               (token.kind == .digit && token.isAtLineStart) ||
               (token.kind == .horizontalRule && token.isAtLineStart)
    }
}
