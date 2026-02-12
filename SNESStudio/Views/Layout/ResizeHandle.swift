import SwiftUI

enum ResizeDirection {
    case horizontal
    case vertical
}

struct ResizeHandle: View {
    let direction: ResizeDirection
    let onDrag: (CGFloat) -> Void

    @State private var isHovered = false

    var body: some View {
        Rectangle()
            .fill(isHovered ? SNESTheme.textDisabled : SNESTheme.border)
            .frame(
                width: direction == .horizontal ? SNESTheme.resizeHandleWidth : nil,
                height: direction == .vertical ? SNESTheme.resizeHandleWidth : nil
            )
            .contentShape(Rectangle().size(
                width: direction == .horizontal ? SNESTheme.resizeHitArea : 10000,
                height: direction == .vertical ? SNESTheme.resizeHitArea : 10000
            ))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering }
                if hovering {
                    if direction == .horizontal {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let delta = direction == .horizontal ? value.translation.width : value.translation.height
                        onDrag(delta)
                    }
            )
    }
}
