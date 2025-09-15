import CodeParserCore
import Foundation

/// Utility functions for calculating indentation information from tokens
/// These help with nested block parsing by providing precise column positions
package enum MarkdownIndentation {

  /// Calculate column positions from tokens at the start of a line
  /// Returns (leadingSpaces, columnAfterWhitespace, totalColumns)
  package static func calculateIndentation(from tokens: [any CodeToken<MarkdownTokenElement>]) -> (spaces: Int, column: Int, total: Int) {
    var spaces = 0
    var column = 0
    var tokenIndex = 0

    // Process leading whitespace tokens
    while tokenIndex < tokens.count && tokens[tokenIndex].element == .whitespace {
      let token = tokens[tokenIndex]
      for char in token.text {
        if char == " " {
          spaces += 1
          column += 1
        } else if char == "\t" {
          // Tab expands to next 4-column boundary
          let nextTabStop = ((column / 4) + 1) * 4
          spaces += (nextTabStop - column)
          column = nextTabStop
        }
      }
      tokenIndex += 1
    }

    return (spaces: spaces, column: column, total: column)
  }

  /// Find the column position of a specific marker character in the token stream
  /// Returns (found, markerColumn, afterMarkerColumn)
  package static func findMarkerPosition(tokens: [any CodeToken<MarkdownTokenElement>],
                                        marker: Character,
                                        afterWhitespace: Bool = true) -> (found: Bool, markerColumn: Int, afterMarkerColumn: Int) {
    var column = 0
    var tokenIndex = 0

    // Skip whitespace if requested
    if afterWhitespace {
      while tokenIndex < tokens.count && tokens[tokenIndex].element == .whitespace {
        column += calculateTokenWidth(tokens[tokenIndex])
        tokenIndex += 1
      }
    }

    // Look for marker in remaining tokens
    while tokenIndex < tokens.count {
      let token = tokens[tokenIndex]
      if token.element == .newline || token.element == .eof {
        break
      }

      if token.text.contains(marker) {
        // Find position within token
        for (index, char) in token.text.enumerated() {
          if char == marker {
            let markerColumn = column + index
            let afterMarkerColumn = column + index + 1
            return (found: true, markerColumn: markerColumn, afterMarkerColumn: afterMarkerColumn)
          }
        }
      }

      column += calculateTokenWidth(token)
      tokenIndex += 1
    }

    return (found: false, markerColumn: 0, afterMarkerColumn: 0)
  }

  /// Find the column position where content starts after a marker
  /// Handles optional space/tab after markers like "> " or "- "
  package static func findContentColumn(tokens: [any CodeToken<MarkdownTokenElement>],
                                       afterMarkerAt markerColumn: Int) -> Int {
    var column = 0
    var foundMarker = false

    for token in tokens {
      if token.element == .newline || token.element == .eof {
        break
      }

      let tokenStart = column
      let tokenEnd = column + calculateTokenWidth(token)

      // Check if marker is in this token
      if !foundMarker && tokenStart <= markerColumn && markerColumn < tokenEnd {
        foundMarker = true
        // Start from position after marker
        column = markerColumn + 1

        // Skip optional space/tab after marker if in same token
        let markerOffsetInToken = markerColumn - tokenStart
        if markerOffsetInToken + 1 < token.text.count {
          let charAfterMarker = token.text[token.text.index(token.text.startIndex, offsetBy: markerOffsetInToken + 1)]
          if charAfterMarker == " " || charAfterMarker == "\t" {
            column += 1
          }
        }
        continue
      }

      // If we found marker and this is next token, skip optional space/tab
      if foundMarker && token.element == .whitespace {
        let firstChar = token.text.first
        if firstChar == " " || firstChar == "\t" {
          return column + 1
        }
        return column
      }

      if foundMarker {
        return column
      }

      column = tokenEnd
    }

    return column
  }

  /// Calculate the width of a token in columns (handling tabs)
  private static func calculateTokenWidth(_ token: any CodeToken<MarkdownTokenElement>) -> Int {
    var width = 0
    for char in token.text {
      if char == "\t" {
        // Tab expands to next 4-column boundary
        let nextTabStop = ((width / 4) + 1) * 4
        width = nextTabStop
      } else {
        width += 1
      }
    }
    return width
  }

  /// Check if a line meets indentation requirements for block continuation
  /// Returns true if the line has enough indentation to continue the block
  package static func meetsIndentationRequirement(tokens: [any CodeToken<MarkdownTokenElement>],
                                                  requiredColumn: Int) -> Bool {
    let (_, column, _) = calculateIndentation(from: tokens)
    return column >= requiredColumn
  }

  /// Remove indentation from tokens up to specified column
  /// Returns new token array with indentation removed
  package static func removeIndentation(from tokens: [any CodeToken<MarkdownTokenElement>],
                                       upToColumn: Int) -> [any CodeToken<MarkdownTokenElement>] {
    var result: [any CodeToken<MarkdownTokenElement>] = []
    var column = 0
    var tokenIndex = 0

    // Skip tokens until we reach the target column
    while tokenIndex < tokens.count && column < upToColumn {
      let token = tokens[tokenIndex]
      let tokenWidth = calculateTokenWidth(token)

      if column + tokenWidth <= upToColumn {
        // Skip this entire token
        column += tokenWidth
        tokenIndex += 1
      } else {
        // Partially skip this token
        let charactersToSkip = upToColumn - column
        if charactersToSkip > 0 && token.element == .whitespace {
          // Create new token with remaining whitespace
          let remainingText = String(token.text.dropFirst(charactersToSkip))
          if !remainingText.isEmpty {
            // Note: This creates a synthetic token - in a real implementation
            // you might want to track the original token source position
            let syntheticRange = token.text.startIndex..<token.text.endIndex
            let newToken = MarkdownToken(element: .whitespace, text: remainingText, range: syntheticRange)
            result.append(newToken)
          }
        } else {
          // Keep the token as-is if we can't partially skip
          result.append(token)
        }
        tokenIndex += 1
        break
      }
    }

    // Add remaining tokens
    while tokenIndex < tokens.count {
      result.append(tokens[tokenIndex])
      tokenIndex += 1
    }

    return result
  }
}
