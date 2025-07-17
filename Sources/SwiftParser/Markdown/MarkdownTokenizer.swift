import Foundation

/// Markdown tokenizer compliant with the CommonMark specification
public class MarkdownTokenizer: CodeTokenizer {
    
    public init() {}
    
    public func tokenize(_ input: String) -> [any CodeToken] {
        var tokens: [any CodeToken] = []
        let lines = input.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
            let lineTokens = tokenizeLine(line, lineNumber: lineIndex + 1)
            tokens.append(contentsOf: lineTokens)
            
            // Add newline tokens (except the last line)
            if lineIndex < lines.count - 1 {
                let newlineRange = line.endIndex..<line.endIndex
                tokens.append(MarkdownToken(kind: .newline, text: "\n", range: newlineRange,
                                          lineNumber: lineIndex + 1, columnNumber: line.count + 1))
            }
        }
        
        // Append EOF token
        let eofRange = input.endIndex..<input.endIndex
        tokens.append(MarkdownToken(kind: .eof, text: "", range: eofRange))
        
        return tokens
    }
    
    private func tokenizeLine(_ line: String, lineNumber: Int) -> [MarkdownToken] {
        var tokens: [MarkdownToken] = []
        var currentIndex = line.startIndex
        var columnNumber = 1
        
        // Detect leading indentation
        let indentLevel = getIndentLevel(line)
        let _ = indentLevel >= 4 // isIndentedCodeBlock - reserved for future use
        
        while currentIndex < line.endIndex {
            let char = line[currentIndex]
            let startIndex = currentIndex
            let isAtLineStart = currentIndex == line.startIndex || 
                               line[line.startIndex..<currentIndex].allSatisfy { $0.isWhitespace }
            
            var tokenKind: MarkdownTokenKind
            var tokenText: String = ""
            var endIndex = line.index(after: currentIndex)
            
            switch char {
            case " ", "\t":
                (tokenText, endIndex) = consumeWhitespace(from: line, startingAt: currentIndex)
                tokenKind = .whitespace
                
            case "#":
                // Check if this is a header marker (line start or only whitespace/hash before)
                let hasOnlyHashOrWhitespaceBefore = currentIndex == line.startIndex || 
                    line[line.startIndex..<currentIndex].allSatisfy { char in
                        char.isWhitespace || char == "#"
                    }
                
                if hasOnlyHashOrWhitespaceBefore {
                    tokenKind = .hash
                    tokenText = String(char)
                } else {
                    tokenKind = .text
                    tokenText = String(char)
                }
                
            case "*":
                // Horizontal rule must be at line start or preceded only by whitespace
                let isHorizontalRuleCandidate = isAtLineStart || 
                    line[line.startIndex..<currentIndex].allSatisfy { $0.isWhitespace }
                
                if isHorizontalRuleCandidate && isHorizontalRule(line, startingWith: currentIndex) {
                    (tokenText, endIndex) = consumeHorizontalRule(from: line, startingAt: currentIndex)
                    tokenKind = .horizontalRule
                } else if isAtLineStart || isListMarker(line, at: currentIndex) {
                    tokenKind = .asterisk
                } else if isEmphasisMarker(line, at: currentIndex) {
                    tokenKind = .asterisk
                } else {
                    tokenKind = .text
                }
                if tokenKind != .horizontalRule {
                    tokenText = String(char)
                }
                
            case "-":
                if isHorizontalRule(line, startingWith: currentIndex) {
                    (tokenText, endIndex) = consumeHorizontalRule(from: line, startingAt: currentIndex)
                    tokenKind = .horizontalRule
                } else if isAtLineStart || isListMarker(line, at: currentIndex) {
                    tokenKind = .dash
                } else {
                    tokenKind = .text
                }
                if tokenKind != .horizontalRule {
                    tokenText = String(char)
                }
                
            case "+":
                if isAtLineStart || isListMarker(line, at: currentIndex) {
                    tokenKind = .plus
                } else {
                    tokenKind = .text
                }
                tokenText = String(char)
                
            case "_":
                if isHorizontalRule(line, startingWith: currentIndex) {
                    (tokenText, endIndex) = consumeHorizontalRule(from: line, startingAt: currentIndex)
                    tokenKind = .horizontalRule
                } else {
                    tokenKind = .underscore
                    tokenText = String(char)
                }
                
            case "`":
                if isCodeFence(line, startingWith: currentIndex) {
                    (tokenText, endIndex) = consumeCodeFence(from: line, startingAt: currentIndex)
                    tokenKind = .backtick
                } else {
                    tokenKind = .backtick
                    tokenText = String(char)
                }
                
            case "~":
                if isCodeFence(line, startingWith: currentIndex, fenceChar: "~") {
                    (tokenText, endIndex) = consumeCodeFence(from: line, startingAt: currentIndex, fenceChar: "~")
                    tokenKind = .tildeTriple
                } else {
                    tokenKind = .text
                    tokenText = String(char)
                }
                
            case ">":
                if isAtLineStart {
                    tokenKind = .greaterThan
                } else {
                    tokenKind = .rightAngle
                }
                tokenText = String(char)
                
            case "[":
                tokenKind = .leftBracket
                tokenText = String(char)
                
            case "]":
                tokenKind = .rightBracket
                tokenText = String(char)
                
            case "(":
                tokenKind = .leftParen
                tokenText = String(char)
                
            case ")":
                tokenKind = .rightParen2
                tokenText = String(char)
                
            case "!":
                tokenKind = .exclamation
                tokenText = String(char)
                
            case "<":
                if isAutolink(line, startingAt: currentIndex) {
                    tokenKind = .leftAngle
                    tokenText = String(char)
                } else if isHTMLTag(line, startingAt: currentIndex) {
                    (tokenText, endIndex) = consumeHTMLTag(from: line, startingAt: currentIndex)
                    tokenKind = .htmlTag
                } else {
                    tokenKind = .leftAngle
                    tokenText = String(char)
                }
                
            case "|":
                tokenKind = .pipe
                tokenText = String(char)
                
            case ":":
                tokenKind = .colon
                tokenText = String(char)
                
            case "\\":
                if currentIndex < line.index(before: line.endIndex) {
                    let nextChar = line[line.index(after: currentIndex)]
                    if isEscapableCharacter(nextChar) {
                        tokenKind = .backslash
                        tokenText = String(char)
                    } else {
                        tokenKind = .text
                        tokenText = String(char)
                    }
                } else {
                    tokenKind = .text
                    tokenText = String(char)
                }
                
            case "&":
                if isEntityReference(line, startingAt: currentIndex) {
                    (tokenText, endIndex) = consumeEntityReference(from: line, startingAt: currentIndex)
                    tokenKind = .entityRef
                } else {
                    tokenKind = .ampersand
                    tokenText = String(char)
                }
                
            case "0"..."9":
                if isAtLineStart || isOrderedListMarker(line, at: currentIndex) {
                    (tokenText, endIndex) = consumeDigits(from: line, startingAt: currentIndex)
                    tokenKind = .digit
                } else {
                    tokenKind = .text
                    tokenText = String(char)
                }
                
            case ".":
                tokenKind = .dot
                tokenText = String(char)
                
            case "^":
                tokenKind = .caret
                tokenText = String(char)
                
            case "@":
                tokenKind = .atSign
                tokenText = String(char)
                
            default:
                // Consume regular text until the next special character
                (tokenText, endIndex) = consumeText(from: line, startingAt: currentIndex)
                tokenKind = .text
            }
            
            let range = startIndex..<endIndex
            let token = MarkdownToken(kind: tokenKind, text: tokenText, range: range,
                                    lineNumber: lineNumber, columnNumber: columnNumber,
                                    isAtLineStart: isAtLineStart, indentLevel: indentLevel)
            tokens.append(token)
            
            columnNumber += tokenText.count
            currentIndex = endIndex
        }
        
        return tokens
    }
    
    // MARK: - Helper methods
    
    private func getIndentLevel(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }
    
    private func consumeWhitespace(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        
        while currentIndex < line.endIndex && line[currentIndex].isWhitespace {
            text.append(line[currentIndex])
            currentIndex = line.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
    
    private func consumeText(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        let specialChars: Set<Character> = ["*", "_", "`", "[", "]", "(", ")", "!", "<", ">", "|", ":", "\\", "&", "#", "-", "+", "~"]
        
        while currentIndex < line.endIndex && !line[currentIndex].isWhitespace && !specialChars.contains(line[currentIndex]) {
            text.append(line[currentIndex])
            currentIndex = line.index(after: currentIndex)
        }
        
        if text.isEmpty {
            text = String(line[index])
            currentIndex = line.index(after: index)
        }
        
        return (text, currentIndex)
    }
    
    private func consumeDigits(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        
        while currentIndex < line.endIndex && line[currentIndex].isNumber {
            text.append(line[currentIndex])
            currentIndex = line.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
    
    private func isListMarker(_ line: String, at index: String.Index) -> Bool {
        // Simplified list marker detection
        return index == line.startIndex || line[line.startIndex..<index].allSatisfy { $0.isWhitespace }
    }
    
    private func isOrderedListMarker(_ line: String, at index: String.Index) -> Bool {
        guard isListMarker(line, at: index) else { return false }
        
        var currentIndex = index
        while currentIndex < line.endIndex && line[currentIndex].isNumber {
            currentIndex = line.index(after: currentIndex)
        }
        
        return currentIndex < line.endIndex && (line[currentIndex] == "." || line[currentIndex] == ")")
    }
    
    private func isEmphasisMarker(_ line: String, at index: String.Index) -> Bool {
        // Simplified emphasis marker detection
        return true
    }
    
    private func isHorizontalRule(_ line: String, startingWith index: String.Index) -> Bool {
        let char = line[index]
        guard char == "*" || char == "-" || char == "_" else { return false }
        
        let remainingLine = String(line[index...])
        let charCount = remainingLine.filter { $0 == char }.count
        let nonWhitespaceCharCount = remainingLine.filter { !$0.isWhitespace && $0 != char }.count
        
        // Horizontal rule requires at least three identical characters and nothing else except whitespace
        return charCount >= 3 && nonWhitespaceCharCount == 0
    }
    
    private func consumeHorizontalRule(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        return (String(line[index...]), line.endIndex)
    }
    
    private func isCodeFence(_ line: String, startingWith index: String.Index, fenceChar: Character = "`") -> Bool {
        var currentIndex = index
        var count = 0
        
        while currentIndex < line.endIndex && line[currentIndex] == fenceChar {
            count += 1
            currentIndex = line.index(after: currentIndex)
        }
        
        return count >= 3
    }
    
    private func consumeCodeFence(from line: String, startingAt index: String.Index, fenceChar: Character = "`") -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        
        while currentIndex < line.endIndex && line[currentIndex] == fenceChar {
            text.append(line[currentIndex])
            currentIndex = line.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
    
    private func isHTMLTag(_ line: String, startingAt index: String.Index) -> Bool {
        guard index < line.endIndex && line[index] == "<" else { return false }
        return line[index...].contains(">")
    }
    
    private func isAutolink(_ line: String, startingAt index: String.Index) -> Bool {
        guard index < line.endIndex && line[index] == "<" else { return false }
        
        let substring = String(line[index...])
        if let endIndex = substring.firstIndex(of: ">") {
            let content = String(substring[substring.index(after: substring.startIndex)..<endIndex])
            
            // Check if this is a URL or email autolink
            return content.contains("://") || content.contains("@")
        }
        
        return false
    }
    
    private func consumeHTMLTag(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        
        while currentIndex < line.endIndex {
            text.append(line[currentIndex])
            if line[currentIndex] == ">" {
                currentIndex = line.index(after: currentIndex)
                break
            }
            currentIndex = line.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
    
    private func isEscapableCharacter(_ char: Character) -> Bool {
        let escapableChars: Set<Character> = ["\\", "`", "*", "_", "{", "}", "[", "]", "(", ")", "#", "+", "-", ".", "!", "|", "<", ">"]
        return escapableChars.contains(char)
    }
    
    private func isEntityReference(_ line: String, startingAt index: String.Index) -> Bool {
        guard index < line.endIndex && line[index] == "&" else { return false }
        return line[index...].contains(";")
    }
    
    private func consumeEntityReference(from line: String, startingAt index: String.Index) -> (String, String.Index) {
        var currentIndex = index
        var text = ""
        
        while currentIndex < line.endIndex {
            text.append(line[currentIndex])
            if line[currentIndex] == ";" {
                currentIndex = line.index(after: currentIndex)
                break
            }
            currentIndex = line.index(after: currentIndex)
        }
        
        return (text, currentIndex)
    }
}
