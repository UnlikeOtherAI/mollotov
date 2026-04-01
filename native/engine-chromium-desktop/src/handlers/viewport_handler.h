#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class ViewportHandler {
 public:
  explicit ViewportHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json GetViewport() const;
  nlohmann::json ResizeViewport(const nlohmann::json& params) const;
  nlohmann::json ResetViewport() const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
