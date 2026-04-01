#pragma once

#include "handler_support.h"
#include "mollotov/desktop_router.h"

namespace mollotov {

class InteractionHandler {
 public:
  explicit InteractionHandler(DesktopHandlerRuntime runtime);

  void Register(DesktopRouter& router) const;

 private:
  nlohmann::json Click(const nlohmann::json& params) const;
  nlohmann::json Fill(const nlohmann::json& params) const;
  nlohmann::json Type(const nlohmann::json& params) const;
  nlohmann::json SelectOption(const nlohmann::json& params) const;
  nlohmann::json Check(const nlohmann::json& params, bool checked) const;

  DesktopHandlerRuntime runtime_;
};

}  // namespace mollotov
