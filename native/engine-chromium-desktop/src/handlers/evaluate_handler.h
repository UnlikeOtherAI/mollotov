#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class EvaluateHandler {
 public:
  explicit EvaluateHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json Evaluate(const nlohmann::json& params) const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
