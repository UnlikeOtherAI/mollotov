#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class DeviceHandler {
 public:
  explicit DeviceHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json GetDeviceInfo() const;
  nlohmann::json GetCapabilities() const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
