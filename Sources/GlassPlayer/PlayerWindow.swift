import AppKit

class PlayerWindow: NSWindow {

    private var clickThroughEnabled = false
    private var observers: [Any] = []
    var videoAspectRatio: Double?

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
        backgroundColor = .clear
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
