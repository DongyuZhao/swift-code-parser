import CodeParserCore
import CodeParserCollection

let input = "foo\n```\nbar\n```\nbaz"
let language = MarkdownLanguage()
let tokenizer = CodeTokenizer<MarkdownTokenElement>()
let tokens = tokenizer.tokenize(input, using: language.tokenBuilders)

print("=== INPUT ===")
print(input)
print("\n=== TOKENS ===")
for (i, token) in tokens.enumerated() {
    print("\(i): .\(token.element) '\(token.text)'")
}

print("\n=== LINES ===")
var currentLineTokens: [any CodeToken<MarkdownTokenElement>] = []
var lineNum = 0

for token in tokens {
    currentLineTokens.append(token)
    
    if token.element == .newline || token.element == .eof {
        print("Line \(lineNum): \(currentLineTokens.map { ".\($0.element) '\($0.text)'" }.joined(separator: ", "))")
        
        // Test fence recognition on the line with ```
        if lineNum == 1 {
            let line = MarkdownLine(tokens: currentLineTokens, lineNumber: lineNum)
            let builder = MarkdownFencedCodeBlockBuilder()
            print("Can start fenced code: \(builder.canStart(line: line))")
        }
        
        currentLineTokens = []
        lineNum += 1
        
        if token.element == .eof {
            break
        }
    }
}
