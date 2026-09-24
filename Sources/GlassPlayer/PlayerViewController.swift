import AppKit
import WebKit

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

class PlayerViewController: NSViewController {

    private(set) var webView: WKWebView!
    private var controlBar: ControlBarView!
    private var dragHandle: WindowDragView!
    private var trackingArea: NSTrackingArea?
    private var popupWindows: [NSWindow] = []

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "videoAspectRatio")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.borderWidth = 1.5
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor

        setupWebView()
        setupDragHandle()
        setupControlBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadYouTube()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        webView.frame = view.bounds
        layoutDragHandle()
        layoutControlBar()
        updateTrackingArea()
    }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let userContentController = config.userContentController
        userContentController.add(WeakScriptMessageHandler(delegate: self), name: "videoAspectRatio")
        userContentController.addUserScript(WKUserScript(
            source: Self.videoFullWindowModeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        view.addSubview(webView)
    }

    private func loadYouTube() {
        let url = URL(string: "https://www.youtube.com")!
        webView.load(URLRequest(url: url))
    }

    func loadURL(_ urlString: String) {
        var str = urlString
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://\(str)"
        }
        guard let url = URL(string: str) else { return }
        if !str.contains("/watch") {
            (view.window as? PlayerWindow)?.videoAspectRatio = nil
        }
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    private static let videoFullWindowModeScript = """
        (function() {
            if (!location.hostname.endsWith('youtube.com')) return;
            if (window.__ytPipInjected) return;
            window.__ytPipInjected = true;

            const css = document.createElement('style');
            css.id = 'yt-pip-style';
            css.textContent = `
                /* When on a video/watch page, make video fill the entire viewport */
                html[data-pip-mode] body {
                    overflow: hidden !important;
                }
                html[data-pip-mode] #page-manager,
                html[data-pip-mode] #content,
                html[data-pip-mode] ytd-app {
                    overflow: hidden !important;
                }
                html[data-pip-mode] #masthead-container,
                html[data-pip-mode] #masthead,
                html[data-pip-mode] tp-yt-app-header-layout,
                html[data-pip-mode] #header,
                html[data-pip-mode] #below,
                html[data-pip-mode] #secondary,
                html[data-pip-mode] #comments,
                html[data-pip-mode] #related,
                html[data-pip-mode] #meta,
                html[data-pip-mode] #info,
                html[data-pip-mode] #menu,
                html[data-pip-mode] ytd-watch-metadata,
                html[data-pip-mode] #description,
                html[data-pip-mode] #bottom-row,
                html[data-pip-mode] #top-row,
                html[data-pip-mode] .ytd-watch-flexy #columns #secondary,
                html[data-pip-mode] ytd-merch-shelf-renderer,
                html[data-pip-mode] #chips,
                html[data-pip-mode] #guide,
                html[data-pip-mode] #guide-button,
                html[data-pip-mode] ytd-mini-guide-renderer {
                    display: none !important;
                }
                html[data-pip-mode] ytd-watch-flexy {
                    --ytd-watch-flexy-sidebar-width: 0px !important;
                    --ytd-watch-flexy-panel-max-height: 0px !important;
                }
                html[data-pip-mode] #columns {
                    max-width: 100vw !important;
                    width: 100vw !important;
                }
                html[data-pip-mode] #primary {
                    max-width: 100vw !important;
                    width: 100vw !important;
                    padding: 0 !important;
                    margin: 0 !important;
                }
                html[data-pip-mode] #player-container-outer,
                html[data-pip-mode] #player-container-inner,
                html[data-pip-mode] #player-container,
                html[data-pip-mode] #ytd-player,
                html[data-pip-mode] #movie_player {
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    max-width: 100vw !important;
                    max-height: 100vh !important;
                    min-width: 100vw !important;
                    min-height: 100vh !important;
                    z-index: 9999 !important;
                    margin: 0 !important;
                    padding: 0 !important;
                }
                /* Sized but not repositioned: it must stay below the end-screen
                   overlay (a sibling in #movie_player) so recommendations stay clickable */
                html[data-pip-mode] .html5-video-container {
                    width: 100vw !important;
                    height: 100vh !important;
                    margin: 0 !important;
                    padding: 0 !important;
                }
                html[data-pip-mode] video {
                    width: 100vw !important;
                    height: 100vh !important;
                    object-fit: contain !important;
                }
                html[data-pip-mode] .ytp-chrome-bottom {
                    width: calc(100% - 24px) !important;
                }
                html[data-shorts-mode] #masthead-container,
                html[data-shorts-mode] #masthead,
                html[data-shorts-mode] #guide,
                html[data-shorts-mode] #guide-button,
                html[data-shorts-mode] ytd-mini-guide-renderer {
                    display: none !important;
                }
                html[data-shorts-mode] ytd-page-manager {
                    margin-top: 0 !important;
                }
                html[data-shorts-mode] ytd-shorts {
                    height: 100vh !important;
                }
            `;
            document.head.appendChild(css);

            function setModeAttr(name, on) {
                const de = document.documentElement;
                if (on && !de.hasAttribute(name)) {
                    de.setAttribute(name, '');
                } else if (!on && de.hasAttribute(name)) {
                    de.removeAttribute(name);
                }
            }

            function checkAndApply() {
                setModeAttr('data-pip-mode', location.pathname === '/watch');
                setModeAttr('data-shorts-mode', location.pathname.startsWith('/shorts/'));
            }

            // Keep the player at the user's desired audio state. YouTube auto-mutes
            // when it autoplays the next video (no fresh user gesture), which makes the
            // player silently mute itself between videos. We restore the user's choice,
            // while still respecting a deliberate mute the user makes themselves.
            let desiredMuted = false;
            let lastUserInteraction = 0;
            ['pointerdown', 'keydown', 'click'].forEach((evt) => {
                document.addEventListener(evt, () => { lastUserInteraction = Date.now(); }, true);
            });

            function enforceAudioState(video) {
                if (!video) return;
                // A mute with no recent interaction is YouTube's autoplay auto-mute.
                if (video.muted && !desiredMuted) video.muted = false;
            }

            document.addEventListener('volumechange', (e) => {
                const v = e.target;
                if (!v || v.tagName !== 'VIDEO') return;
                // Treat a mute/unmute as intentional only if it closely follows a real
                // user interaction; otherwise correct it back to the desired state.
                if (Date.now() - lastUserInteraction < 1000) {
                    desiredMuted = v.muted;
                } else {
                    enforceAudioState(v);
                }
            }, true);

            // Aspect ratio detection via ResizeObserver. We track a single <video>
            // element and only rebind when it is actually replaced. Rebinding on every
            // DOM mutation (as before) leaked a 'loadedmetadata' listener per mutation
            // and churned ResizeObservers, which froze the app during heavy scrolling.
            let lastRatio = 0;
            let observedVideo = null;
            let resizeObserver = null;

            function reportAspectRatio() {
                const p = location.pathname;
                if (p !== '/watch' && !p.startsWith('/shorts/')) return;
                const video = observedVideo;
                if (video && video.videoWidth && video.videoHeight) {
                    const ratio = video.videoWidth / video.videoHeight;
                    if (Math.abs(ratio - lastRatio) > 0.01) {
                        lastRatio = ratio;
                        window.webkit.messageHandlers.videoAspectRatio.postMessage({
                            width: video.videoWidth,
                            height: video.videoHeight
                        });
                    }
                }
            }

            function onLoadedMetadata() { reportAspectRatio(); }

            // Binds to `video` when given (the one actually playing). Without it, falls
            // back to the first <video> only when nothing usable is bound: YouTube keeps
            // hidden players (a previous watch page, feed previews) in the DOM, so the
            // first <video> is not necessarily the one on screen.
            function ensureVideoObserved(video) {
                if (!video) {
                    if (observedVideo && observedVideo.isConnected) return;
                    video = document.querySelector('video');
                }
                if (!video || video === observedVideo) return;
                if (observedVideo) observedVideo.removeEventListener('loadedmetadata', onLoadedMetadata);
                if (resizeObserver) resizeObserver.disconnect();
                observedVideo = video;
                resizeObserver = new ResizeObserver(reportAspectRatio);
                resizeObserver.observe(video);
                video.addEventListener('loadedmetadata', onLoadedMetadata);
                reportAspectRatio();
            }

            document.addEventListener('playing', (e) => {
                if (e.target.tagName !== 'VIDEO') return;
                enforceAudioState(e.target);
                ensureVideoObserved(e.target);
                reportAspectRatio();
            }, true);

            // A single throttled observer drives both mode toggling and video
            // (re)binding, so a burst of scroll-driven mutations collapses into one
            // pass at most every 250 ms. Throttling (not debouncing) means a steady
            // stream of mutations cannot postpone the pass indefinitely.
            let mutationTimer = 0;
            const observer = new MutationObserver(() => {
                if (mutationTimer) return;
                mutationTimer = setTimeout(() => {
                    mutationTimer = 0;
                    checkAndApply();
                    ensureVideoObserved();
                }, 250);
            });
            observer.observe(document.body, { childList: true, subtree: true });

            function onNavigation() {
                lastRatio = 0;
                checkAndApply();
                ensureVideoObserved();
            }

            const origPushState = history.pushState;
            history.pushState = function() {
                origPushState.apply(this, arguments);
                setTimeout(onNavigation, 100);
            };
            window.addEventListener('popstate', () => setTimeout(onNavigation, 100));
            window.addEventListener('yt-navigate-finish', () => setTimeout(onNavigation, 100));

            checkAndApply();
            ensureVideoObserved();
        })();
        """

    // MARK: - Drag Handle

    private func setupDragHandle() {
        dragHandle = WindowDragView()
        view.addSubview(dragHandle)
    }

    private func layoutDragHandle() {
        let handleHeight: CGFloat = 44
        let handleWidth = min(view.bounds.width * 0.85, 1200.0)
        dragHandle.frame = NSRect(x: 0, y: view.bounds.height - handleHeight, width: handleWidth, height: handleHeight)
    }

    // MARK: - Control Bar

    private func setupControlBar() {
        controlBar = ControlBarView()
        controlBar.alphaValue = 0
        controlBar.onOpacityChanged = { [weak self] value in
            (self?.view.window as? PlayerWindow)?.windowOpacity = CGFloat(value)
        }
        controlBar.onAlwaysOnTopToggled = { [weak self] in
            guard let win = self?.view.window as? PlayerWindow else { return }
            win.isAlwaysOnTop.toggle()
            self?.controlBar.updateAlwaysOnTop(win.isAlwaysOnTop)
        }
        controlBar.onClickThroughToggled = { [weak self] in
            guard let win = self?.view.window as? PlayerWindow else { return }
            win.isClickThrough.toggle()
            self?.controlBar.updateClickThrough(win.isClickThrough)
            if win.isClickThrough { self?.hideControlBar() }
        }
        controlBar.onBack = { [weak self] in self?.goBack() }
        controlBar.onForward = { [weak self] in self?.goForward() }
        controlBar.onHome = { [weak self] in self?.loadURL("https://www.youtube.com") }
        controlBar.onClose = { [weak self] in
            self?.view.window?.close()
        }
        view.addSubview(controlBar)
        layoutControlBar()
    }

    private func layoutControlBar() {
        let barHeight: CGFloat = 44
        controlBar.frame = NSRect(x: 0, y: view.bounds.height - barHeight, width: view.bounds.width, height: barHeight)
    }

    // MARK: - Hover tracking

    private func updateTrackingArea() {
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved],
            owner: self
        )
        view.addTrackingArea(trackingArea!)
    }

    private var isClickThroughActive: Bool {
        (view.window as? PlayerWindow)?.isClickThrough ?? false
    }

    override func mouseEntered(with event: NSEvent) {
        if !isClickThroughActive { showControlBar() }
    }

    override func mouseExited(with event: NSEvent) {
        hideControlBar()
    }

    override func mouseMoved(with event: NSEvent) {
        if isClickThroughActive { return }
        let loc = view.convert(event.locationInWindow, from: nil)
        let topRegion = view.bounds.height - 60
        if loc.y > topRegion {
            showControlBar()
        }
    }

    private func showControlBar() {
        guard controlBar.alphaValue < 1 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            controlBar.animator().alphaValue = 1
        }
    }

    private func hideControlBar() {
        guard controlBar.alphaValue > 0 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            controlBar.animator().alphaValue = 0
        }
    }

    func syncControlBarState() {
        guard let win = view.window as? PlayerWindow else { return }
        controlBar.updateOpacity(Float(win.windowOpacity))
        controlBar.updateAlwaysOnTop(win.isAlwaysOnTop)
        controlBar.updateClickThrough(win.isClickThrough)
    }
}

