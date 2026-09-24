import AppKit

struct ResizeEdges: OptionSet {
    let rawValue: Int

    static let left = ResizeEdges(rawValue: 1 << 0)
    static let right = ResizeEdges(rawValue: 1 << 1)
    static let top = ResizeEdges(rawValue: 1 << 2)
    static let bottom = ResizeEdges(rawValue: 1 << 3)

    static let allHandles: [ResizeEdges] = [
        .left, .right, .top, .bottom,
        [.top, .left], [.top, .right], [.bottom, .left], [.bottom, .right],
    ]

    var isHorizontal: Bool { contains(.left) || contains(.right) }
    var isVertical: Bool { contains(.top) || contains(.bottom) }
}

// An invisible strip on one edge or corner of the player. A borderless window only
// gets a resize zone a few pixels wide, and the web view underneath overrides the
// resize cursor, so these handles give every edge and corner a wider grab area.
class ResizeHandleView: NSView {

    static let edgeThickness: CGFloat = 6
    static let cornerSize: CGFloat = 16

    let edges: ResizeEdges
    private var startFrame: NSRect?
    private var startMouse: NSPoint?
    private var trackingArea: NSTrackingArea?

    init(edges: ResizeEdges) {
        self.edges = edges
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func handleFrame(for edges: ResizeEdges, in bounds: NSRect) -> NSRect {
        let isCorner = edges.isHorizontal && edges.isVertical
        let side = isCorner ? cornerSize : edgeThickness

        let x: CGFloat
        let width: CGFloat
        if edges.contains(.left) {
            x = 0
            width = side
        } else if edges.contains(.right) {
            x = bounds.width - side
            width = side
        } else {
            x = cornerSize
            width = max(bounds.width - 2 * cornerSize, 0)
        }

        let y: CGFloat
        let height: CGFloat
        if edges.contains(.bottom) {
            y = 0
            height = side
        } else if edges.contains(.top) {
            y = bounds.height - side
            height = side
        } else {
            y = cornerSize
            height = max(bounds.height - 2 * cornerSize, 0)
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Mouse handling

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window = window as? PlayerWindow else { return }
        // Screen coordinates, because this view moves with the window while resizing.
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
        window.beginUserResize()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window as? PlayerWindow,
              let startFrame, let startMouse else { return }
        let mouse = NSEvent.mouseLocation
        window.resize(from: startFrame, edges: edges, by: NSPoint(x: mouse.x - startMouse.x, y: mouse.y - startMouse.y))
        cursor.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard startFrame != nil else { return }
        startFrame = nil
        startMouse = nil
        (window as? PlayerWindow)?.endUserResize()
    }

    // MARK: - Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    // The web view keeps setting its own cursor as the mouse moves, so set ours again
    // on every move over the handle.
    override func cursorUpdate(with event: NSEvent) {
        cursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        cursor.set()
    }

    private var cursor: NSCursor {
#if compiler(>=6.0)
        if #available(macOS 15.0, *) {
            return .frameResize(position: frameResizePosition, directions: .all)
        }
#endif
        if edges == .left || edges == .right { return .resizeLeftRight }
        if edges == .top || edges == .bottom { return .resizeUpDown }
        return .crosshair
    }

#if compiler(>=6.0)
    @available(macOS 15.0, *)
    private var frameResizePosition: NSCursor.FrameResizePosition {
        switch (edges.contains(.top), edges.contains(.bottom), edges.contains(.left), edges.contains(.right)) {
        case (true, _, true, _): return .topLeft
        case (true, _, _, true): return .topRight
        case (_, true, true, _): return .bottomLeft
        case (_, true, _, true): return .bottomRight
        case (true, _, _, _): return .top
        case (_, true, _, _): return .bottom
        case (_, _, true, _): return .left
        default: return .right
        }
    }
#endif
}
