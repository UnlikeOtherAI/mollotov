#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class ConsoleHandler {
 public:
  explicit ConsoleHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json GetConsoleMessages(const nlohmann::json& params) const;
  nlohmann::json GetJsErrors() const;
  nlohmann::json ClearConsole() const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