// MARK: - NSWindowDelegate

extension PlayerViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        if popupWindows.contains(where: { $0 === closedWindow }) {
            popupWindows.removeAll { $0 === closedWindow }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.webView.reload()
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension PlayerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView != self.webView else { return }
        let url = webView.url?.absoluteString ?? ""
        if url.contains("youtube.com") && !url.contains("accounts.google.com") && !url.contains("signin") {
            for win in popupWindows { win.close() }
            popupWindows.removeAll()
            self.webView.reload()
        }
    }
}

// MARK: - WKScriptMessageHandler

extension PlayerViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "videoAspectRatio",
              let body = message.body as? [String: Any],
              let width = body["width"] as? Double,
              let height = body["height"] as? Double,
              width > 0, height > 0,
              let window = view.window as? PlayerWindow else { return }

        let newRatio = width / height
        window.videoAspectRatio = newRatio

        if window.inLiveResize { return }
        window.snapToAspectRatio()
    }
}

// MARK: - WKUIDelegate

extension PlayerViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        popup.title = "Sign In"
        popup.center()
        popup.level = .floating
        popup.appearance = NSAppearance(named: .aqua)

        let popupWebView = WKWebView(frame: .zero, configuration: configuration)
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self
        popupWebView.customUserAgent = self.webView.customUserAgent
        popup.contentView = popupWebView
        popup.delegate = self
        popup.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        popupWindows.append(popup)

        return popupWebView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let win = popupWindows.first(where: { ($0.contentView as? WKWebView) == webView }) {
            win.close()
            popupWindows.removeAll { $0 === win }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.webView.reload()
        }
    }
}
