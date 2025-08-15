import CodeParserCore

public enum MarkdownTokenMode {
    case normal // Normal mode for parsing
    case code // Code block mode for parsing
    case html // HTML mode for parsing
    case autolink // Autolink mode for parsing
}

public class MarkdownTokenState: CodeTokenState {
    public typealias Token = MarkdownTokenElement

    public var modes: [MarkdownTokenMode] // The token parsing mode stack for Markdown tokenization

    public init() {
        self.modes = [.normal]
    }
}

extension Array where Element == MarkdownTokenMode {
    mutating func push(_ mode: MarkdownTokenMode) {
        self.append(mode)
    }

    @discardableResult
    mutating func pop() -> MarkdownTokenMode? {
        return self.popLast()
    }

    func peek() -> MarkdownTokenMode? {
        return self.last
    }

    var top: MarkdownTokenMode? {
        return self.last
    }
}
