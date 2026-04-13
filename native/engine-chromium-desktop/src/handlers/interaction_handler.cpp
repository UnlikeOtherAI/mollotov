#include "interaction_handler.h"

#include "kelpie/element_selector_script.h"
#include "kelpie/form_control_script.h"

namespace kelpie {
namespace {

const char* kClickScript = R"JS(
(() => {
  ELEMENT_SELECTOR_HELPERS
  const selector = SELECTOR;
  const element = document.querySelector(selector);
  if (!element) {
    return {error: 'not_found'};
  }
  element.scrollIntoView({block: 'center', inline: 'center'});
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    return {error: 'not_visible'};
  }
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  const hit = document.elementFromPoint(centerX, centerY);
  if (!hit) {
    return {error: 'not_visible'};
  }
  if (!(hit === element || element.contains(hit) || hit.contains(element))) {
    return {error: 'not_visible'};
  }
  if (typeof hit.focus === 'function') {
    try { hit.focus({preventScroll: true}); } catch (error) { try { hit.focus(); } catch (focusError) {} }
  }
  function dispatchPointer(type, button, buttons) {
    if (typeof window.PointerEvent !== 'function') return;
    hit.dispatchEvent(new PointerEvent(type, {
      bubbles: true,
      cancelable: true,
      composed: true,
      clientX: centerX,
      clientY: centerY,
      screenX: centerX,
      screenY: centerY,
      pointerId: 1,
      pointerType: 'touch',
      isPrimary: true,
      button: button,
      buttons: buttons
    }));
  }
  function dispatchMouse(type, button, buttons) {
    hit.dispatchEvent(new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      composed: true,
      clientX: centerX,
      clientY: centerY,
      screenX: centerX,
      screenY: centerY,
      detail: type === 'click' ? 1 : 0,
      button: button,
      buttons: buttons
    }));
  }
  dispatchPointer('pointermove', 0, 0);
  dispatchMouse('mousemove', 0, 0);
  dispatchPointer('pointerdown', 0, 1);
  dispatchMouse('mousedown', 0, 1);
  dispatchPointer('pointerup', 0, 0);
  dispatchMouse('mouseup', 0, 0);
  if (typeof hit.click === 'function') {
    hit.click();
  } else {
    dispatchMouse('click', 0, 0);
  }
  return {
    tag: (element.tagName || "").toLowerCase(),
    text: (element.innerText || element.textContent || "").trim(),
    selector: kelpieBuildSelector(element)
  };
})()
)JS";

}  // namespace

InteractionHandler::InteractionHandler(DesktopHandlerRuntime runtime)
    : runtime_(std::move(runtime)) {}

void InteractionHandler::Register(DesktopRouter& router) const {
  router.Register("click", [this](const nlohmann::json& params) { return Click(params); });
  router.Register("fill", [this](const nlohmann::json& params) { return Fill(params); });
  router.Register("type", [this](const nlohmann::json& params) { return Type(params); });
  router.Register("select-option",
                  [this](const nlohmann::json& params) { return SelectOption(params); });
  router.Register("check", [this](const nlohmann::json& params) { return Check(params, true); });
  router.Register("uncheck",
                  [this](const nlohmann::json& params) { return Check(params, false); });
}

nlohmann::json InteractionHandler::Click(const nlohmann::json& params) const {
  try {
    HandlerContext& context = RequireHandlerContext(runtime_);
    std::string script = kClickScript;
    const std::string selector = RequireString(params, "selector");
    const auto helper_position = script.find("ELEMENT_SELECTOR_HELPERS");
    script.replace(helper_position, 24, ElementSelectorBuilderScript());
    const auto position = script.find("SELECTOR");
    script.replace(position, 8, JsStringLiteral(selector));

    const nlohmann::json result = context.EvaluateJsReturningJson(script);
    if (result.value("error", "") == "not_found") {
      return ErrorResponse(ErrorCode::kElementNotFound,
                           "No element matching selector '" + selector + "'");
    }
    if (result.value("error", "") == "not_visible") {
      return ErrorResponse(ErrorCode::kElementNotVisible,
                           "Element matching selector '" + selector + "' is not visible");
    }
    return SuccessResponse({
        {"element",
         {{"tag", result.value("tag", "")},
          {"text", result.value("text", "")},
          {"selector", result.value("selector", selector)}}},
    });
  } catch (const std::invalid_argument& exception) {
    return InvalidParams(exception.what());
  }
}

