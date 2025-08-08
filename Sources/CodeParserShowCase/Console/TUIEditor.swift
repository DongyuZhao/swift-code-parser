#if !canImport(SwiftUI)
import Foundation
import CodeParserCore
import CodeParserCollection

#if os(macOS)
import Darwin
#else
import Glibc
#endif

private struct TerminalRawMode {
  private var orig = termios()
  private(set) var enabled = false

  init() {
    var t = termios()
    if tcgetattr(STDIN_FILENO, &t) == -1 { return }
    orig = t
    // raw mode (inspired by "kilo" editor)
    t.c_iflag &= ~(tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP))
    t.c_oflag &= ~tcflag_t(OPOST)
    t.c_cflag |= tcflag_t(CS8)
    t.c_lflag &= ~(tcflag_t(ECHO | ICANON | IEXTEN | ISIG))
    t.c_cc.16 /* VMIN */ = 0
    t.c_cc.17 /* VTIME */ = 1
    if tcsetattr(STDIN_FILENO, TCSAFLUSH, &t) == -1 { return }
    enabled = true
  }

  mutating func disable() {
    if enabled { _ = withUnsafePointer(to: orig) { tcsetattr(STDIN_FILENO, TCSAFLUSH, UnsafePointer(mutating: $0)) } }
    enabled = false
  }

  deinit { var m = self; m.disable() }
}

private struct WinSize { let cols: Int; let rows: Int }

private func getWindowSize() -> WinSize {
  var ws = winsize()
  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 {
    return WinSize(cols: Int(ws.ws_col), rows: Int(ws.ws_row))
  }
  return WinSize(cols: 80, rows: 24)
}

private enum Key {
  case char(Character)
  case enter
  case backspace
  case arrowUp, arrowDown, arrowLeft, arrowRight
  case ctrl(Character)
  case unknown
}

private func readKey() -> Key {
  var c: UInt8 = 0
  if read(STDIN_FILENO, &c, 1) != 1 { return .unknown }
  if c == 13 { return .enter }
  if c == 127 { return .backspace }
  if c == 27 { // ESC sequence
    var seq = [UInt8](repeating: 0, count: 2)
    if read(STDIN_FILENO, &seq, 2) == 2 {
      if seq[0] == 91 { // '['
        switch seq[1] {
        case 65: return .arrowUp
        case 66: return .arrowDown
        case 67: return .arrowRight
        case 68: return .arrowLeft
        default: break
        }
      }
    }
    return .unknown
  }
  if c <= 26 { // Ctrl+A .. Ctrl+Z
    let ch = Character(UnicodeScalar(c + 96))
    return .ctrl(ch)
  }
  return .char(Character(UnicodeScalar(c)))
}

private final class EditorBuffer {
  var lines: [String] = [""]
  var cx = 0
  var cy = 0

  var text: String { lines.joined(separator: "\n") }

  func insert(_ ch: Character) {
    guard cy < lines.count else { return }
    var line = lines[cy]
    let idx = line.index(line.startIndex, offsetBy: max(0, min(cx, line.count)))
    line.insert(ch, at: idx)
    lines[cy] = line
    cx += 1
  }

  func newline() {
    guard cy < lines.count else { return }
    let line = lines[cy]
    let splitIdx = line.index(line.startIndex, offsetBy: max(0, min(cx, line.count)))
    let left = String(line[..<splitIdx])
    let right = String(line[splitIdx...])
    lines[cy] = left
    lines.insert(right, at: cy + 1)
    cy += 1
    cx = 0
  }

  func backspace() {
    guard cy < lines.count else { return }
    if cx > 0 {
      var line = lines[cy]
      let idx = line.index(line.startIndex, offsetBy: cx)
      line.remove(at: line.index(before: idx))
      lines[cy] = line
      cx -= 1
    } else if cy > 0 {
      // join with previous line
      let prevLen = lines[cy - 1].count
      lines[cy - 1] += lines[cy]
      lines.remove(at: cy)
      cy -= 1
      cx = prevLen
    }
  }

  func moveLeft() { if cx > 0 { cx -= 1 } else if cy > 0 { cy -= 1; cx = lines[cy].count } }
  func moveRight() { if cy < lines.count { if cx < lines[cy].count { cx += 1 } else if cy + 1 < lines.count { cy += 1; cx = 0 } } }
  func moveUp() { if cy > 0 { cy -= 1; cx = min(cx, lines[cy].count) } }
  func moveDown() { if cy + 1 < lines.count { cy += 1; cx = min(cx, lines[cy].count) } }
}

final class TUIEditor {
  private var raw = TerminalRawMode()
  private let language = MarkdownLanguage()
  private let parser: CodeParser<MarkdownNodeElement, MarkdownTokenElement>
  private var buf = EditorBuffer()
  private var lastParsed: CodeParseResult<MarkdownNodeElement, MarkdownTokenElement>?
  private var activeRightPane = 0 // 0 tokens, 1 stats

