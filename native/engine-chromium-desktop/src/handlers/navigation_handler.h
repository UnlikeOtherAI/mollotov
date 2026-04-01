#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class NavigationHandler {
 public:
  explicit NavigationHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json Navigate(const nlohmann::json& params) const;
  nlohmann::json Back(const nlohmann::json& params) const;
  nlohmann::json Forward(const nlohmann::json& params) const;
  nlohmann::json Reload(const nlohmann::json& params) const;
  nlohmann::json GetCurrentUrl() const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
