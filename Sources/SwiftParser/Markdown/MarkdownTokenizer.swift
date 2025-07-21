import Foundation

// MARK: - Markdown Tokenizer
public class MarkdownTokenizer: CodeOutdatedTokenizer {
    // MARK: - Tokenization State
    private var input: String = ""
    private var current: String.Index = "".startIndex
    private var tokens: [MarkdownToken] = []
    
    public init() {}
    
    // MARK: - Main Tokenization Entry Point
    public func tokenize(_ input: String) -> [any CodeToken<MarkdownTokenElement>] {
        self.input = input
        self.current = input.startIndex
        self.tokens = []
        
        while current < input.endIndex {
            tokenizeNext()
        }
        
        // Add EOF token
        let eofRange = current..<current
        tokens.append(MarkdownToken.eof(at: eofRange))
        
        return tokens
    }
    
    // MARK: - Core Tokenization Logic
    private func tokenizeNext() {
        guard current < input.endIndex else { return }
        
        let char = input[current]
        let startIndex = current
        
        switch char {
        // MARK: - Single Character Tokens
        case "#":
            addToken(.hash, text: "#", from: startIndex)
            
        case "*":
            addToken(.asterisk, text: "*", from: startIndex)
            
        case "_":
            addToken(.underscore, text: "_", from: startIndex)
            
        case "`":
            // Check for inline code or code blocks
            if tokenizeCodeBlock(from: startIndex) {
                return // Don't call advanceIndex() if we handled a multi-character token
            }
            // If no code block found, treat as regular text
            addToken(.text, text: "`", from: startIndex)
            
        case "-":
            addToken(.dash, text: "-", from: startIndex)
            
        case "+":
            addToken(.plus, text: "+", from: startIndex)
            
        case "=":
            addToken(.equals, text: "=", from: startIndex)
            
        case "~":
            addToken(.tilde, text: "~", from: startIndex)
            
        case "^":
            addToken(.caret, text: "^", from: startIndex)

        case "@":
            addToken(.atSign, text: "@", from: startIndex)
            
        case "|":
            addToken(.pipe, text: "|", from: startIndex)

        case ":":
            if tokenizeCustomContainer(from: startIndex) {
                return
            }
            addToken(.colon, text: ":", from: startIndex)
            
        case ";":
            addToken(.semicolon, text: ";", from: startIndex)
            
        case "!":
            addToken(.exclamation, text: "!", from: startIndex)
            
        case "?":
            addToken(.question, text: "?", from: startIndex)
            
        case ".":
            addToken(.dot, text: ".", from: startIndex)
            
        case ",":
            addToken(.comma, text: ",", from: startIndex)
            
        case ">":
            addToken(.gt, text: ">", from: startIndex)
            
        case "<":
            if tokenizeAutolink(from: startIndex) {
                return // Don't call advanceIndex() if we handled an autolink
            }
            if tokenizeHtmlStructure(from: startIndex) {
                return // Don't call advanceIndex() if we handled a multi-character token
            }
            addToken(.lt, text: "<", from: startIndex)
            
        case "&":
            if tokenizeHtmlEntity() {
                return // Don't call advanceIndex() if we handled an HTML entity
            }
            addToken(.ampersand, text: "&", from: startIndex)
            
        case "\\":
            if tokenizeBackslash(from: startIndex) {
                return // Don't call advanceIndex() if we handled a multi-character token
            }
            
        case "/":
            addToken(.forwardSlash, text: "/", from: startIndex)
            
        case "\"":
            addToken(.quote, text: "\"", from: startIndex)
            
        case "'":
            addToken(.singleQuote, text: "'", from: startIndex)
            
        case "[":
            addToken(.leftBracket, text: "[", from: startIndex)
            
        case "]":
            addToken(.rightBracket, text: "]", from: startIndex)
            
        case "(":
            addToken(.leftParen, text: "(", from: startIndex)
            
        case ")":
            addToken(.rightParen, text: ")", from: startIndex)
            
        case "{":
            addToken(.leftBrace, text: "{", from: startIndex)
            
        case "}":
            addToken(.rightBrace, text: "}", from: startIndex)
            
        case "$":
            if tokenizeMathFormula(from: startIndex) {
                return // Don't call advanceIndex() if we handled a math formula
            }
            // If not a math formula, treat as regular text token
            addToken(.text, text: "$", from: startIndex)
            
        // MARK: - Whitespace Tokens
        case " ":
            // Check if this could be the start of an indented code block
            if isAtLineStart() && tokenizeIndentedCodeBlock(from: startIndex) {
                return // Don't call advanceIndex() if we handled an indented code block
            }
            addToken(.space, text: " ", from: startIndex)
            
        case "\t":
            // Check if this could be the start of an indented code block
            if isAtLineStart() && tokenizeIndentedCodeBlock(from: startIndex) {
                return // Don't call advanceIndex() if we handled an indented code block
            }
            addToken(.tab, text: "\t", from: startIndex)
            
        case "\n":
            addToken(.newline, text: "\n", from: startIndex)
            
        case "\r\n":
            // Handle CRLF as a single newline token
            addToken(.newline, text: "\r\n", from: startIndex)
            
        case "\r":
            if let nextIndex = input.index(current, offsetBy: 1, limitedBy: input.endIndex),
               nextIndex < input.endIndex && input[nextIndex] == "\n" {
                // Handle CRLF as a single newline
                addToken(.newline, text: "\r\n", from: startIndex)
                current = input.index(nextIndex, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                return // Don't call advanceIndex() again
            } else {
                addToken(.carriageReturn, text: "\r", from: startIndex)
            }
            
        // MARK: - Digits
        case "0"..."9":
            // Check if this is a pure number or mixed alphanumeric
            if shouldTokenizeAsText(from: startIndex) {
                tokenizeText(from: startIndex)
            } else {
                tokenizeNumber(from: startIndex)
            }
            return // Don't call advanceIndex() as tokenize methods handle it
            
        // MARK: - Default Text
        default:
            tokenizeText(from: startIndex)
            return // Don't call advanceIndex() as tokenizeText handles it
        }
        
        advanceIndex()
    }
    
    // MARK: - Helper Methods
    private func addToken(_ element: MarkdownTokenElement, text: String, from startIndex: String.Index) {
        let endIndex = input.index(startIndex, offsetBy: text.count, limitedBy: input.endIndex) ?? input.endIndex
        let range = startIndex..<endIndex
        let token = MarkdownToken(element: element, text: text, range: range)
        tokens.append(token)
    }
    
    private func advanceIndex() {
        if current < input.endIndex {
            current = input.index(after: current)
        }
    }
    
    private func peek(offset: Int = 1) -> Character? {
        guard let index = input.index(current, offsetBy: offset, limitedBy: input.endIndex),
              index < input.endIndex else {
            return nil
        }
        return input[index]
    }
    
    private func peekString(length: Int) -> String? {
        guard let endIndex = input.index(current, offsetBy: length, limitedBy: input.endIndex) else {
            return nil
        }
        return String(input[current..<endIndex])
    }
    
    private func consume(_ count: Int = 1) -> String {
        let startIndex = current
        let endIndex = input.index(current, offsetBy: count, limitedBy: input.endIndex) ?? input.endIndex
        let result = String(input[startIndex..<endIndex])
        current = endIndex
        return result
    }
    
    private func consumeWhile(_ condition: (Character) -> Bool) -> String {
        let startIndex = current
        
        while current < input.endIndex && condition(input[current]) {
            current = input.index(after: current)
        }
        
        return String(input[startIndex..<current])
    }
    
    private func match(_ string: String) -> Bool {
        guard let endIndex = input.index(current, offsetBy: string.count, limitedBy: input.endIndex) else {
            return false
        }
        return input[current..<endIndex] == string
    }
    
    private func isAtLineStart() -> Bool {
        // We're at line start if we're at the beginning of input
        if current == input.startIndex {
            return true
        }
        
        // Or if the previous character was a newline or carriage return
        let prevIndex = input.index(before: current)
        let prevChar = input[prevIndex]
        return prevChar == "\n" || prevChar == "\r"
    }
    
    private func isAtLineEnd() -> Bool {
        return current >= input.endIndex || 
               input[current] == "\n" || 
               input[current] == "\r"
    }
    
    private func isWhitespace(_ char: Character) -> Bool {
        return char == " " || char == "\t"
    }
    
    private func isNewline(_ char: Character) -> Bool {
        return char == "\n" || char == "\r"
    }
    
    private func isAlphanumeric(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber
    }
    
    private func isPunctuation(_ char: Character) -> Bool {
        return "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".contains(char)
    }
    
    private func isUnicodeWhitespace(_ char: Character) -> Bool {
        return char.isWhitespace
    }
    
    private func isUnicodePunctuation(_ char: Character) -> Bool {
        return char.isPunctuation
    }
}

// MARK: - Extended Tokenization Methods
extension MarkdownTokenizer {
    
