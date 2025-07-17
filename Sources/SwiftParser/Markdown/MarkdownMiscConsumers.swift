import Foundation

/// Consumer for handling newlines and blank lines
public class MarkdownNewlineConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        if mdToken.kind == .newline {
            context.tokens.removeFirst()
            
            // Check if it's a double newline (blank line)
            if let nextToken = context.tokens.first as? MarkdownToken,
               nextToken.kind == .newline {
                // It's a blank line; consume it without creating a node
                context.tokens.removeFirst()
                return true
            }
            
            // Single newline, usually no node is needed
            return true
        }
        
        return false
    }
}

/// Consumer for handling plain text (fallback)
public class MarkdownTextConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // If the token is not processed by other consumers, treat it as plain text
        if mdToken.kind == .text || mdToken.kind == .whitespace {
            let textNode = CodeNode(type: MarkdownElement.text, value: mdToken.text, range: mdToken.range)
            context.currentNode.addChild(textNode)
            context.tokens.removeFirst()
            return true
        }
        
        return false
    }
}

/// Consumer for handling tables (GFM extension)
public class MarkdownTableConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if it might be the start of a table (a line containing the | character)
        if mdToken.kind == .pipe || (mdToken.kind == .text && mdToken.isAtLineStart) {
            return tryConsumeTable(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func tryConsumeTable(context: inout CodeContext, token: MarkdownToken) -> Bool {
        // First, preview whether the current line contains a pipe symbol
        var currentIndex = 0
        var hasPipe = false
        var lineTokens: [MarkdownToken] = []
        
        // Collect all tokens of the current line
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
        
        // Check if the next line is a separator line
        var separatorIndex = currentIndex + 1 // Skip the newline character
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
        
        // Check if the separator line conforms to the table format
        isSeparatorLine = isValidTableSeparator(separatorTokens)
        
        if !isSeparatorLine {
            return false
        }
        
        // Start building the table
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
        
        // Process the header row
        let headerRow = parseTableRow(firstRowTokens)
        if let headerRowNode = headerRow {
            tableNode.addChild(headerRowNode)
        }
        
        // Remove processed tokens (first row and separator row)
        for _ in 0..<(firstRowTokens.count + 1 + separatorTokens.count + 1) {
            if !context.tokens.isEmpty {
                context.tokens.removeFirst()
            }
        }
        
        // Continue processing table data rows
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof {
                break
            }
            
            // Collect the current row
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
            
            // If the row does not contain a pipe, the table ends
            if !hasPipeInRow && !rowTokens.isEmpty {
                // Put the tokens back
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
                // Blank line, table ends
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
                    // End the current cell
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
        
        // Process the last cell
        if inCell && !cellContent.isEmpty {
            let cellNode = CodeNode(type: MarkdownElement.tableCell, value: cellContent.trimmingCharacters(in: .whitespaces))
            rowNode.addChild(cellNode)
        }
        
        return rowNode.children.isEmpty ? nil : rowNode
    }
}

/// Consumer for handling strikethrough (GFM extension)
public class MarkdownStrikethroughConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if it's the start of ~~
        if mdToken.kind == .text && mdToken.text == "~" {
            // Check if the next token is also ~
            if context.tokens.count > 1,
               let nextToken = context.tokens[1] as? MarkdownToken,
               nextToken.kind == .text && nextToken.text == "~" {
                return consumeStrikethrough(context: &context, token: mdToken)
            }
        }
        
        return false
    }
    
    private func consumeStrikethrough(context: inout CodeContext, token: MarkdownToken) -> Bool {
        context.tokens.removeFirst() // Remove the first ~
        context.tokens.removeFirst() // Remove the second ~
        
        var strikethroughText = ""
        var foundClosing = false
        
        // Find the closing ~~
        while let currentToken = context.tokens.first as? MarkdownToken {
            if currentToken.kind == .eof || currentToken.kind == .newline {
                break
            }
            
            if currentToken.kind == .text && currentToken.text == "~" {
                // Check if the next token is also ~
                if context.tokens.count > 1,
                   let nextToken = context.tokens[1] as? MarkdownToken,
                   nextToken.kind == .text && nextToken.text == "~" {
                    context.tokens.removeFirst() // Remove the first ~
                    context.tokens.removeFirst() // Remove the second ~
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
            // If no closing tag is found, treat it as plain text
            let textNode = CodeNode(type: MarkdownElement.text, value: "~~" + strikethroughText, range: token.range)
            context.currentNode.addChild(textNode)
            return true
        }
    }
}

/// Consumer for handling link reference definitions
public class MarkdownLinkReferenceConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        guard let mdToken = token as? MarkdownToken else { return false }
        
        // Check if it's a link reference definition starting with [ at the beginning of a line
        if mdToken.kind == .leftBracket && mdToken.isAtLineStart {
            return tryConsumeLinkReference(context: &context, token: mdToken)
        }
        
        return false
    }
    
    private func tryConsumeLinkReference(context: inout CodeContext, token: MarkdownToken) -> Bool {
        var tempTokens: [MarkdownToken] = []
        var currentIndex = 0
        
        // Collect tokens of the current line for checking
        while currentIndex < context.tokens.count {
            guard let currentToken = context.tokens[currentIndex] as? MarkdownToken else { break }
            
            if currentToken.kind == .newline || currentToken.kind == .eof {
                break
            }
            
            tempTokens.append(currentToken)
            currentIndex += 1
        }
        
        // Check if it conforms to the link reference definition format: [label]: url "title"
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
        
        // Parse the link reference definition
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
            case 0: // Parse label
                if token.kind == .rightBracket {
                    phase = 1
                } else if token.kind != .leftBracket {
                    label += token.text
                }
                
            case 1: // Parse URL
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
                
            case 2: // Parse title
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
        
        // Remove processed tokens
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

/// Default consumer, handles unmatched tokens
public class MarkdownFallbackConsumer: CodeTokenConsumer {
    
    public init() {}
    
    public func consume(context: inout CodeContext, token: any CodeToken) -> Bool {
        // Process any token not handled by other consumers
        if let mdToken = token as? MarkdownToken {
            let textNode = CodeNode(type: MarkdownElement.text, value: mdToken.text, range: mdToken.range)
            context.currentNode.addChild(textNode)
            context.tokens.removeFirst()
            return true
        }
        
        return false
    }
}
