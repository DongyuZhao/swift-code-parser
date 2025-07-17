import Foundation

/// 处理换行和空行的Consumer
public class MarkdownNewlineConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .newline {
            context.tokens.removeFirst()
            
            // 检查是否是双换行（空行）
            if let nextToken = context.tokens.first as? MarkdownToken,
               nextToken.kind == .newline {
                // 这是空行，消费它但不创建节点
                context.tokens.removeFirst()
                return true
            }
            
            // 单个换行符，通常不需要创建节点
            return true
        }
        
        return false
    }
}

/// 处理普通文本的Consumer（fallback）
public class MarkdownTextConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 如果token没有被其他consumer处理，作为普通文本处理
        if mdToken.kind == .text || mdToken.kind == .whitespace {
            let textNode = CodeNode(type: MarkdownElement.text, value: mdToken.text, range: mdToken.range)
            context.currentNode.addChild(textNode)
            context.tokens.removeFirst()
            return true
        }
        
        return false
    }
}

/// 处理表格的Consumer（GFM扩展）
public class MarkdownTableConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检查是否可能是表格开始（包含|字符的行）
        if mdToken.kind == .pipe || (mdToken.kind == .text && mdToken.isAtLineStart) {
            return tryConsumeTable(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func tryConsumeTable(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // 先预览当前行是否包含管道符号
        var currentIndex = 0
        var hasPipe = false
        var lineTokens: [MarkdownToken] = []
        
        // 收集当前行的所有tokens
        while currentIndex < context.tokens.count {
            guard let currentToken = context.tokens[currentIndex] as? MarkdownToken else { break }
            
            if currentToken.kind == .newline || currentToken.kind == .eof {
                break
            }
            
            lineTokens.append(currentToken)
            if currentToken.kind == .pipe {
                hasPipe = true
            }
            currentIndex += 1
        }
        
        if !hasPipe {
            return false
        }
        
        // 检查下一行是否是分隔符行
        var separatorIndex = currentIndex + 1 // 跳过换行符
        var isSeparatorLine = false
        var separatorTokens: [MarkdownToken] = []
        
        while separatorIndex < context.tokens.count {
            guard let sepToken = context.tokens[separatorIndex] as? MarkdownToken else { break }
            
            if sepToken.kind == .newline || sepToken.kind == .eof {
                break
            }
            
            separatorTokens.append(sepToken)
            separatorIndex += 1
        }
        
        // 检查分隔符行是否符合表格格式
        isSeparatorLine = isValidTableSeparator(separatorTokens)
        
        if !isSeparatorLine {
            return false
        }
        
        // 开始构建表格
        return consumeTable(context: &context, firstRowTokens: lineTokens, separatorTokens: separatorTokens, startToken: token)
    }
    
    private func isValidTableSeparator(_ tokens: [MarkdownToken]) -> Bool {
        var hasRequiredChars = false
        
        for token in tokens {
            switch token.kind {
            case .pipe, .dash, .colon, .whitespace:
                if token.kind == .dash {
                    hasRequiredChars = true
                }
                continue
            default:
                return false
            }
        }
        
        return hasRequiredChars
    }
    
    private func consumeTable(context: inout CodeContext, firstRowTokens: [MarkdownToken], separatorTokens: [MarkdownToken], startToken: MarkdownToken) -> Bool {
        let tableNode = CodeNode(type: MarkdownElement.table, value: "", range: startToken.range)
        context.currentNode.addChild(tableNode)
        
        // 处理表头行
        let headerRow = parseTableRow(firstRowTokens)
        if let headerRowNode = headerRow {
            tableNode.addChild(headerRowNode)
        }
        
        // 移除已处理的tokens（第一行和分隔符行）
        for _ in 0..<(firstRowTokens.count + 1 + separatorTokens.count + 1) {
            if !context.tokens.isEmpty {
                context.tokens.removeFirst()
            }
        }
        
        // 继续处理表格数据行
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof {
                break
            }
            
            // 收集当前行
            var rowTokens: [MarkdownToken] = []
            var hasPipeInRow = false
            
            while let token = context.tokens.first as? MarkdownToken {
                if token.kind == .newline || token.kind == .eof {
                    context.tokens.removeFirst()
                    break
                }
                
                rowTokens.append(token)
                if token.kind == .pipe {
                    hasPipeInRow = true
                }
                context.tokens.removeFirst()
            }
            
            // 如果行不包含管道符，表格结束
            if !hasPipeInRow && !rowTokens.isEmpty {
                // 将tokens放回去
                let reversedTokens = Array(rowTokens.reversed())
                for token in reversedTokens {
                    context.tokens.insert(token, at: 0)
                }
                break
            }
            
            if hasPipeInRow {
                if let dataRow = parseTableRow(rowTokens) {
                    tableNode.addChild(dataRow)
                }
            } else if rowTokens.isEmpty {
                // 空行，表格结束
                break
            }
        }
        
        return true
    }
    
    private func parseTableRow(_ tokens: [MarkdownToken]) -> CodeNode? {
        let rowNode = CodeNode(type: MarkdownElement.tableRow, value: "")
        
        var cellContent = ""
        var inCell = false
        
        for token in tokens {
            if token.kind == .pipe {
                if inCell {
                    // 结束当前单元格
                    let cellNode = CodeNode(type: MarkdownElement.tableCell, value: cellContent.trimmingCharacters(in: .whitespaces))
                    rowNode.addChild(cellNode)
                    cellContent = ""
                }
                inCell = true
            } else {
                if inCell {
                    cellContent += token.text
                }
            }
        }
        
        // 处理最后一个单元格
        if inCell && !cellContent.isEmpty {
            let cellNode = CodeNode(type: MarkdownElement.tableCell, value: cellContent.trimmingCharacters(in: .whitespaces))
            rowNode.addChild(cellNode)
        }
        
        return rowNode.children.isEmpty ? nil : rowNode
    }
}