    /// Tokenize a sequence of characters as a single token
    private func tokenizeSequence(_ element: MarkdownTokenElement, 
                                 startChar: Character, 
                                 minLength: Int = 1,
                                 maxLength: Int = Int.max) -> Bool {
        let startIndex = current
        var length = 0
        
        while current < input.endIndex && 
              input[current] == startChar && 
              length < maxLength {
            current = input.index(after: current)
            length += 1
        }
        
        if length >= minLength {
            let range = startIndex..<current
            let text = String(input[range])
            tokens.append(MarkdownToken(element: element, text: text, range: range))
            return true
        } else {
            current = startIndex
            return false
        }
    }
    
    /// Tokenize HTML structure - handles tags, blocks, and unclosed blocks
    /// Returns true if an HTML structure was handled
    private func tokenizeHtmlStructure(from startIndex: String.Index) -> Bool {
        // First check if this is an HTML comment
        if tokenizeHtmlComment(from: startIndex) {
            return true
        }
        
        // Try to tokenize as HTML tag first
        if let tagResult = tryTokenizeHtmlTag(from: startIndex) {
            current = tagResult.endIndex
            
            // Check if this is a self-closing tag
            if tagResult.isSelfClosing {
                tokens.append(MarkdownToken(element: .htmlTag, text: tagResult.content, range: startIndex..<tagResult.endIndex))
                return true
            }
            
            // Check if this is an opening tag that could start an HTML block
            if tagResult.isOpeningTag {
                // Try to find the matching closing tag
                if let blockResult = tryTokenizeHtmlBlock(from: startIndex, openingTag: tagResult) {
                    tokens.append(MarkdownToken(element: .htmlBlock, text: blockResult.content, range: startIndex..<blockResult.endIndex))
                    current = blockResult.endIndex
                    return true
                }
                
                // No matching closing tag found, check for unclosed block
                if let unclosedResult = tryTokenizeHtmlUnclosedBlock(from: startIndex, openingTag: tagResult) {
                    tokens.append(MarkdownToken(element: .htmlUnclosedBlock, text: unclosedResult.content, range: startIndex..<unclosedResult.endIndex))
                    current = unclosedResult.endIndex
                    return true
                }
            }
            
            // Fall back to treating as individual HTML tag
            tokens.append(MarkdownToken(element: .htmlTag, text: tagResult.content, range: startIndex..<tagResult.endIndex))
            return true
        }
        
        return false
    }
    
