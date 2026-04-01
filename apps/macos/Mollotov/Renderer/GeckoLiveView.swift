import AppKit

/// NSView that renders Firefox's current viewport by polling Page.captureScreenshot
/// at ~5fps. Displayed when Gecko is the active renderer.
@MainActor
final class GeckoLiveView: NSView {
    var screenshotProvider: (() async -> NSImage?)? = nil

    private var refreshTimer: Timer?
    private var imageLayer = CALayer()
    private var isRefreshing = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.frame = bounds
        layer?.addSublayer(imageLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
    }

    func startRefreshing() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
    }

    func stopRefreshing() {
        isRefreshing = false
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func tick() async {
        guard let image = await screenshotProvider?() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        CATransaction.commit()
    }
}
