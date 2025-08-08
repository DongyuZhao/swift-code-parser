#if os(macOS)
import SwiftUI
import AppKit

/// 轻量级代码编辑器封装，以便拿到光标行列信息
struct CodeEditorView: NSViewRepresentable {
  @Binding var text: String
  var onCaretChange: ((Int, Int) -> Void)? = nil // (line, column) 1-based
  var fontSize: CGFloat = NSFont.systemFontSize

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.hasHorizontalScroller = false
    scroll.autohidesScrollers = true
    scroll.drawsBackground = true

    let textView = NSTextView(frame: .zero)
    textView.delegate = context.coordinator
    textView.isRichText = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.usesFontPanel = false
    textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    textView.textContainerInset = NSSize(width: 6, height: 8)
    textView.string = text
    textView.backgroundColor = NSColor.textBackgroundColor
    textView.textColor = NSColor.textColor
    textView.isHorizontallyResizable = true
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width, .height]
    textView.minSize = NSSize(width: 0, height: 0)
  textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    if let container = textView.textContainer {
  container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
      container.widthTracksTextView = true
    }

    scroll.documentView = textView
    textView.frame = scroll.contentView.bounds
    return scroll
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    if let textView = nsView.documentView as? NSTextView, textView.string != text {
      textView.string = text
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  @MainActor
  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CodeEditorView
    init(_ parent: CodeEditorView) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
      guard let tv = notification.object as? NSTextView else { return }
      parent.text = tv.string
      reportCaret(tv)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let tv = notification.object as? NSTextView else { return }
      reportCaret(tv)
    }

    private func reportCaret(_ tv: NSTextView) {
      let nsText = tv.string as NSString
      let loc = tv.selectedRange().location
      guard loc <= nsText.length else { return }
      let prefix = nsText.substring(to: loc) as NSString
      let line = max(1, prefix.components(separatedBy: "\n").count)
      let lastNL = prefix.range(of: "\n", options: .backwards)
      let col: Int
      if lastNL.location != NSNotFound {
        col = loc - lastNL.location
      } else {
        col = loc + 1
      }
      parent.onCaretChange?(line, max(1, col))
    }
  }
}
#endif
