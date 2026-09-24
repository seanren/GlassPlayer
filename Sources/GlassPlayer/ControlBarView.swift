import AppKit

class ControlBarView: NSView {

    var onOpacityChanged: ((Float) -> Void)?
    var onAlwaysOnTopToggled: (() -> Void)?
    var onClickThroughToggled: (() -> Void)?
    var onClose: (() -> Void)?
    var onHome: (() -> Void)?
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?

    private var opacitySlider: NSSlider!
    private var pinButton: NSButton!
    private var clickThroughButton: NSButton!
    private var closeButton: NSButton!
    private var homeButton: NSButton!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var opacityLabel: NSTextField!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor

        closeButton = makeButton(symbol: "xmark.circle.fill", action: #selector(closeTapped))
        closeButton.contentTintColor = .systemRed

        pinButton = makeButton(symbol: "pin.fill", action: #selector(pinTapped))
        pinButton.toolTip = "Always on Top"
        pinButton.contentTintColor = .systemYellow

        clickThroughButton = makeButton(symbol: "cursorarrow.click.2", action: #selector(clickThroughTapped))
        clickThroughButton.toolTip = "Click-Through Mode"
        clickThroughButton.contentTintColor = .white

        backButton = makeButton(symbol: "chevron.left", action: #selector(backTapped))
        backButton.toolTip = "Back"

        forwardButton = makeButton(symbol: "chevron.right", action: #selector(forwardTapped))
        forwardButton.toolTip = "Forward"

        homeButton = makeButton(symbol: "house.fill", action: #selector(homeTapped))
        homeButton.toolTip = "YouTube Home"
        homeButton.contentTintColor = .systemBlue

        opacityLabel = NSTextField(labelWithString: "Opacity")
        opacityLabel.font = .systemFont(ofSize: 11, weight: .medium)
        opacityLabel.textColor = .white

        opacitySlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacityChanged))
        opacitySlider.controlSize = .small

        addSubview(closeButton)
        addSubview(pinButton)
        addSubview(clickThroughButton)
        addSubview(backButton)
        addSubview(forwardButton)
        addSubview(homeButton)
        addSubview(opacityLabel)
        addSubview(opacitySlider)
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let y: CGFloat = (h - 24) / 2
        var x: CGFloat = 8

        closeButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 32

        pinButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 32

        clickThroughButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 36

        backButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 28

        forwardButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 28

        homeButton.frame = NSRect(x: x, y: y, width: 24, height: 24)
        x += 36

        opacityLabel.sizeToFit()
        opacityLabel.frame.origin = NSPoint(x: x, y: (h - opacityLabel.frame.height) / 2)
        x += opacityLabel.frame.width + 8

        let sliderWidth = min(bounds.width - x - 16, 200)
        opacitySlider.frame = NSRect(x: x, y: (h - 20) / 2, width: max(sliderWidth, 80), height: 20)
    }

    private func makeButton(symbol: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.target = self
        btn.action = action
        btn.contentTintColor = .white
        return btn
    }

    @objc private func closeTapped() { onClose?() }

    @objc private func pinTapped() { onAlwaysOnTopToggled?() }

    @objc private func clickThroughTapped() { onClickThroughToggled?() }

    @objc private func backTapped() { onBack?() }

    @objc private func forwardTapped() { onForward?() }

    @objc private func homeTapped() { onHome?() }

    @objc private func opacityChanged() {
        onOpacityChanged?(opacitySlider.floatValue)
    }

    func updateOpacity(_ value: Float) {
        opacitySlider.floatValue = value
    }

    func updateAlwaysOnTop(_ isOn: Bool) {
        pinButton.contentTintColor = isOn ? .systemYellow : .white
        pinButton.image = NSImage(
            systemSymbolName: isOn ? "pin.fill" : "pin.slash",
            accessibilityDescription: nil
        )
    }

    func updateClickThrough(_ isOn: Bool) {
        clickThroughButton.contentTintColor = isOn ? .systemGreen : .white
    }
}