    /// Helper structure for HTML tag parsing results
    private struct HtmlTagResult {
        let content: String
        let endIndex: String.Index
        let tagName: String
        let isSelfClosing: Bool
        let isOpeningTag: Bool
        let isClosingTag: Bool
    }
    
    /// Helper structure for HTML block parsing results
    private struct HtmlBlockResult {
        let content: String
        let endIndex: String.Index
    }
    
    /// Try to tokenize an HTML tag
    private func tryTokenizeHtmlTag(from startIndex: String.Index) -> HtmlTagResult? {
        var currentIndex = startIndex
        guard currentIndex < input.endIndex && input[currentIndex] == "<" else {
            return nil
        }
        
        currentIndex = input.index(after: currentIndex)
        
        // Check for closing tag
        var isClosingTag = false
        if currentIndex < input.endIndex && input[currentIndex] == "/" {
            isClosingTag = true
            currentIndex = input.index(after: currentIndex)
        }
        
        // Must have a letter to start tag name
        guard currentIndex < input.endIndex && (input[currentIndex].isLetter || input[currentIndex] == "!") else {
            return nil
        }
        
        // Extract tag name
        let tagNameStart = currentIndex
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            if char.isLetter || char.isNumber || char == "-" || char == "_" {
                currentIndex = input.index(after: currentIndex)
            } else {
                break
            }
        }
        
        let tagName = String(input[tagNameStart..<currentIndex])
        
        // Consume attributes and find closing bracket
        var isSelfClosing = false
        var foundClosingBracket = false
        
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            if char == ">" {
                // End of tag
                currentIndex = input.index(after: currentIndex)
                foundClosingBracket = true
                break
            } else if char == "/" {
                // Self-closing tag
                currentIndex = input.index(after: currentIndex)
                if currentIndex < input.endIndex && input[currentIndex] == ">" {
                    currentIndex = input.index(after: currentIndex)
                    isSelfClosing = true
                    foundClosingBracket = true
                    break
                }
            } else {
                currentIndex = input.index(after: currentIndex)
            }
        }
        
        // Check if we found a complete tag
        if foundClosingBracket && currentIndex > input.index(after: startIndex) {
            let content = String(input[startIndex..<currentIndex])
            return HtmlTagResult(
                content: content,
                endIndex: currentIndex,
                tagName: tagName,
                isSelfClosing: isSelfClosing,
                isOpeningTag: !isClosingTag && !isSelfClosing,
                isClosingTag: isClosingTag
            )
        }
        
