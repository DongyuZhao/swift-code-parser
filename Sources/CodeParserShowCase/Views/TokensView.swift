#if canImport(SwiftUI)
import SwiftUI
import CodeParserCore
import CodeParserCollection

struct TokensView: View {
  let parseResult: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Tokenization Results")
        .font(.headline)
        .padding(.horizontal)

      if let result = parseResult {
        if !result.errors.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text("Errors:")
              .font(.subheadline)
              .foregroundColor(.red)
            ForEach(Array(result.errors.enumerated()), id: \.offset) { _, error in
              Text("• \(error.message)")
                .font(.caption)
                .foregroundColor(.red)
            }
          }
          .padding(.horizontal)
        }

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(result.tokens.enumerated()), id: \.offset) { index, token in
              TokenRowView(index: index, token: token)
            }
          }
          .padding(.horizontal)
        }
      } else {
        Text("No parsing results")
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }
    }
  }
}

#endif

struct TokenRowView: View {
  let index: Int
  let token: any CodeToken<MarkdownTokenElement>

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text("\(index)")
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(width: 30, alignment: .trailing)

      VStack(alignment: .leading, spacing: 2) {
        Text(token.element.rawValue)
          .font(.caption)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.blue.opacity(0.2))
          .cornerRadius(4)

        if !token.text.isEmpty {
          Text(token.text.replacingOccurrences(of: "\n", with: "\\n"))
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
        }
      }

      Spacer()
    }
    .padding(.vertical, 2)
  }
}
