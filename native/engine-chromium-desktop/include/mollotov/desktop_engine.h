#pragma once

#include <functional>
#include <memory>
#include <string>

#include <nlohmann/json.hpp>

#include "mollotov/cef_renderer.h"

namespace mollotov {

class DesktopEngine {
 public:
  enum class Mode {
    kWindowed = 0,
    kOffscreen,
  };

  struct Size {
    int width = 1280;
    int height = 720;
  };

  struct Config {
    Mode mode = Mode::kOffscreen;
    Size viewport;
    std::string initial_url;
    std::string cache_path;
    std::string user_agent;
    bool external_message_pump = true;
    std::function<void(void*)> configure_window_info;
  };

  struct ViewportState {
    int width = 1280;
    int height = 720;
    double device_pixel_ratio = 1.0;
    bool offscreen = true;
  };

  using JsonEventSink = std::function<void(const nlohmann::json&)>;
  using NavigationSink = std::function<void(const std::string&, const std::string&)>;

  DesktopEngine();
  ~DesktopEngine();

  bool Initialize(const Config& config);
  void Shutdown();
  void DoMessageLoopWork();

  bool is_initialized() const;
  bool is_offscreen() const;

  ViewportState viewport() const;
  bool ResizeViewport(int width, int height);

  void SetConsoleSink(JsonEventSink sink);
  void SetNetworkSink(JsonEventSink sink);
  void SetNavigationSink(NavigationSink sink);

  CefRenderer& renderer();
  const CefRenderer& renderer() const;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
  std::unique_ptr<CefRenderer> renderer_;
};

}  // namespace mollotov