        return nil
    }
    
    /// Try to tokenize an HTML block (matched opening and closing tags)
    private func tryTokenizeHtmlBlock(from startIndex: String.Index, openingTag: HtmlTagResult) -> HtmlBlockResult? {
        var currentIndex = openingTag.endIndex
        
        // Look for the matching closing tag
        let closingTagPattern = "</\(openingTag.tagName)>"
        
        while currentIndex < input.endIndex {
            // Try to find the closing tag
            if let closingTagRange = input.range(of: closingTagPattern, options: .caseInsensitive, range: currentIndex..<input.endIndex) {
                // Found closing tag
                let closingTagEnd = closingTagRange.upperBound
                let blockContent = String(input[startIndex..<closingTagEnd])
                
                return HtmlBlockResult(
                    content: blockContent,
                    endIndex: closingTagEnd
                )
            }
            
            // Move to next character
            currentIndex = input.index(after: currentIndex)
        }
        
        return nil
    }
    
    /// Try to tokenize an HTML unclosed block (ends at first blank line)
    private func tryTokenizeHtmlUnclosedBlock(from startIndex: String.Index, openingTag: HtmlTagResult) -> HtmlBlockResult? {
        var currentIndex = openingTag.endIndex
        
        // Look for the first blank line (two consecutive newlines)
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            if char == "\n" {
                // Found a newline, check if next line is blank
                let nextIndex = input.index(after: currentIndex)
                if nextIndex < input.endIndex {
                    let nextChar = input[nextIndex]
                    if nextChar == "\n" {
                        // Found blank line, end the unclosed block here
                        return HtmlBlockResult(
                            content: String(input[startIndex..<currentIndex]),
                            endIndex: currentIndex
                        )
                    }
                }
            }
            
            currentIndex = input.index(after: currentIndex)
        }
        
        // If no blank line found, include everything to the end
        return HtmlBlockResult(
            content: String(input[startIndex..<input.endIndex]),
            endIndex: input.endIndex
        )
    }
    
    /// Tokenize HTML comments
    /// Returns true if an HTML comment was handled
    private func tokenizeHtmlComment(from startIndex: String.Index) -> Bool {
        var currentIndex = current
        
        // Check for comment start "<!--"
        let commentStart = "<!--"
        var matchIndex = 0
        
        while currentIndex < input.endIndex && matchIndex < commentStart.count {
            if input[currentIndex] == commentStart[commentStart.index(commentStart.startIndex, offsetBy: matchIndex)] {
                matchIndex += 1
                currentIndex = input.index(after: currentIndex)
            } else {
                return false
            }
        }
        
        // Found comment start, now look for end "-->"
        while currentIndex < input.endIndex {
            if input[currentIndex] == "-" {
                let remainingChars = input.distance(from: currentIndex, to: input.endIndex)
                if remainingChars >= 3 {
                    let endCheck = input[currentIndex...input.index(currentIndex, offsetBy: 2)]
                    if endCheck == "-->" {
                        currentIndex = input.index(currentIndex, offsetBy: 3)
                        break
                    }
                }
            }
            currentIndex = input.index(after: currentIndex)
        }
        
        if currentIndex > input.index(after: startIndex) {
            current = currentIndex
            let range = startIndex..<current
            let text = String(input[range])
            tokens.append(MarkdownToken(element: .htmlComment, text: text, range: range))
            return true
        }
        
        return false
    }
    
    /// Tokenize HTML entities
    private func tokenizeHtmlEntity() -> Bool {
        let startIndex = current
        
        guard input[current] == "&" else { return false }
        
        current = input.index(after: current)
        
        // Named entity
        if current < input.endIndex && input[current].isLetter {
            let entityStart = current
            while current < input.endIndex && 
                  (input[current].isLetter || input[current].isNumber) {
                current = input.index(after: current)
            }
            
            if current < input.endIndex && input[current] == ";" {
                let entityName = String(input[entityStart..<current])
                if isValidHtmlEntity(entityName) {
                    current = input.index(after: current)
                    let range = startIndex..<current
                    let text = String(input[range])
                    tokens.append(MarkdownToken(element: .htmlEntity, text: text, range: range))
                    return true
                }
            }
        }
        // Numeric entity
        else if current < input.endIndex && input[current] == "#" {
            current = input.index(after: current)
            
            if current < input.endIndex && (input[current] == "x" || input[current] == "X") {
                // Hexadecimal entity
                current = input.index(after: current)
                while current < input.endIndex && input[current].isHexDigit {
                    current = input.index(after: current)
                }
            } else {
                // Decimal entity
                while current < input.endIndex && input[current].isNumber {
                    current = input.index(after: current)
                }
            }
            
            if current < input.endIndex && input[current] == ";" {
                current = input.index(after: current)
                let range = startIndex..<current
                let text = String(input[range])
                tokens.append(MarkdownToken(element: .htmlEntity, text: text, range: range))
                return true
            }
        }
        
        // Not a valid entity, reset
        current = startIndex
        return false
    }
    
    /// Check if the given name is a valid HTML entity
    private func isValidHtmlEntity(_ name: String) -> Bool {
        // Common HTML entities that should be recognized
        let validEntities: Set<String> = [
            "amp", "lt", "gt", "quot", "apos", "nbsp", "copy", "reg", "trade", 
            "hellip", "mdash", "ndash", "lsquo", "rsquo", "ldquo", "rdquo",
            "bull", "middot", "times", "divide", "plusmn", "sup2", "sup3",
            "frac14", "frac12", "frac34", "iexcl", "cent", "pound", "curren",
            "yen", "brvbar", "sect", "uml", "ordf", "laquo", "not", "shy",
            "macr", "deg", "plusmn", "acute", "micro", "para", "middot",
            "cedil", "ordm", "raquo", "iquest", "Agrave", "Aacute", "Acirc",
            "Atilde", "Auml", "Aring", "AElig", "Ccedil", "Egrave", "Eacute",
            "Ecirc", "Euml", "Igrave", "Iacute", "Icirc", "Iuml", "ETH",
            "Ntilde", "Ograve", "Oacute", "Ocirc", "Otilde", "Ouml", "times",
            "Oslash", "Ugrave", "Uacute", "Ucirc", "Uuml", "Yacute", "THORN",
            "szlig", "agrave", "aacute", "acirc", "atilde", "auml", "aring",
            "aelig", "ccedil", "egrave", "eacute", "ecirc", "euml", "igrave",
            "iacute", "icirc", "iuml", "eth", "ntilde", "ograve", "oacute",
            "ocirc", "otilde", "ouml", "divide", "oslash", "ugrave", "uacute",
            "ucirc", "uuml", "yacute", "thorn", "yuml"
        ]
        
        return validEntities.contains(name)
    }
    
    /// Tokenize backslash and potential TeX math delimiters
    /// Returns true if a multi-character token was handled
    private func tokenizeBackslash(from startIndex: String.Index) -> Bool {
        // Check if this is a TeX math delimiter that should be tokenized as a complete formula
        if let nextIndex = input.index(current, offsetBy: 1, limitedBy: input.endIndex),
           nextIndex < input.endIndex {
            let nextChar = input[nextIndex]
            
            switch nextChar {
            case "[":
                // \[...\] - TeX display math
                if let formulaToken = tokenizeTexDisplayMath(from: startIndex) {
                    tokens.append(formulaToken)
                    return true
                }
                
            case "(":
                // \(...\) - TeX inline math
                if let formulaToken = tokenizeTexInlineMath(from: startIndex) {
                    tokens.append(formulaToken)
                    return true
                }
                
            case "]", ")":
                // \] or \) - These are closing delimiters without opening, treat as regular text
                let range = startIndex..<input.index(current, offsetBy: 2, limitedBy: input.endIndex)!
                let text = String(input[range])
                tokens.append(MarkdownToken.text(text, at: range))
                current = range.upperBound
                return true
                
            default:
                break
            }
        }
        
        // Not a TeX math delimiter, treat as regular backslash
        addToken(.backslash, text: "\\", from: startIndex)
        return false
    }
    
    /// Tokenize math formulas starting with dollar signs
    /// Returns true if a math formula was handled
    private func tokenizeMathFormula(from startIndex: String.Index) -> Bool {
        // Check if this starts with $$
        if let nextIndex = input.index(current, offsetBy: 1, limitedBy: input.endIndex),
           nextIndex < input.endIndex && input[nextIndex] == "$" {
            // This might be a display math formula $$...$$
            if let formulaToken = tokenizeDisplayMath(from: startIndex) {
                tokens.append(formulaToken)
                return true
            }
            // If we can't find a complete display math formula, don't treat it as math
            return false
        } else {
            // This might be an inline math formula $...$
            if let formulaToken = tokenizeInlineMath(from: startIndex) {
                tokens.append(formulaToken)
                return true
            }
            // If we can't find a complete inline math formula, don't treat it as math
            return false
        }
    }
    
    /// Tokenize display math formula $$...$$
    private func tokenizeDisplayMath(from startIndex: String.Index) -> MarkdownToken? {
        var currentIndex = startIndex
        
        // Skip the opening $$
        guard let afterOpenIndex = input.index(currentIndex, offsetBy: 2, limitedBy: input.endIndex) else {
            return nil
        }
        currentIndex = afterOpenIndex
        
        // Find the closing $$
        while currentIndex < input.endIndex {
            if input[currentIndex] == "$" {
                if let nextIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex),
                   nextIndex < input.endIndex && input[nextIndex] == "$" {
                    // Found closing $$
                    let endIndex = input.index(nextIndex, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                    let range = startIndex..<endIndex
                    let text = String(input[range])
                    current = endIndex
                    return MarkdownToken.formulaBlock(text, at: range)
                }
            }
            currentIndex = input.index(after: currentIndex)
        }
        
        // No closing $$ found, treat as display math from $$ to EOF
        let range = startIndex..<input.endIndex
        let text = String(input[range])
        current = input.endIndex
        return MarkdownToken.formulaBlock(text, at: range)
    }
    
    /// Tokenize inline math formula $...$
    private func tokenizeInlineMath(from startIndex: String.Index) -> MarkdownToken? {
        var currentIndex = startIndex
        
        // Skip the opening $
        guard let afterOpenIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex) else {
            return nil
        }
        currentIndex = afterOpenIndex
        
        // Check if the first character after $ is whitespace - if so, not a valid math formula
        if currentIndex < input.endIndex && input[currentIndex].isWhitespace {
            return nil
        }
        
        // Find the closing $
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            if char == "$" {
                // Check if the character before $ is whitespace - if so, not a valid math formula
                if currentIndex > afterOpenIndex {
                    let prevIndex = input.index(before: currentIndex)
                    if input[prevIndex].isWhitespace {
                        return nil
                    }
                }
                
                // Found closing $
                let endIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                let range = startIndex..<endIndex
                let text = String(input[range])
                current = endIndex
                return MarkdownToken.formula(text, at: range)
            }
            
            // Check for newline characters - these invalidate inline math
            if char == "\n" || char == "\r" {
                // Found newline, not a valid inline math formula
                return nil
            }
            
            // Skip escaped characters
            if char == "\\" {
                currentIndex = input.index(currentIndex, offsetBy: 2, limitedBy: input.endIndex) ?? input.endIndex
            } else {
                currentIndex = input.index(after: currentIndex)
            }
        }
        
        // No closing $ found, not a valid inline math
        return nil
    }
    
    /// Tokenize TeX display math formula \[...\]
    private func tokenizeTexDisplayMath(from startIndex: String.Index) -> MarkdownToken? {
        var currentIndex = startIndex
        
        // Skip the opening \[
        guard let afterOpenIndex = input.index(currentIndex, offsetBy: 2, limitedBy: input.endIndex) else {
            return nil
        }
        currentIndex = afterOpenIndex
        
        // Find the closing \]
        while currentIndex < input.endIndex {
            if input[currentIndex] == "\\" {
                if let nextIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex),
                   nextIndex < input.endIndex && input[nextIndex] == "]" {
                    // Found closing \]
                    let endIndex = input.index(nextIndex, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                    let range = startIndex..<endIndex
                    let text = String(input[range])
                    current = endIndex
                    return MarkdownToken.formulaBlock(text, at: range)
                }
            }
            currentIndex = input.index(after: currentIndex)
        }
        
        // No closing \] found, treat as display math from \[ to EOF
        let range = startIndex..<input.endIndex
        let text = String(input[range])
        current = input.endIndex
        return MarkdownToken.formulaBlock(text, at: range)
    }
    
    /// Tokenize TeX inline math formula \(...\)
    private func tokenizeTexInlineMath(from startIndex: String.Index) -> MarkdownToken? {
        var currentIndex = startIndex
        
        // Skip the opening \(
        guard let afterOpenIndex = input.index(currentIndex, offsetBy: 2, limitedBy: input.endIndex) else {
            return nil
        }
        currentIndex = afterOpenIndex
        
        // Find the closing \)
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            // Check for newline characters - these terminate inline math
            if char == "\n" || char == "\r" {
                // Found newline, treat as TeX inline math from \( to end of line
                let range = startIndex..<currentIndex
                let text = String(input[range])
                current = currentIndex
                return MarkdownToken.formula(text, at: range)
            }
            
            if char == "\\" {
                if let nextIndex = input.index(currentIndex, offsetBy: 1, limitedBy: input.endIndex),
                   nextIndex < input.endIndex && input[nextIndex] == ")" {
                    // Found closing \)
                    let endIndex = input.index(nextIndex, offsetBy: 1, limitedBy: input.endIndex) ?? input.endIndex
                    let range = startIndex..<endIndex
                    let text = String(input[range])
                    current = endIndex
                    return MarkdownToken.formula(text, at: range)
                }
            }
            currentIndex = input.index(after: currentIndex)
        }
        
        // No closing \) found and no newline, treat as TeX inline math from \( to EOF
        let range = startIndex..<input.endIndex
        let text = String(input[range])
        current = input.endIndex
        return MarkdownToken.formula(text, at: range)
    }
    
    /// Tokenize code blocks and inline code
    private func tokenizeCodeBlock(from startIndex: String.Index) -> Bool {
        // Check if this is a fenced code block (```)
        if let fencedToken = tokenizeFencedCodeBlock(from: startIndex) {
            tokens.append(fencedToken)
            return true
        }
        
        // Check if this is inline code (`)
        if let inlineToken = tokenizeInlineCode(from: startIndex) {
            tokens.append(inlineToken)
            return true
        }
        
        return false
    }
    
    /// Check if we're at the start of a line and can tokenize indented code block
    private func tokenizeIndentedCodeBlock(from startIndex: String.Index) -> Bool {
        // Check if we have 4 spaces or 1 tab at the start of a line
        var tempIndex = startIndex
        var spaceCount = 0
        
        // Count spaces and tabs
        while tempIndex < input.endIndex {
            if input[tempIndex] == " " {
                spaceCount += 1
                if spaceCount >= 4 {
                    tempIndex = input.index(after: tempIndex)
                    break
                }
            } else if input[tempIndex] == "\t" {
                spaceCount = 4 // Tab counts as 4 spaces
                tempIndex = input.index(after: tempIndex)
                break
            } else {
                break
            }
            tempIndex = input.index(after: tempIndex)
        }
        
        // Need at least 4 spaces worth of indentation
        if spaceCount < 4 {
            return false
        }
        
        // Check if there's actual content after the indentation (not just whitespace)
        var hasContent = false
        var contentCheckIndex = tempIndex
        while contentCheckIndex < input.endIndex && input[contentCheckIndex] != "\n" && input[contentCheckIndex] != "\r" {
            if input[contentCheckIndex] != " " && input[contentCheckIndex] != "\t" {
                hasContent = true
                break
            }
            contentCheckIndex = input.index(after: contentCheckIndex)
        }
        
        // If there's no content on this line, this is not an indented code block
        if !hasContent {
            return false
        }
        
        // Find the end of the indented code block
        let codeBlockStart = startIndex
        var codeBlockEnd = startIndex
        
        // Scan for the end of the indented code block
        while tempIndex < input.endIndex {
            // Skip the current line
            while tempIndex < input.endIndex && input[tempIndex] != "\n" && input[tempIndex] != "\r" {
                tempIndex = input.index(after: tempIndex)
            }
            
            codeBlockEnd = tempIndex
            
            // Skip line ending
            if tempIndex < input.endIndex && input[tempIndex] == "\r" {
                tempIndex = input.index(after: tempIndex)
                if tempIndex < input.endIndex && input[tempIndex] == "\n" {
                    tempIndex = input.index(after: tempIndex)
                }
            } else if tempIndex < input.endIndex && input[tempIndex] == "\n" {
                tempIndex = input.index(after: tempIndex)
            }
            
            // Check if next line is also indented (or blank)
            let lineStart = tempIndex
            var lineSpaces = 0
            var isBlankLine = true
            
            while tempIndex < input.endIndex && input[tempIndex] != "\n" && input[tempIndex] != "\r" {
                if input[tempIndex] == " " {
                    lineSpaces += 1
                } else if input[tempIndex] == "\t" {
                    lineSpaces = 4
                    isBlankLine = false
                    break
                } else {
                    isBlankLine = false
                    break
                }
                tempIndex = input.index(after: tempIndex)
            }
            
            // If it's a blank line, continue
            if isBlankLine {
                continue
            }
            
            // If next line doesn't have enough indentation, stop
            if lineSpaces < 4 {
                break
            }
            
            // Reset to continue scanning
            tempIndex = lineStart
        }
        
        // Create the indented code block token
        let range = codeBlockStart..<codeBlockEnd
        let text = String(input[range])
        let token = MarkdownToken.indentedCodeBlock(text, at: range)
        tokens.append(token)
        
        current = codeBlockEnd
        return true
    }
    
    /// Tokenize fenced code blocks (```...```)
    private func tokenizeFencedCodeBlock(from startIndex: String.Index) -> MarkdownToken? {
        // Check if we have at least 3 backticks
        var tickCount = 0
        var tempIndex = startIndex
        
        while tempIndex < input.endIndex && input[tempIndex] == "`" {
            tickCount += 1
            tempIndex = input.index(after: tempIndex)
        }
        
        if tickCount < 3 {
            return nil
        }
        
        // Skip any language specifier on the same line
        while tempIndex < input.endIndex && input[tempIndex] != "\n" && input[tempIndex] != "\r" {
            tempIndex = input.index(after: tempIndex)
        }
        
        // Skip the newline after the opening fence
        if tempIndex < input.endIndex && (input[tempIndex] == "\n" || input[tempIndex] == "\r") {
            if input[tempIndex] == "\r" && tempIndex < input.endIndex {
                let nextIndex = input.index(after: tempIndex)
                if nextIndex < input.endIndex && input[nextIndex] == "\n" {
                    tempIndex = input.index(after: nextIndex)
                } else {
                    tempIndex = nextIndex
                }
            } else {
                tempIndex = input.index(after: tempIndex)
            }
        }
        
        // Find the closing fence
        var closingFenceStart: String.Index?
        
        while tempIndex < input.endIndex {
            if input[tempIndex] == "`" {
                let fenceStart = tempIndex
                var closingTickCount = 0
                
                while tempIndex < input.endIndex && input[tempIndex] == "`" {
                    closingTickCount += 1
                    tempIndex = input.index(after: tempIndex)
                }
                
                if closingTickCount >= tickCount {
                    closingFenceStart = fenceStart
                    break
                }
            } else {
                tempIndex = input.index(after: tempIndex)
            }
        }
        
        let endIndex: String.Index
        if let closingStart = closingFenceStart {
            endIndex = closingStart
            // Advance current to after the closing fence
            current = tempIndex
        } else {
            // No closing fence found - treat as code block until EOF
            endIndex = input.endIndex
            current = input.endIndex
        }
        
        let range = startIndex..<(closingFenceStart != nil ? tempIndex : endIndex)
        let text = String(input[range])
        
        return MarkdownToken.fencedCodeBlock(text, at: range)
    }
    
    /// Tokenize inline code (`...`)
    private func tokenizeInlineCode(from startIndex: String.Index) -> MarkdownToken? {
        // Check if we have exactly one backtick
        if input[startIndex] != "`" {
            return nil
        }
        
        // Look for next backtick that's not escaped
        var tempIndex = input.index(after: startIndex)
        var foundEnd = false
        
        while tempIndex < input.endIndex {
            if input[tempIndex] == "`" {
                foundEnd = true
                break
            }
            // Skip over escaped backticks
            if input[tempIndex] == "\\" && tempIndex < input.endIndex {
                let nextIndex = input.index(after: tempIndex)
                if nextIndex < input.endIndex {
                    tempIndex = input.index(after: nextIndex)
                } else {
                    tempIndex = nextIndex
                }
            } else {
                tempIndex = input.index(after: tempIndex)
            }
        }
        
        if !foundEnd {
            return nil
        }
        
        // Include the closing backtick
        let endIndex = input.index(after: tempIndex)
        current = endIndex
        
        let range = startIndex..<endIndex
        let text = String(input[range])
        
        return MarkdownToken.inlineCode(text, at: range)
    }
    
    /// Tokenize consecutive text characters (including letters and numbers)
    private func tokenizeText(from startIndex: String.Index) {
        // First check if this might be a bare URL
        if tokenizeBareURLInText(from: startIndex) {
            return
        }
        
        var textContent = ""
        var currentIndex = current
        
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            // Check if this character should be treated as a separate token
            // Include both letters and numbers in text tokens
            if isSpecialCharacter(char) {
                break
            }
            
            textContent.append(char)
            currentIndex = input.index(after: currentIndex)
        }
        
        current = currentIndex
        let range = startIndex..<current
        tokens.append(MarkdownToken.text(textContent, at: range))
    }
    
    /// Tokenize consecutive number characters (only for pure numbers)
    private func tokenizeNumber(from startIndex: String.Index) {
        var numberContent = ""
        var currentIndex = current
        
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            // Only include digits in number tokens
            if !char.isNumber {
                break
            }
            
            numberContent.append(char)
            currentIndex = input.index(after: currentIndex)
        }
        
        current = currentIndex
        let range = startIndex..<current
        tokens.append(MarkdownToken.number(numberContent, at: range))
    }
    
    /// Check if a character is a special character that should be tokenized separately
    private func isSpecialCharacter(_ char: Character) -> Bool {
        switch char {
        case "#", "*", "_", "`", "-", "+", "=", "~", "^", "@", "|", ":", ";", "!", "?", ".", ",", ">", "<", "&", "\\", "/", "\"", "'", "[", "]", "(", ")", "{", "}", "$":
            return true
        case " ", "\t", "\n", "\r":
            return true
        default:
            return false
        }
    }
    
    /// Check if a number should be tokenized as text (mixed alphanumeric)
    private func shouldTokenizeAsText(from startIndex: String.Index) -> Bool {
        var currentIndex = current
        
        // Look ahead to see if we have letters mixed with numbers
        while currentIndex < input.endIndex {
            let char = input[currentIndex]
            
            if isSpecialCharacter(char) {
                break
            }
            
            if char.isLetter {
                return true // Found a letter, treat as text
            }
            
            currentIndex = input.index(after: currentIndex)
        }
        
        return false // Only digits found, treat as number
    }
    
    /// Tokenize escape sequences
    private func tokenizeEscapeSequence() -> Bool {
        let startIndex = current
        
        guard input[current] == "\\" else { return false }
        
        guard let nextIndex = input.index(current, offsetBy: 1, limitedBy: input.endIndex),
              nextIndex < input.endIndex else { return false }
        
        let nextChar = input[nextIndex]
        
        // Check if it's a valid escape sequence
        if isPunctuation(nextChar) {
            // For now, treat escape sequences as separate tokens
            // Parser layer will handle the semantic meaning
            addToken(.backslash, text: "\\", from: startIndex)
            return false
        }
        
        return false
    }
    
    /// Tokenize Unicode escape sequences
    private func tokenizeUnicodeEscape() -> Bool {
        let startIndex = current
        
        guard match("\\u") else { return false }
        
        current = input.index(current, offsetBy: 2)
        
        // Expect 4 hex digits
        var hexCount = 0
        while current < input.endIndex && 
              input[current].isHexDigit && 
              hexCount < 4 {
            current = input.index(after: current)
            hexCount += 1
        }
        
        if hexCount == 4 {
            // For now, treat as separate tokens
            // Parser layer will handle the semantic meaning
            current = startIndex
            addToken(.backslash, text: "\\", from: startIndex)
            return false
        }
        
        // Reset on failure
        current = startIndex
        return false
    }
    
    /// Tokenize autolinks and URLs
    private func tokenizeAutolink(from startIndex: String.Index) -> Bool {
        // Check if this is an autolink <URL> or <email>
        if input[startIndex] == "<" {
            return tokenizeAutolinkInBrackets(from: startIndex)
        }
        
        // Check if this is a bare URL
        return tokenizeBareURL(from: startIndex)
    }
    
    /// Tokenize autolinks in brackets <URL>
    private func tokenizeAutolinkInBrackets(from startIndex: String.Index) -> Bool {
        guard input[startIndex] == "<" else { return false }
        
        var tempIndex = input.index(after: startIndex)
        var urlContent = ""
        
        // Find the closing >
        while tempIndex < input.endIndex {
            let char = input[tempIndex]
            
            if char == ">" {
                // Found closing bracket
                let fullRange = startIndex..<input.index(after: tempIndex)
                let fullText = String(input[fullRange])
                
                // Check if this looks like a URL or email
                if isValidAutolinkContent(urlContent) {
                    // All bracketed URLs and emails are autolinks according to CommonMark
                    let token = MarkdownToken.autolink(fullText, at: fullRange)
                    tokens.append(token)
                    current = input.index(after: tempIndex)
                    return true
                }
                
                // Not a valid autolink, let HTML handler deal with it
                return false
            } else if char == " " || char == "\t" || char == "\n" || char == "\r" || char == "<" {
                // Invalid characters for autolinks
                return false
            }
            
            urlContent.append(char)
            tempIndex = input.index(after: tempIndex)
        }
        
        // No closing bracket found
        return false
    }
    
    /// Tokenize bare URLs (without brackets)
    private func tokenizeBareURL(from startIndex: String.Index) -> Bool {
        // This is more complex and depends on context
        // For now, we'll implement a simple version that looks for common URL patterns
        
        // Check if this starts with a URL scheme
        let remainingText = String(input[startIndex...])
        let urlPattern = /^(https?:\/\/[^\s<>\[\]]+)/
        
        if let match = remainingText.firstMatch(of: urlPattern) {
            let matchedText = String(match.1)
            let endIndex = input.index(startIndex, offsetBy: matchedText.count)
            let range = startIndex..<endIndex
            
            let token = MarkdownToken.url(matchedText, at: range)
            tokens.append(token)
            current = endIndex
            return true
        }
        
        return false
    }
    
    /// Tokenize bare email addresses (without brackets)
    private func tokenizeBareEmail(from startIndex: String.Index) -> Bool {
        // Look for email pattern in the remaining text
        let remainingText = String(input[startIndex...])
        let emailPattern = /^([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/
        
        if let match = remainingText.firstMatch(of: emailPattern) {
            let matchedText = String(match.1)
            let endIndex = input.index(startIndex, offsetBy: matchedText.count)
            let range = startIndex..<endIndex
            
            let token = MarkdownToken.email(matchedText, at: range)
            tokens.append(token)
            current = endIndex
            return true
        }
        
        return false
    }
    
    /// Check if the content looks like a valid autolink
    private func isValidAutolinkContent(_ content: String) -> Bool {
        // Email pattern
        if content.contains("@") {
            let emailPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
            return content.firstMatch(of: emailPattern) != nil
        }
        
        // URL pattern
        let urlPattern = /^[a-zA-Z][a-zA-Z0-9+.-]*:[^\s]*$/
        return content.firstMatch(of: urlPattern) != nil
    }
    
    /// Check if we're processing text that could be a URL or email
    private func tokenizeBareURLInText(from startIndex: String.Index) -> Bool {
        // Check if current position starts with http:// or https://
        let remainingText = String(input[startIndex...])
        
        if remainingText.hasPrefix("http://") || remainingText.hasPrefix("https://") {
            return tokenizeBareURL(from: startIndex)
        }
        
        // Check if this might be an email address
        if tokenizeBareEmail(from: startIndex) {
            return true
        }
        
        return false
    }

    /// Tokenize custom containers starting with ':::' at line start
    private func tokenizeCustomContainer(from startIndex: String.Index) -> Bool {
        guard isAtLineStart(index: startIndex), match(":::") else { return false }

        var tempIndex = input.index(startIndex, offsetBy: 3)

        // Scan for the closing ':::' at line start
        while tempIndex < input.endIndex {
            if isAtLineStart(index: tempIndex) && input[tempIndex...].hasPrefix(":::") {
                // Move to end of closing line
                var end = input.index(tempIndex, offsetBy: 3)
                while end < input.endIndex && input[end] != "\n" && input[end] != "\r" {
                    end = input.index(after: end)
                }
                if end < input.endIndex {
                    if input[end] == "\r" {
                        let next = input.index(after: end)
                        if next < input.endIndex && input[next] == "\n" {
                            end = input.index(after: next)
                        } else {
                            end = next
                        }
                    } else {
                        end = input.index(after: end)
                    }
                }
                let range = startIndex..<end
                let text = String(input[range])
                tokens.append(MarkdownToken.customContainer(text, at: range))
                current = end
                return true
            }
            tempIndex = input.index(after: tempIndex)
        }

        // No closing delimiter found - consume to EOF
        let range = startIndex..<input.endIndex
        let text = String(input[range])
        tokens.append(MarkdownToken.customContainer(text, at: range))
        current = input.endIndex
        return true
    }

    private func isAtLineStart(index: String.Index) -> Bool {
        if index == input.startIndex { return true }
        let prev = input[input.index(before: index)]
        return prev == "\n" || prev == "\r"
    }

    // ...existing code...
}

// MARK: - Character Extensions
extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
