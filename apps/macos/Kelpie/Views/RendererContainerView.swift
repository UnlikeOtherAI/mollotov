import SwiftUI

/// Wraps the active renderer's NSView in SwiftUI.
struct RendererContainerView: NSViewRepresentable {
    @ObservedObject var serverState: ServerState
    @ObservedObject var rendererState: RendererState
    @ObservedObject var tabStore: TabStore

    final class Coordinator {
        var attachedEngine: RendererState.Engine?
        weak var attachedView: NSView?
        private var eventMonitor: Any?

        /// Installs a local event monitor that resigns the WebView as first responder
        /// whenever the user clicks outside the renderer container. This allows SwiftUI
        /// controls elsewhere in the window (AI panel, resize separator, overlays) to
        /// receive mouse events normally.
        func installEventMonitor(for container: NSView) {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak container] event in
                guard let container, let window = container.window, event.window === window else {
                    return event
                }
                let locationInContainer = container.convert(event.locationInWindow, from: nil)
                if !container.bounds.contains(locationInContainer) {
                    if let fr = window.firstResponder {
                        let cls = NSStringFromClass(type(of: fr))
                        if cls.contains("WKWeb") || cls.contains("CrWeb") || cls.contains("CEF") {
                            window.makeFirstResponder(nil)
                        }
                    }
                }
                return event
            }
        }

        deinit {
            if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        attachActiveRenderer(to: container, coordinator: context.coordinator)
        context.coordinator.installEventMonitor(for: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        attachActiveRenderer(to: container, coordinator: context.coordinator)
        let nonCEFCount = container.subviews.filter {
            !NSStringFromClass(type(of: $0)).contains("CEF")
        }.count
        if nonCEFCount > tabStore.tabs.count {
            removeClosedTabViews(from: container)
        }

        // Hide the WKWebView when the active tab is on the start page so the
        // SwiftUI StartPageView overlay can receive mouse events unobstructed.
        if let activeTab = tabStore.activeTab {
            activeTab.renderer.makeView().isHidden = activeTab.isStartPage
        }
    }

    /// Removes subviews that belong to tabs that no longer exist.
    /// CEF views are never removed — only WKWebView subviews are eligible.
    private func removeClosedTabViews(from container: NSView) {
        let activeViews = Set(tabStore.tabs.map { ObjectIdentifier($0.renderer.makeView()) })
        for subview in container.subviews {
            let isCEF = NSStringFromClass(type(of: subview)).contains("CEF")
            guard !isCEF else { continue }
            if !activeViews.contains(ObjectIdentifier(subview)) {
                subview.removeFromSuperview()
            }
        }
    }

    private func attachActiveRenderer(to container: NSView, coordinator: Coordinator) {
        guard let activeView = serverState.handlerContext.renderer?.makeView() else {
            container.subviews.forEach { $0.isHidden = true }
            coordinator.attachedEngine = nil
            return
        }

        activeView.frame = container.bounds
        activeView.autoresizingMask = [.width, .height]

        // Add the view if it isn't already a subview.
        // Active renderer views are never removed — only hidden/shown.
        // CEF's NSView must NEVER be removed: re-adding it corrupts
        // its compositing state and crashes CrBrowserMain.
        // Closed WKWebView tab views ARE removed (by removeClosedTabViews)
        // to free memory and WKWebView process slots.
        if activeView.superview !== container {
            container.addSubview(activeView)
        }

        // Show the active view, hide all others.
        for subview in container.subviews {
            subview.isHidden = subview !== activeView
        }

        coordinator.attachedEngine = rendererState.activeEngine
    }
}
