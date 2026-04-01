#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class RendererHandler {
 public:
  explicit RendererHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json GetRenderer() const;
  nlohmann::json SetRenderer() const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
