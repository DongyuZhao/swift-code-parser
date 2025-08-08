#if canImport(SwiftUI)
import SwiftUI
import Foundation

struct RichTextView: View {
  let markdown: String

  var body: some View {
    ScrollView {
      if let attr = try? AttributedString(markdown: markdown) {
        Text(attr)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
      } else {
        Text(markdown)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
      }
    }
  }
}
#endif