  init() { parser = CodeParser(language: language) }

  func run() {
    defer { cleanup() }
    drawWelcome()
    while true {
      draw()
      switch readKey() {
      case .ctrl("q"): return
      case .ctrl("p"): parse()
      case .ctrl("t"): activeRightPane = (activeRightPane + 1) % 2
      case .enter: buf.newline()
      case .backspace: buf.backspace()
      case .arrowLeft: buf.moveLeft()
      case .arrowRight: buf.moveRight()
      case .arrowUp: buf.moveUp()
      case .arrowDown: buf.moveDown()
      case .char(let ch): buf.insert(ch)
      default: break
      }
    }
  }

  private func parse() {
    lastParsed = parser.parse(buf.text, language: language)
  }

  private func drawWelcome() {
    // Clear once
    write("\u{001B}[2J\u{001B}[H")
  }

  private func draw() {
    let ws = getWindowSize()
    let rows = ws.rows
    let cols = ws.cols
    let leftCols = max(10, cols * 2 / 3)
    let rightCols = cols - leftCols - 1

    // Hide cursor
    write("\u{001B}[?25l")
    // Move home
    write("\u{001B}[H")

    // Draw editor (left)
    for r in 0..<(rows - 2) {
      let line = r < buf.lines.count ? buf.lines[r] : ""
      let visible = String(line.prefix(leftCols))
      write(visible)
      // Fill to separator
      if visible.count < leftCols { write(String(repeating: " ", count: leftCols - visible.count)) }
      // Separator
      write("│")
      // Right pane
      drawRightPaneLine(row: r, height: rows - 2, width: rightCols)
      // EOL
      if r < rows - 3 { write("\r\n") }
    }

    // Status bar
    write("\r\n")
    let statusLeft = "^Q Quit  ^P Parse  ^T Toggle Pane   Ln \(buf.cy + 1), Col \(buf.cx + 1)"
    let status = statusLeft.padding(toLength: cols, withPad: " ", startingAt: 0)
    write("\u{001B}[7m" + String(status.prefix(cols)) + "\u{001B}[0m")
    write("\r\n")
    let msg = lastParsed == nil ? "Type to edit. Press ^P to parse Markdown." : rightPaneTitle()
    write(String(msg.padding(toLength: cols, withPad: " ", startingAt: 0).prefix(cols)))

    // Position cursor
    let cursorRow = min(buf.cy, rows - 3) + 1
    let cursorCol = min(buf.cx, leftCols) + 1
    write(String(format: "\u{001B}[%d;%dH", cursorRow, cursorCol))
    // Show cursor
    write("\u{001B}[?25h")
    fflush(stdout)
  }

  private func rightPaneTitle() -> String {
    switch activeRightPane {
    case 0: return "Tokens view"
    default: return "Node statistics"
    }
  }

  private func drawRightPaneLine(row: Int, height: Int, width: Int) {
    guard width > 0 else { return }
    let pad = { (s: String) -> String in String(s.padding(toLength: width, withPad: " ", startingAt: 0).prefix(width)) }
    if lastParsed == nil {
      if row == 0 { write(pad("Tokens/Stats will appear here after ^P")) } else { write(pad("")) }
      return
    }
    let result = lastParsed!
    switch activeRightPane {
    case 0:
      // Tokens list
      if row == 0 { write(pad("Tokens (\(result.tokens.count))")); return }
      let idx = row - 1
      if idx >= 0 && idx < result.tokens.count {
        let t = result.tokens[idx]
        let text = t.text.replacingOccurrences(of: "\n", with: "\\n")
        let preview = text.count > 20 ? String(text.prefix(20)) + "…" : text
        write(pad("\(t.element.rawValue): \(preview)"))
      } else {
        write(pad(""))
      }
    default:
      // Simple node statistics
      struct Counter { static func counts(_ n: CodeNode<MarkdownNodeElement>, _ c: inout [MarkdownNodeElement:Int]) { c[n.element, default: 0] += 1; for ch in n.children { counts(ch, &c) } } }
      var counts: [MarkdownNodeElement:Int] = [:]
      Counter.counts(result.root, &counts)
      let sorted = counts.sorted { $0.value > $1.value }
      if row == 0 { write(pad("Nodes: \(sorted.reduce(0){$0+$1.value})")); return }
      let idx = row - 1
      if idx >= 0 && idx < sorted.count {
        let item = sorted[idx]
        write(pad("\(item.key.rawValue): \(item.value)"))
      } else { write(pad("")) }
    }
  }

  private func cleanup() {
    // Clear screen, show cursor, move to bottom
    write("\u{001B}[2J\u{001B}[H\u{001B}[?25h")
  }
}

@inline(__always) private func write(_ s: String) { _ = fputs(s, stdout) }

#endif
