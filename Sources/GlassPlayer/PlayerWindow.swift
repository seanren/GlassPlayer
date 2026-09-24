import AppKit

class PlayerWindow: NSWindow {

    private var clickThroughEnabled = false
    private(set) var isUserResizing = false
    private var observers: [Any] = []
    var videoAspectRatio: Double? {
        didSet { updateResizeConstraint() }
    }

    override var canBecomeKey: Bool { !clickThroughEnabled }
    override var canBecomeMain: Bool { !clickThroughEnabled }

    convenience init() {
        let settings = AppSettings.shared
        let frame = settings.windowFrame ?? NSRect(x: 100, y: 100, width: 640, height: 400)
        self.init(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        // Nearly (not fully) clear: macOS passes clicks on fully transparent pixels to
        // the window below, which made the rounded corners impossible to grab.
        backgroundColor = NSColor(white: 0, alpha: 0.01)
        hasShadow = true
        isMovableByWindowBackground = true
        minSize = NSSize(width: 320, height: 200)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        alphaValue = CGFloat(settings.opacity)
        level = settings.alwaysOnTop ? .floating : .normal
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 20
        contentView?.layer?.masksToBounds = true

        let moveObs = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: self, queue: nil
        ) { [weak self] _ in self?.saveFrame() }
        let resizeObs = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: self, queue: nil
        ) { [weak self] _ in self?.saveFrame() }
        let endResizeObs = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification, object: self, queue: nil
        ) { [weak self] _ in self?.snapToAspectRatio() }
        observers = [moveObs, resizeObs, endResizeObs]
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // Keeps the video's shape while the user drags any edge or corner. Without it,
    // snapToAspectRatio recomputes the height from the width on release, so a drag
    // on the top or bottom edge snapped straight back to the old size.
    private func updateResizeConstraint() {
        if let ratio = videoAspectRatio, ratio > 0 {
            contentAspectRatio = NSSize(width: ratio, height: 1)
        } else {
            // Setting resize increments clears the aspect-ratio constraint.
            contentResizeIncrements = NSSize(width: 1, height: 1)
        }
    }

    func beginUserResize() {
        isUserResizing = true
    }

    func endUserResize() {
        isUserResizing = false
        snapToAspectRatio()
    }

    // Resizes from a drag on a ResizeHandleView. The opposite edge stays put and the
    // window keeps the video's shape, within the minimum size and the screen.
    func resize(from start: NSRect, edges: ResizeEdges, by delta: NSPoint) {
        var width = start.width
        var height = start.height
        if edges.contains(.left) { width -= delta.x }
        if edges.contains(.right) { width += delta.x }
        if edges.contains(.bottom) { height -= delta.y }
        if edges.contains(.top) { height += delta.y }
        width = max(width, 1)
        height = max(height, 1)

        let maxSize = (screen ?? NSScreen.main)?.visibleFrame.size
            ?? NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if let ratio = videoAspectRatio.map({ CGFloat($0) }), ratio > 0 {
            // An edge drives the other side; a corner follows whichever side moved further.
            if edges.isHorizontal && (!edges.isVertical || width / ratio >= height) {
                height = width / ratio
            } else {
                width = height * ratio
            }
            // Scale both sides together so the limits don't change the shape.
            let scaleUp = max(minSize.width / width, minSize.height / height, 1)
            width *= scaleUp
            height *= scaleUp
            let scaleDown = min(maxSize.width / width, maxSize.height / height, 1)
            width *= scaleDown
            height *= scaleDown
        } else {
            width = min(max(width, minSize.width), maxSize.width)
            height = min(max(height, minSize.height), maxSize.height)
        }

        let x: CGFloat
        if edges.contains(.left) {
            x = start.maxX - width
        } else if edges.contains(.right) {
            x = start.minX
        } else {
            x = start.midX - width / 2
        }
        let y = edges.contains(.top) ? start.minY : start.maxY - height

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    func snapToAspectRatio() {
        guard let ratio = videoAspectRatio, ratio > 0 else { return }
        let currentFrame = frame
        let visible = (screen ?? NSScreen.main)?.visibleFrame
        var newWidth = currentFrame.width
        var newHeight = newWidth / CGFloat(ratio)
        if let visible, newHeight > visible.height {
            newHeight = visible.height
            newWidth = newHeight * CGFloat(ratio)
        }
        if newHeight < minSize.height {
            newHeight = minSize.height
            newWidth = newHeight * CGFloat(ratio)
        }
        if abs(currentFrame.height - newHeight) < 2, abs(currentFrame.width - newWidth) < 2 { return }
        var newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + (currentFrame.height - newHeight),
            width: newWidth,
            height: newHeight
        )
        if let visible {
            if newFrame.maxX > visible.maxX { newFrame.origin.x = visible.maxX - newFrame.width }
            if newFrame.minX < visible.minX { newFrame.origin.x = visible.minX }
            if newFrame.maxY > visible.maxY { newFrame.origin.y = visible.maxY - newFrame.height }
            if newFrame.minY < visible.minY { newFrame.origin.y = visible.minY }
        }
        setFrame(newFrame, display: true, animate: true)
    }

    var isAlwaysOnTop: Bool {
        get { level == .floating }
        set {
            level = newValue ? .floating : .normal
            AppSettings.shared.alwaysOnTop = newValue
        }
    }

    var isClickThrough: Bool {
        get { clickThroughEnabled }
        set {
            clickThroughEnabled = newValue
            ignoresMouseEvents = newValue
            AppSettings.shared.clickThrough = newValue
        }
    }

    var windowOpacity: CGFloat {
        get { alphaValue }
        set {
            alphaValue = newValue
            AppSettings.shared.opacity = Float(newValue)
        }
    }

    private func saveFrame() {
        AppSettings.shared.windowFrame = frame
    }
}
