#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class DomHandler {
 public:
  explicit DomHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json QuerySelector(const nlohmann::json& params, bool all) const;
  nlohmann::json GetElementText(const nlohmann::json& params) const;
  nlohmann::json GetAttributes(const nlohmann::json& params) const;
  nlohmann::json GetDom(const nlohmann::json& params) const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
