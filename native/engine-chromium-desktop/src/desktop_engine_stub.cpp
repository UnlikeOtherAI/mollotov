#include "kelpie/desktop_engine.h"

namespace kelpie {

class DesktopEngine::Impl {
 public:
  explicit Impl(CefRenderer* renderer) : renderer_(renderer) {}

  bool Initialize(const Config& next_config) {
    config = next_config;
    viewport.width = config.viewport.width;
    viewport.height = config.viewport.height;
    viewport.offscreen = config.mode == Mode::kOffscreen;
    renderer_->SetCallbacks({});
    initialized = false;
    return false;
  }

  Config config;
  ViewportState viewport;
  CefRenderer* renderer_ = nullptr;
  bool initialized = false;
};

DesktopEngine::DesktopEngine()
    : impl_(nullptr),
      renderer_(std::make_unique<CefRenderer>()) {
  impl_ = std::make_unique<Impl>(renderer_.get());
}

DesktopEngine::~DesktopEngine() = default;

bool DesktopEngine::Initialize(const Config& config) {
  return impl_->Initialize(config);
}

void DesktopEngine::Shutdown() {}

void DesktopEngine::DoMessageLoopWork() {}

bool DesktopEngine::is_initialized() const {
  return false;
}

bool DesktopEngine::is_offscreen() const {
  return impl_->viewport.offscreen;
}

DesktopEngine::ViewportState DesktopEngine::viewport() const {
  return impl_->viewport;
}

bool DesktopEngine::ResizeViewport(int width, int height) {
  impl_->viewport.width = width;
  impl_->viewport.height = height;
  return true;
}

bool DesktopEngine::SendFocusEvent(bool focused) {
  (void)focused;
  return false;
}

bool DesktopEngine::SendMouseMoveEvent(int x, int y, bool mouse_leave) {
  (void)x;
  (void)y;
  (void)mouse_leave;
  return false;
}

bool DesktopEngine::SendMouseClickEvent(int x, int y, int button, bool mouse_up, int click_count) {
  (void)x;
  (void)y;
  (void)button;
  (void)mouse_up;
  (void)click_count;
  return false;
}

bool DesktopEngine::SendMouseWheelEvent(int x, int y, int delta_x, int delta_y) {
  (void)x;
  (void)y;
  (void)delta_x;
  (void)delta_y;
  return false;
}

void DesktopEngine::SetConsoleSink(JsonEventSink) {}

void DesktopEngine::SetNetworkSink(JsonEventSink) {}

void DesktopEngine::SetNavigationSink(NavigationSink) {}

CefRenderer& DesktopEngine::renderer() {
  return *renderer_;
}

const CefRenderer& DesktopEngine::renderer() const {
  return *renderer_;
}

}  // namespace kelpie
