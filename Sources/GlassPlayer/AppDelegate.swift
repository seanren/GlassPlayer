import AppKit
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var playerWindow: PlayerWindow!
    var playerVC: PlayerViewController!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        setupWindow()
        setupStatusBarItem()
        setupMainMenu()

        playerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        playerVC.syncControlBarState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPlayer()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !playerWindow.isVisible {
            showPlayer()
        }
    }

    // MARK: - Window Setup

    private func setupWindow() {
        playerWindow = PlayerWindow()
        playerVC = PlayerViewController()
        playerWindow.contentViewController = playerVC
    }

    // MARK: - Status Bar

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "GlassPlayer")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Player", action: #selector(showPlayer), keyEquivalent: ""))
        menu.addItem(.separator())

        let opacityItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacitySubmenu = NSMenu()
        for pct in [100, 80, 60, 40, 20] {
            let item = NSMenuItem(title: "\(pct)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.tag = pct
            item.target = self
            opacitySubmenu.addItem(item)
        }
        opacityItem.submenu = opacitySubmenu
        menu.addItem(opacityItem)

        let pinItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "t")
        pinItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(pinItem)

        let clickItem = NSMenuItem(title: "Click-Through Mode", action: #selector(toggleClickThrough), keyEquivalent: "k")
        clickItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(clickItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Go to YouTube Home", action: #selector(goHome), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Load Playlist URL…", action: #selector(loadPlaylistURL), keyEquivalent: ""))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit GlassPlayer", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About GlassPlayer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit GlassPlayer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let pinItem = NSMenuItem(title: "Toggle Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "t")
        pinItem.keyEquivalentModifierMask = [.command, .shift]
        pinItem.target = self
        viewMenu.addItem(pinItem)

        let ctItem = NSMenuItem(title: "Toggle Click-Through", action: #selector(toggleClickThrough), keyEquivalent: "k")
        ctItem.keyEquivalentModifierMask = [.command, .shift]
        ctItem.target = self
        viewMenu.addItem(ctItem)

        viewMenu.addItem(.separator())

        let incOpacity = NSMenuItem(title: "Increase Opacity", action: #selector(increaseOpacity), keyEquivalent: "=")
        incOpacity.keyEquivalentModifierMask = [.command]
        incOpacity.target = self
        viewMenu.addItem(incOpacity)

        let decOpacity = NSMenuItem(title: "Decrease Opacity", action: #selector(decreaseOpacity), keyEquivalent: "-")
        decOpacity.keyEquivalentModifierMask = [.command]
        decOpacity.target = self
        viewMenu.addItem(decOpacity)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let navMenuItem = NSMenuItem()
        let navMenu = NSMenu(title: "Navigate")

        let backItem = NSMenuItem(title: "Back", action: #selector(goBack), keyEquivalent: "[")
        backItem.target = self
        navMenu.addItem(backItem)

        let fwdItem = NSMenuItem(title: "Forward", action: #selector(goForward), keyEquivalent: "]")
        fwdItem.target = self
        navMenu.addItem(fwdItem)

        navMenu.addItem(.separator())

        let homeItem = NSMenuItem(title: "YouTube Home", action: #selector(goHome), keyEquivalent: "h")
        homeItem.keyEquivalentModifierMask = [.command, .shift]
        homeItem.target = self
        navMenu.addItem(homeItem)

        let urlItem = NSMenuItem(title: "Load Playlist URL…", action: #selector(loadPlaylistURL), keyEquivalent: "l")
        urlItem.target = self
        navMenu.addItem(urlItem)

        navMenuItem.submenu = navMenu
        mainMenu.addItem(navMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func showPlayer() {
        if playerWindow.isClickThrough {
            playerWindow.isClickThrough = false
            playerVC.syncControlBarState()
        }
        playerWindow.level = .floating
        playerWindow.orderFrontRegardless()
        playerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if !playerWindow.isAlwaysOnTop {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.playerWindow.level = .normal
            }
        }
    }

    @objc private func toggleAlwaysOnTop() {
        playerWindow.isAlwaysOnTop.toggle()
        playerVC.syncControlBarState()
    }

    @objc private func toggleClickThrough() {
        playerWindow.isClickThrough.toggle()
        playerVC.syncControlBarState()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        let value = CGFloat(sender.tag) / 100.0
        playerWindow.windowOpacity = value
        playerVC.syncControlBarState()
    }

    @objc private func increaseOpacity() {
        let current = playerWindow.windowOpacity
        playerWindow.windowOpacity = min(current + 0.1, 1.0)
        playerVC.syncControlBarState()
    }

    @objc private func decreaseOpacity() {
        let current = playerWindow.windowOpacity
        playerWindow.windowOpacity = max(current - 0.1, 0.1)
        playerVC.syncControlBarState()
    }

    @objc private func goBack() { playerVC.goBack() }
    @objc private func goForward() { playerVC.goForward() }

    @objc private func goHome() {
        playerVC.loadURL("https://www.youtube.com")
    }

    @objc private func loadPlaylistURL() {
        if playerWindow.isClickThrough {
            playerWindow.isClickThrough = false
            playerVC.syncControlBarState()
        }
        playerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Load YouTube URL"
        alert.informativeText = "Enter a YouTube playlist or video URL:"
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        input.placeholderString = "https://www.youtube.com/playlist?list=..."
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let url = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty {
                playerVC.loadURL(url)
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
