#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class BrowserManagementHandler {
 public:
  explicit BrowserManagementHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json GetTabs() const;
  nlohmann::json NewTab(const nlohmann::json& params) const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
