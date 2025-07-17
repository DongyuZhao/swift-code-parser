import Foundation

/// 处理链接的Consumer
public class MarkdownLinkConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .leftBracket {
            return consumeLink(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func consumeLink(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // 创建部分链接节点用于处理前缀歧义
        let partialLinkNode = CodeNode(type: MarkdownElement.partialLink, value: "", range: token.range)
        
        context.tokens.removeFirst() // 移除[
        
        var linkText = ""
        var foundClosingBracket = false
        
        // 收集链接文本直到找到]
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
            // 没找到闭合括号，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
        
        // 检查是否有(url)部分
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftParen {
            return consumeInlineLink(context: &context, linkText: linkText, startToken: token, partialNode: partialLinkNode)
        }
        
        // 检查是否是引用链接[text][ref]或[text][]
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftBracket {
            return consumeReferenceLink(context: &context, linkText: linkText, startToken: token, partialNode: partialLinkNode)
        }
        
        // 可能是简化引用链接[text]，将其作为部分节点处理
        partialLinkNode.value = linkText
        context.currentNode.addChild(partialLinkNode)
        return true
    }
    
    private func consumeInlineLink(context: inout CodeContext, linkText: String, startToken: MarkdownToken, partialNode: CodeNode) -> Bool {
        context.tokens.removeFirst() // 移除(
        
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
                // 开始标题
                inTitle = true
                titleQuote = char == "(" ? ")" : char!
                context.tokens.removeFirst()
                continue
            }
            
            if inTitle && char == titleQuote {
                // 结束标题
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
            
            // 添加URL和标题作为属性或子节点
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
            // 没找到闭合括号，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText + "](" + url + title, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
    
    private func consumeReferenceLink(context: inout CodeContext, linkText: String, startToken: MarkdownToken, partialNode: CodeNode) -> Bool {
        context.tokens.removeFirst() // 移除第二个[
        
        var refLabel = ""
        var foundClosingBracket = false
        
        // 收集引用标签
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
            
            // 如果引用标签为空，使用链接文本作为引用
            let actualRef = refLabel.isEmpty ? linkText : refLabel
            let refNode = CodeNode(type: MarkdownElement.text, value: actualRef)
            linkNode.addChild(refNode)
            
            context.currentNode.addChild(linkNode)
            return true
        } else {
            // 没找到闭合括号，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "[" + linkText + "][" + refLabel, range: startToken.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// 处理图片的Consumer
public class MarkdownImageConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .exclamation {
            // 检查下一个token是否是[
            if context.tokens.count > 1,
               let nextToken = context.tokens[1] as? MarkdownToken,
               nextToken.kind == .leftBracket {
                return consumeImage(context: &context, token: mdToken)
            }
        }
        
        return false
    }
    
    private func consumeImage(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // 移除!
        context.tokens.removeFirst() // 移除[
        
        var altText = ""
        var foundClosingBracket = false
        
        // 收集alt文本直到找到]
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
            // 没找到闭合括号，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "![" + altText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
        
        // 检查是否有(url)部分
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftParen {
            return consumeInlineImage(context: &context, altText: altText, startToken: token)
        }
        
        // 检查是否是引用图片![alt][ref]或![alt][]
        if let nextToken = context.tokens.first as? MarkdownToken,
           nextToken.kind == .leftBracket {
            return consumeReferenceImage(context: &context, altText: altText, startToken: token)
        }
        
        // 简化引用图片![alt]，创建部分节点
        let partialImageNode = CodeNode(type: MarkdownElement.partialImage, value: altText, range: token.range)
        context.currentNode.addChild(partialImageNode)
        return true
    }
    
    private func consumeInlineImage(context: inout CodeContext, altText: String, startToken: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // 移除(
        
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
            
            // 添加URL和标题
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
        context.tokens.removeFirst() // 移除第二个[
        
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

/// 处理自动链接的Consumer
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
        context.tokens.removeFirst() // 移除<
        
        var linkContent = ""
        var foundClosing = false
        var isValidAutolink = false
        
        // 收集内容直到>
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .rightAngle {
                context.tokens.removeFirst()
                foundClosing = true
                break
            }
            
            // 检查是否包含空白（自动链接不能包含空白）
            if currentToken.kind == .whitespace {
                break
            }
            
            linkContent += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosing {
            // 检查是否是有效的URL或email
            if isValidURL(linkContent) || isValidEmail(linkContent) {
                isValidAutolink = true
            }
        }
        
        if isValidAutolink {
            let autolinkNode = CodeNode(type: MarkdownElement.autolink, value: linkContent, range: token.range)
            context.currentNode.addChild(autolinkNode)
            return true
        } else {
            // 不是有效的自动链接，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "<" + linkContent + (foundClosing ? ">" : ""), range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
    
    private func isValidURL(_ string: String) -> Bool {
        // 简化的URL验证
        let urlPrefixes = ["http://", "https://", "ftp://", "ftps://"]
        return urlPrefixes.contains { string.lowercased().hasPrefix($0) }
    }
    
    private func isValidEmail(_ string: String) -> Bool {
        // 简化的email验证
        return string.contains("@") && string.contains(".") && !string.hasPrefix("@") && !string.hasSuffix("@")
    }
}

/// 处理HTML内联元素的Consumer
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

/// 处理换行的Consumer
public class MarkdownLineBreakConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .newline {
            context.tokens.removeFirst()
            
            // 检查是否是硬换行（前面有两个空格）
            var hasHardBreak = false
            if context.currentNode.children.count > 0 {
                let lastChild = context.currentNode.children.last!
                if lastChild.value.hasSuffix("  ") {
                    hasHardBreak = true
                    // 移除尾部空格
                    lastChild.value = String(lastChild.value.dropLast(2))
                }
            }
            
            if hasHardBreak {
                // 硬换行：创建lineBreak节点
                let breakNode = CodeNode(type: MarkdownElement.lineBreak, value: "\n", range: mdToken.range)
                context.currentNode.addChild(breakNode)
                return true
            } else {
                // 软换行：检查下一行是否为空或开始新的块级元素
                if let nextToken = context.tokens.first as? MarkdownToken {
                    if nextToken.kind == .newline {
                        // 空行，不处理（让其他consumer处理）
                        return false
                    } else if isBlockElementStart(nextToken) {
                        // 下一行是块级元素，不处理
                        return false
                    } else {
                        // 段落内的软换行，不创建节点，让段落consumer处理
                        return false
                    }
                } else {
                    // 文件结尾，不处理
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
