#include "tap_runtime_utils.h"

#include <algorithm>
#include <filesystem>
#include <sstream>

#include "linux_app_internal.h"

namespace kelpie::linuxapp {
namespace {

std::filesystem::path TapCalibrationPath(const std::string& profile_dir) {
  return std::filesystem::path(profile_dir) / "tap-calibration.json";
}

}  // namespace

TapCalibration LoadTapCalibration(const std::string& profile_dir) {
  const std::string raw = ReadTextFile(TapCalibrationPath(profile_dir));
  if (raw.empty()) {
    return {};
  }
  try {
    const nlohmann::json payload = nlohmann::json::parse(raw);
    return {
        payload.value("offsetX", 0.0),
        payload.value("offsetY", 0.0),
    };
  } catch (const nlohmann::json::parse_error&) {
    return {};
  }
}

TapCalibration SaveTapCalibration(const std::string& profile_dir,
                                  double offset_x,
                                  double offset_y) {
  const nlohmann::json payload = {
      {"offsetX", offset_x},
      {"offsetY", offset_y},
  };
  WriteTextFile(TapCalibrationPath(profile_dir), payload.dump(2));
  return {offset_x, offset_y};
}

std::optional<double> JsonNumber(const nlohmann::json& params, std::string_view key) {
  const auto it = params.find(std::string(key));
  if (it == params.end() || !it->is_number()) {
    return std::nullopt;
  }
  return it->get<double>();
}

double ClampCoordinate(double value, double lower, double upper) {
  if (lower > upper) {
    return lower;
  }
  return std::clamp(value, lower, upper);
}

std::string OverlayRgbFromHex(const std::string& hex) {
  const std::string normalized =
      !hex.empty() && hex.front() == '#' ? hex.substr(1) : hex;
  if (normalized.size() != 6) {
    return "59,130,246";
  }
  try {
    const int red = std::stoi(normalized.substr(0, 2), nullptr, 16);
    const int green = std::stoi(normalized.substr(2, 2), nullptr, 16);
    const int blue = std::stoi(normalized.substr(4, 2), nullptr, 16);
    std::ostringstream stream;
    stream << red << ',' << green << ',' << blue;
    return stream.str();
  } catch (const std::exception&) {
    return "59,130,246";
  }
}

std::string TapScript(double requested_x,
                      double requested_y,
                      double applied_x,
                      double applied_y,
                      double offset_x,
                      double offset_y,
                      std::string_view color_rgb) {
  std::ostringstream script;
  script
      << "(function(){"
      << "function kelpieRectJSON(rect){return{x:rect.x,y:rect.y,width:rect.width,height:rect.height};}"
      << "function kelpieViewportDiagnostics(){return{viewport:{width:window.innerWidth||0,height:window.innerHeight||0},scrollPosition:{x:window.scrollX||0,y:window.scrollY||0}};}"
      << "function kelpieElementSummary(node){if(!node)return null;var rect=typeof node.getBoundingClientRect==='function'?node.getBoundingClientRect():{x:0,y:0,width:0,height:0};return{tag:node.tagName?node.tagName.toLowerCase():null,role:node.getAttribute?(node.getAttribute('role')||(node.tagName?node.tagName.toLowerCase():null)):null,text:((node.innerText||node.textContent||node.value||node.placeholder||'')+'').trim().substring(0,100),selector:node.tagName&&typeof kelpieBuildSelector==='function'?kelpieBuildSelector(node):null,rect:kelpieRectJSON(rect)};}"
      << "function kelpieTapDiagnostics(target,requestedX,requestedY,appliedX,appliedY,offsetX,offsetY){var diagnostics=kelpieViewportDiagnostics();diagnostics.requestedPoint={x:requestedX,y:requestedY};diagnostics.clickedPoint={x:appliedX,y:appliedY};diagnostics.offset={x:offsetX,y:offsetY};diagnostics.actualElementAtPoint=kelpieElementSummary(target);return diagnostics;}"
      << "var requestedX=" << requested_x << ';'
      << "var requestedY=" << requested_y << ';'
      << "var appliedX=" << applied_x << ';'
      << "var appliedY=" << applied_y << ';'
      << "var offsetX=" << offset_x << ';'
      << "var offsetY=" << offset_y << ';'
      << "var hook=window.__kelpieTapCalibration;"
      << "if(hook&&typeof hook.onAutomationTap==='function'){try{hook.onAutomationTap({requestedX:requestedX,requestedY:requestedY,appliedX:appliedX,appliedY:appliedY,offsetX:offsetX,offsetY:offsetY});}catch(error){}}"
      << "var dot=document.createElement('div');"
      << "dot.style.cssText='position:fixed;left:' + appliedX + 'px;top:' + appliedY + 'px;width:36px;height:36px;margin-left:-18px;margin-top:-18px;border-radius:50%;background:rgba("
      << color_rgb
      << ",0.7);pointer-events:none;z-index:2147483647;transition:transform 0.5s ease-out, opacity 0.5s ease-out;transform:scale(1);opacity:1;';"
      << "document.body&&document.body.appendChild(dot);"
      << "var ripple=document.createElement('div');"
      << "ripple.style.cssText='position:fixed;left:' + appliedX + 'px;top:' + appliedY + 'px;width:36px;height:36px;margin-left:-18px;margin-top:-18px;border-radius:50%;border:2px solid rgba("
      << color_rgb
      << ",0.7);pointer-events:none;z-index:2147483647;transition:transform 0.6s ease-out, opacity 0.6s ease-out;transform:scale(1);opacity:1;';"
      << "document.body&&document.body.appendChild(ripple);"
      << "requestAnimationFrame(function(){ripple.style.transform='scale(3)';ripple.style.opacity='0';});"
      << "setTimeout(function(){dot.style.transform='scale(0.5)';dot.style.opacity='0';},550);"
      << "setTimeout(function(){dot.remove();ripple.remove();},1100);"
      << "var eventTarget=document.elementFromPoint(appliedX,appliedY)||document.body||document.documentElement;"
      << "if(!eventTarget){return kelpieTapDiagnostics(null,requestedX,requestedY,appliedX,appliedY,offsetX,offsetY);}"
      << "if(typeof eventTarget.focus==='function'){try{eventTarget.focus({preventScroll:true});}catch(error){try{eventTarget.focus();}catch(focusError){}}}"
      << "function dispatchMouse(type,button,buttons){eventTarget.dispatchEvent(new MouseEvent(type,{bubbles:true,cancelable:true,composed:true,clientX:appliedX,clientY:appliedY,screenX:appliedX,screenY:appliedY,detail:type==='click'?1:0,button:button,buttons:buttons}));}"
      << "function dispatchPointer(type,button,buttons){if(typeof window.PointerEvent!=='function'){return;}eventTarget.dispatchEvent(new PointerEvent(type,{bubbles:true,cancelable:true,composed:true,clientX:appliedX,clientY:appliedY,screenX:appliedX,screenY:appliedY,pointerId:1,pointerType:'touch',isPrimary:true,button:button,buttons:buttons}));}"
      << "dispatchPointer('pointerdown',0,1);"
      << "dispatchMouse('mousedown',0,1);"
      << "dispatchPointer('pointerup',0,0);"
      << "dispatchMouse('mouseup',0,0);"
      << "if(typeof eventTarget.click==='function'){eventTarget.click();}else{dispatchMouse('click',0,0);}"
      << "return kelpieTapDiagnostics(eventTarget,requestedX,requestedY,appliedX,appliedY,offsetX,offsetY);"
      << "})()";
  return script.str();
}

}  // namespace kelpie::linuxapp