/// 处理删除线的Consumer（GFM扩展）
public class MarkdownStrikethroughConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检查是否是~~的开始
        if mdToken.kind == .text && mdToken.text == "~" {
            // 检查下一个token是否也是~
            if context.tokens.count > 1,
               let nextToken = context.tokens[1] as? MarkdownToken,
               nextToken.kind == .text && nextToken.text == "~" {
                return consumeStrikethrough(context: &context, token: mdToken)
            }
        }
        
        return false
    }
    
    private func consumeStrikethrough(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // 移除第一个~
        context.tokens.removeFirst() // 移除第二个~
        
        var strikethroughText = ""
        var foundClosing = false
        
        // 查找闭合的~~
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .text && currentToken.text == "~" {
                // 检查下一个token是否也是~
                if context.tokens.count > 1,
                   let nextToken = context.tokens[1] as? MarkdownToken,
                   nextToken.kind == .text && nextToken.text == "~" {
                    context.tokens.removeFirst() // 移除第一个~
                    context.tokens.removeFirst() // 移除第二个~
                    foundClosing = true
                    break
                }
            }
            
            strikethroughText += currentToken.text
            context.tokens.removeFirst()
        }
        
        if foundClosing && !strikethroughText.isEmpty {
            let strikeNode = CodeNode(type: MarkdownElement.strikethrough, value: strikethroughText, range: token.range)
            context.currentNode.addChild(strikeNode)
            return true
        } else {
            // 没找到闭合标记，作为普通文本处理
            let textNode = CodeNode(type: MarkdownElement.text, value: "~~" + strikethroughText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// 处理链接引用定义的Consumer
public class MarkdownLinkReferenceConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // 检查是否是行首的[开始的链接引用定义
        if mdToken.kind == .leftBracket && mdToken.isAtLineStart {
            return tryConsumeLinkReference(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func tryConsumeLinkReference(context: inout CodeContext, token: MarkdownToken) -> Bool {
        var tempTokens: [MarkdownToken] = []
        var currentIndex = 0
        
        // 收集当前行的tokens进行检查
        while currentIndex < context.tokens.count {
            guard let currentToken = context.tokens[currentIndex] as? MarkdownToken else { break }
            
            if currentToken.kind == .newline || currentToken.kind == .eof {
                break
            }
            
            tempTokens.append(currentToken)
            currentIndex += 1
        }
        
        // 检查是否符合链接引用定义格式: [label]: url "title"
        var labelEndIndex = -1
        var hasColon = false
        
        for (index, token) in tempTokens.enumerated() {
            if token.kind == .rightBracket && labelEndIndex == -1 {
                labelEndIndex = index
            } else if token.kind == .colon && labelEndIndex != -1 && index == labelEndIndex + 1 {
                hasColon = true
                break
            }
        }
        
        if !hasColon || labelEndIndex == -1 {
            return false
        }
        
        // 解析链接引用定义
        return consumeLinkReference(context: &context, tokens: tempTokens, startToken: token)
    }
    
    private func consumeLinkReference(context: inout CodeContext, tokens: [MarkdownToken], startToken: MarkdownToken) -> Bool {
        var label = ""
        var url = ""
        var title = ""
        
        var phase = 0 // 0: label, 1: url, 2: title
        var inQuotes = false
        var quoteChar: Character = "\""
        
        for token in tokens {
            switch phase {
            case 0: // 解析标签
                if token.kind == .rightBracket {
                    phase = 1
                } else if token.kind != .leftBracket {
                    label += token.text
                }
                
            case 1: // 解析URL
                if token.kind == .colon {
                    continue
                } else if token.kind == .whitespace && url.isEmpty {
                    continue
                } else if token.text.first == "\"" || token.text.first == "'" {
                    if url.isEmpty {
                        continue
                    }
                    phase = 2
                    inQuotes = true
                    quoteChar = token.text.first!
                } else if token.kind != .whitespace {
                    url += token.text
                } else if !url.isEmpty {
                    phase = 2
                }
                
            case 2: // 解析标题
                if inQuotes {
                    if token.text.last == quoteChar {
                        inQuotes = false
                    } else {
                        title += token.text
                    }
                } else {
                    title += token.text
                }
                
            default:
                break
            }
        }
        
        // 移除已处理的tokens
        for _ in 0..<(tokens.count + 1) { // +1 for newline
            if !context.tokens.isEmpty {
                context.tokens.removeFirst()
            }
        }
        
        let refNode = CodeNode(type: MarkdownElement.linkReferenceDefinition, value: label.trimmingCharacters(in: .whitespaces), range: startToken.range)
        
        if !url.isEmpty {
            let urlNode = CodeNode(type: MarkdownElement.text, value: url.trimmingCharacters(in: .whitespaces))
            refNode.addChild(urlNode)
        }
        
        if !title.isEmpty {
            let titleNode = CodeNode(type: MarkdownElement.text, value: title.trimmingCharacters(in: .whitespaces))
            refNode.addChild(titleNode)
        }
        
        context.currentNode.addChild(refNode)
        return true
    }
}

/// 默认Consumer，处理未匹配的tokens
public class MarkdownFallbackConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        // 处理任何未被其他consumer处理的token
        if let mdToken = token as? MarkdownToken {
            let textNode = CodeNode(type: MarkdownElement.text, value: mdToken.text, range: mdToken.range)
            context.currentNode.addChild(textNode)
            context.tokens.removeFirst()
            return true
        }
        
        return false
    }
}
