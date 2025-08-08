//
//  ResizableSplitView.swift
//  CodeParserShowCase
//
//  A lightweight SwiftUI two-pane split view with a wide draggable handle
//  and proper resize cursor feedback on macOS.
//

#if canImport(SwiftUI)
  import SwiftUI
  #if os(macOS)
    import AppKit
  #endif

  struct ResizableSplitView<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing
    private let minLeading: CGFloat
    private let minTrailing: CGFloat
    private let initialProportion: CGFloat
    private let handleWidth: CGFloat
    private let showDividerLine: Bool

    @State private var proportion: CGFloat
    @State private var dragStartLeading: CGFloat? = nil
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var didPushCursor: Bool = false

    init(
      minLeading: CGFloat = 240,
      minTrailing: CGFloat = 280,
      initialProportion: CGFloat = 0.33,
      handleWidth: CGFloat = 5,
      showDividerLine: Bool = true,
      @ViewBuilder leading: () -> Leading,
      @ViewBuilder trailing: () -> Trailing
    ) {
      self.leading = leading()
      self.trailing = trailing()
      self.minLeading = minLeading
      self.minTrailing = minTrailing
      self.initialProportion = initialProportion
      self.handleWidth = handleWidth
      self.showDividerLine = showDividerLine
      self._proportion = State(initialValue: initialProportion)
    }

    var body: some View {
      GeometryReader { geo in
        let total = max(1, geo.size.width)
        let clampedLeading = clampLeadingWidth(total: total)
        let clampedTrailing = max(0, total - clampedLeading - handleWidth)

        HStack(spacing: 0) {
          leading
            .frame(width: clampedLeading)

          dividerHandle(total: total, leadingWidth: clampedLeading)
            .frame(width: handleWidth, height: nil, alignment: .center)
            .frame(maxHeight: .infinity)
            .zIndex(1)

          trailing
            .frame(width: clampedTrailing)
        }
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.9), value: proportion)
      }
    }

    private func dividerHandle(total: CGFloat, leadingWidth: CGFloat) -> some View {
      ZStack {
        // Only a 1px center separator; no visible wide background
        if showDividerLine {
          let baseOpacity: Double = isDragging ? 0.7 : (isHovering ? 0.5 : 0.28)
          Rectangle()
            .fill(separatorColor.opacity(baseOpacity))
            .frame(width: 1)
            .accessibilityLabel("Splitter")
        }
      }
      .contentShape(Rectangle())
      .background(separatorColor.opacity(0.001))  // near-invisible but hit-testable
      .gesture(dragGesture(total: total, startLeading: leadingWidth))
      .onHover { hovering in
        isHovering = hovering
        #if os(macOS)
          if hovering {
            if !didPushCursor {
              NSCursor.resizeLeftRight.push()
              didPushCursor = true
            }
          } else {
            if didPushCursor {
              NSCursor.pop()
              didPushCursor = false
            }
          }
        #endif
      }
      .onTapGesture(count: 2) {
        // Double-click to reset to initial proportion
        proportion = initialProportion
      }
    }

    private func dragGesture(total: CGFloat, startLeading: CGFloat) -> some Gesture {
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          isDragging = true
          if dragStartLeading == nil { dragStartLeading = startLeading }
          let base = dragStartLeading ?? startLeading
          let proposed = base + value.translation.width
          let minLead = minLeading
          let maxLead = max(minLead, total - minTrailing - handleWidth)
          let newLead = min(maxLead, max(minLead, proposed))
          let newProportion = max(0, min(1, newLead / total))
          proportion = newProportion
        }
        .onEnded { _ in
          isDragging = false
          dragStartLeading = nil
        }
    }

    private func clampLeadingWidth(total: CGFloat) -> CGFloat {
      let minLead = minLeading
      let maxLead = max(minLead, total - minTrailing - handleWidth)
      let raw = total * proportion
      return min(maxLead, max(minLead, raw))
    }
  }

  // MARK: - Platform Colors

  extension ResizableSplitView {
    fileprivate var separatorColor: Color {
      #if os(macOS)
        return Color(NSColor.separatorColor)
      #else
        return Color(UIColor.separator)
      #endif
    }
  }

#endif