nlohmann::json InteractionHandler::Fill(const nlohmann::json& params) const {
  try {
    HandlerContext& context = RequireHandlerContext(runtime_);
    const std::string selector = RequireString(params, "selector");
    const std::string value = RequireString(params, "value");
    const std::string script =
        "(() => {"
        + FormControlMutationScript() +
        "const element = document.querySelector(" + JsStringLiteral(selector) + ");"
        "if (!element) { return {found: false}; }"
        "element.focus();"
        "kelpieWriteFormControlValue(element," + JsStringLiteral(value) + ");"
        "kelpieDispatchFormControlInput(element);"
        "kelpieDispatchFormControlChange(element);"
        "return {found: true};"
        "})()";
    const nlohmann::json result = context.EvaluateJsReturningJson(script);
    if (!result.value("found", false)) {
      return ErrorResponse(ErrorCode::kElementNotFound,
                           "No element matching selector '" + selector + "'");
    }
    return SuccessResponse({{"selector", selector}, {"value", value}});
  } catch (const std::invalid_argument& exception) {
    return InvalidParams(exception.what());
  }
}

nlohmann::json InteractionHandler::Type(const nlohmann::json& params) const {
  try {
    HandlerContext& context = RequireHandlerContext(runtime_);
    const std::string text = RequireString(params, "text");
    const auto selector_it = params.find("selector");
    const std::string selector =
        selector_it != params.end() && selector_it->is_string() ? selector_it->get<std::string>() : "";
    std::string script = "(() => { let element = document.activeElement;";
    if (!selector.empty()) {
      script += "element = document.querySelector(" + JsStringLiteral(selector) + ");";
    }
    script +=
        FormControlMutationScript() +
        "if (!element) { return {found: false}; }"
        "element.focus();"
        "const text = " + JsStringLiteral(text) + ";"
        "for (const ch of text) {"
        "  element.dispatchEvent(new KeyboardEvent('keydown',{key:ch,bubbles:true}));"
        "  element.dispatchEvent(new KeyboardEvent('keypress',{key:ch,bubbles:true}));"
        "  kelpieWriteFormControlValue(element, kelpieReadFormControlValue(element) + ch);"
        "  kelpieDispatchFormControlInput(element);"
        "  element.dispatchEvent(new KeyboardEvent('keyup',{key:ch,bubbles:true}));"
        "}"
        "kelpieDispatchFormControlChange(element);"
        "return {found: true};"
        "})()";
    const nlohmann::json result = context.EvaluateJsReturningJson(script);
    if (!result.value("found", false)) {
      return ErrorResponse(ErrorCode::kElementNotFound, "No active or matching input element");
    }
    return SuccessResponse({{"typed", text}});
  } catch (const std::invalid_argument& exception) {
    return InvalidParams(exception.what());
  }
}

nlohmann::json InteractionHandler::SelectOption(const nlohmann::json& params) const {
  try {
    HandlerContext& context = RequireHandlerContext(runtime_);
    const std::string selector = RequireString(params, "selector");
    const std::string value = RequireString(params, "value");
    const std::string script =
        "(() => {"
        "const select = document.querySelector(" + JsStringLiteral(selector) + ");"
        "if (!select) { return {found: false}; }"
        "const option = Array.from(select.options || []).find(item => item.value === " +
        JsStringLiteral(value) + ");"
        "if (!option) { return {found: true, selected: false}; }"
        "select.value = option.value;"
        "select.dispatchEvent(new Event('change', {bubbles: true}));"
        "return {found: true, selected: true, value: option.value, text: option.text || ''};"
        "})()";
    const nlohmann::json result = context.EvaluateJsReturningJson(script);
    if (!result.value("found", false)) {
      return ErrorResponse(ErrorCode::kElementNotFound,
                           "No element matching selector '" + selector + "'");
    }
    if (!result.value("selected", false)) {
      return ErrorResponse(ErrorCode::kInvalidParams,
                           "No option with value '" + value + "'");
    }
    return SuccessResponse({
        {"selected", {{"value", result.value("value", value)},
                       {"text", result.value("text", "")}}},
    });
  } catch (const std::invalid_argument& exception) {
    return InvalidParams(exception.what());
  }
}

nlohmann::json InteractionHandler::Check(const nlohmann::json& params, bool checked) const {
  try {
    HandlerContext& context = RequireHandlerContext(runtime_);
    const std::string selector = RequireString(params, "selector");
    const std::string script =
        "(() => {"
        "const element = document.querySelector(" + JsStringLiteral(selector) + ");"
        "if (!element) { return {found: false}; }"
        "element.checked = " + std::string(checked ? "true" : "false") + ";"
        "element.dispatchEvent(new Event('change', {bubbles: true}));"
        "return {found: true, checked: !!element.checked};"
        "})()";
    const nlohmann::json result = context.EvaluateJsReturningJson(script);
    if (!result.value("found", false)) {
      return ErrorResponse(ErrorCode::kElementNotFound,
                           "No element matching selector '" + selector + "'");
    }
    return SuccessResponse({{"checked", result.value("checked", checked)}});
  } catch (const std::invalid_argument& exception) {
    return InvalidParams(exception.what());
  }
}

}  // namespace kelpie
