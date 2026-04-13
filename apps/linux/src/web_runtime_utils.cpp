#include "web_runtime_utils.h"

#include <algorithm>

#if KELPIE_LINUX_HAS_GTK
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#endif

#include "kelpie/handler_context.h"
#include "kelpie/element_selector_script.h"
#include "kelpie/form_control_script.h"
#include "kelpie/js_string_literal.h"
#include "kelpie/response_helpers.h"

namespace kelpie::linuxapp {
namespace {

std::string InteractionHelpersScript() {
  return "function kelpieRectJSON(rect){return{x:rect.x,y:rect.y,width:rect.width,height:rect.height};}"
         "function kelpieViewportDiagnostics(){return{viewport:{width:window.innerWidth||0,height:window.innerHeight||0},scrollPosition:{x:window.scrollX||0,y:window.scrollY||0}};}"
         "function kelpieElementSummary(node){if(!node)return null;var rect=typeof node.getBoundingClientRect==='function'?node.getBoundingClientRect():{x:0,y:0,width:0,height:0};return{tag:node.tagName?node.tagName.toLowerCase():null,role:node.getAttribute?(node.getAttribute('role')||(node.tagName?node.tagName.toLowerCase():null)):null,text:((node.innerText||node.textContent||node.value||node.placeholder||'')+'').trim().substring(0,100),selector:node.tagName?kelpieBuildSelector(node):null,rect:kelpieRectJSON(rect)};}"
         "function kelpieBaseDiagnostics(selector,annotationIndex){var diagnostics=kelpieViewportDiagnostics();if(selector)diagnostics.selector=selector;if(annotationIndex!==null&&annotationIndex!==undefined)diagnostics.annotationIndex=annotationIndex;return diagnostics;}"
         "function kelpieSelectorTokens(selector){var matches=(selector||'').toLowerCase().match(/[a-z0-9_-]+/g)||[];var seen=new Set();return matches.filter(function(token){if(token.length<2)return false;if(['div','span','button','input','select','textarea','role','aria','data'].includes(token))return false;if(seen.has(token))return false;seen.add(token);return true;}).slice(0,6);}"
         "function kelpieSimilarElements(selector){var tokens=kelpieSelectorTokens(selector);if(!tokens.length)return[];return Array.from(document.querySelectorAll('a,button,input,select,textarea,[role=button]')).map(function(node){var rect=node.getBoundingClientRect();if(rect.width<=0||rect.height<=0)return null;var haystack=[node.id||'',node.getAttribute('name')||'',node.getAttribute('aria-label')||'',node.getAttribute('placeholder')||'',typeof node.className==='string'?node.className:'',node.innerText||'',node.textContent||'',node.value||'',node.tagName||''].join(' ').toLowerCase();var score=tokens.reduce(function(total,token){return total+(haystack.indexOf(token)>=0?1:0);},0);if(!score)return null;var summary=kelpieElementSummary(node);summary.score=score;return summary;}).filter(Boolean).sort(function(lhs,rhs){return rhs.score-lhs.score;}).slice(0,5).map(function(item){return{selector:item.selector,text:item.text,tag:item.tag,role:item.role,rect:item.rect};});}"
         "function kelpieNotFoundDiagnostics(selector,annotationIndex){var diagnostics=kelpieBaseDiagnostics(selector,annotationIndex);if(selector)diagnostics.similarElements=kelpieSimilarElements(selector);return diagnostics;}"
         "function kelpieEditableDiagnostics(el,selector,annotationIndex){var tag=el.tagName?el.tagName.toLowerCase():null;var diagnostics=kelpieBaseDiagnostics(selector,annotationIndex);diagnostics.tag=tag;diagnostics.targetRect=kelpieRectJSON(el.getBoundingClientRect());diagnostics.isInput=['input','textarea','select'].includes(tag);diagnostics.disabled=!!el.disabled;diagnostics.readOnly=!!el.readOnly;diagnostics.isContentEditable=!!el.isContentEditable;return diagnostics;}"
         "function kelpieTapDiagnostics(target,requestedX,requestedY,appliedX,appliedY,offsetX,offsetY){var diagnostics=kelpieBaseDiagnostics(null,null);diagnostics.requestedPoint={x:requestedX,y:requestedY};diagnostics.clickedPoint={x:appliedX,y:appliedY};diagnostics.offset={x:offsetX,y:offsetY};diagnostics.actualElementAtPoint=kelpieElementSummary(target);return diagnostics;}";
}

std::string ActivationScript(std::string_view resolver,
                             std::optional<std::string> selector,
                             std::optional<int> annotation_index,
                             bool using_annotation) {
  const std::string selector_literal =
      selector.has_value() ? JsStringLiteral(*selector) : std::string("null");
  const std::string annotation_literal =
      annotation_index.has_value() ? std::to_string(*annotation_index) : std::string("null");
  const std::string element_lookup = using_annotation
                                         ? std::string(
                                               "var annotation = " + std::string(resolver) + ";"
                                               "if (!annotation) return {error:'not_found', diagnostics: kelpieBaseDiagnostics(null, requestedAnnotationIndex)};"
                                               "var matches = Array.from(document.querySelectorAll('a,button,input,select,textarea,[role=button]')).filter(function(node){"
                                               "  var rect = node.getBoundingClientRect();"
                                               "  return rect.width > 0 && rect.height > 0;"
                                               "});"
                                               "var el = matches[annotation.index];"
                                               "if (!el) return {error:'not_found', diagnostics: kelpieNotFoundDiagnostics(annotation.selector || null, requestedAnnotationIndex)};")
                                         : std::string(
                                               "var el = " + std::string(resolver) + ";"
                                               "if (!el) return {error:'not_found', diagnostics: kelpieNotFoundDiagnostics(requestedSelector, requestedAnnotationIndex)};");

  return "(() => {" + ElementSelectorBuilderScript() + InteractionHelpersScript() +
         "var requestedSelector = " + selector_literal + ";"
         "var requestedAnnotationIndex = " + annotation_literal + ";" + element_lookup +
         "el.scrollIntoView({block:'center',inline:'center'});"
         "var rect = el.getBoundingClientRect();"
         "if (rect.width <= 0 || rect.height <= 0) {"
         "  var diagnostics = kelpieBaseDiagnostics(requestedSelector, requestedAnnotationIndex);"
         "  diagnostics.targetRect = kelpieRectJSON(rect);"
         "  return {error:'not_visible', diagnostics: diagnostics};"
         "}"
         "var centerX = rect.left + rect.width / 2;"
         "var centerY = rect.top + rect.height / 2;"
         "var hit = document.elementFromPoint(centerX, centerY);"
         "if (!hit) {"
         "  var diagnostics = kelpieBaseDiagnostics(requestedSelector, requestedAnnotationIndex);"
         "  diagnostics.targetRect = kelpieRectJSON(rect);"
         "  diagnostics.targetCenter = {x:centerX,y:centerY};"
         "  return {error:'not_visible', diagnostics: diagnostics};"
         "}"
         "if (!(hit === el || el.contains(hit) || hit.contains(el))) {"
         "  var diagnostics = kelpieBaseDiagnostics(requestedSelector || (annotation ? annotation.selector : null), requestedAnnotationIndex);"
         "  diagnostics.targetRect = kelpieRectJSON(rect);"
         "  diagnostics.targetCenter = {x:centerX,y:centerY};"
         "  diagnostics.actualElementAtPoint = kelpieElementSummary(hit);"
         "  diagnostics.obstruction = kelpieElementSummary(hit);"
         "  return {error:'not_visible', diagnostics: diagnostics};"
         "}"
         "if (typeof hit.focus === 'function') {"
         "  try { hit.focus({preventScroll:true}); } catch (error) { try { hit.focus(); } catch (focusError) {} }"
         "}"
         "function dispatchPointer(type, button, buttons) {"
         "  if (typeof window.PointerEvent !== 'function') return;"
         "  hit.dispatchEvent(new PointerEvent(type,{bubbles:true,cancelable:true,composed:true,clientX:centerX,clientY:centerY,screenX:centerX,screenY:centerY,pointerId:1,pointerType:'touch',isPrimary:true,button:button,buttons:buttons}));"
         "}"
         "function dispatchMouse(type, button, buttons) {"
         "  hit.dispatchEvent(new MouseEvent(type,{bubbles:true,cancelable:true,composed:true,clientX:centerX,clientY:centerY,screenX:centerX,screenY:centerY,detail:type==='click'?1:0,button:button,buttons:buttons}));"
         "}"
         "dispatchPointer('pointermove',0,0);"
         "dispatchMouse('mousemove',0,0);"
         "dispatchPointer('pointerdown',0,1);"
         "dispatchMouse('mousedown',0,1);"
         "dispatchPointer('pointerup',0,0);"
         "dispatchMouse('mouseup',0,0);"
         "if (typeof hit.click === 'function') hit.click(); else dispatchMouse('click',0,0);"
         "return {tag:(el.tagName||'').toLowerCase(),role:el.getAttribute('role')||(el.tagName||'').toLowerCase(),name:(el.innerText||el.textContent||el.value||el.placeholder||'').trim().substring(0,50),selector:kelpieBuildSelector(el),text:(el.innerText||el.textContent||'').trim().substring(0,100),rect:{x:rect.x,y:rect.y,width:rect.width,height:rect.height},center:{x:centerX,y:centerY}};"
         "})()";
}

}  // namespace

std::optional<ScreenshotResolution> ParseScreenshotResolution(const nlohmann::json& params) {
  const auto it = params.find("resolution");
  if (it == params.end() || it->is_null()) {
    return ScreenshotResolution::kNative;
  }
  if (!it->is_string()) {
    return std::nullopt;
  }
  const std::string value = it->get<std::string>();
  if (value == "native") {
    return ScreenshotResolution::kNative;
  }
  if (value == "viewport") {
    return ScreenshotResolution::kViewport;
  }
  return std::nullopt;
}

ScreenshotViewportMetrics LoadScreenshotViewportMetrics(kelpie::HandlerContext& context) {
  const nlohmann::json viewport = context.EvaluateJsReturningJson(
      "(() => ({viewportWidth: Math.max(window.innerWidth || 0, 1),"
      "viewportHeight: Math.max(window.innerHeight || 0, 1),"
      "devicePixelRatio: window.devicePixelRatio || 1}))()");
  return {
      viewport.value("viewportWidth", 1),
      viewport.value("viewportHeight", 1),
      viewport.value("devicePixelRatio", 1.0),
  };
}

nlohmann::json ScreenshotMetadata(int image_width, int image_height, std::string_view format,
                                  ScreenshotResolution resolution,
                                  const ScreenshotViewportMetrics& viewport) {
  const double scale_x =
      viewport.viewport_width > 0 ? static_cast<double>(image_width) / viewport.viewport_width : 1.0;
  const double scale_y = viewport.viewport_height > 0
                             ? static_cast<double>(image_height) / viewport.viewport_height
                             : 1.0;
  return {
      {"width", image_width},
      {"height", image_height},
      {"format", std::string(format)},
      {"resolution", resolution == ScreenshotResolution::kViewport ? "viewport" : "native"},
      {"coordinateSpace", "viewport-css-pixels"},
      {"viewportWidth", viewport.viewport_width},
      {"viewportHeight", viewport.viewport_height},
      {"devicePixelRatio", viewport.device_pixel_ratio},
      {"imageScaleX", scale_x},
      {"imageScaleY", scale_y},
  };
}

std::optional<std::pair<int, int>> ParsePngDimensions(const std::vector<std::uint8_t>& bytes) {
  constexpr std::uint8_t kPngSignature[] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
  if (bytes.size() < 24 || !std::equal(std::begin(kPngSignature), std::end(kPngSignature), bytes.begin())) {
    return std::nullopt;
  }
  if (!(bytes[12] == 'I' && bytes[13] == 'H' && bytes[14] == 'D' && bytes[15] == 'R')) {
    return std::nullopt;
  }
  const int width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  const int height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  if (width <= 0 || height <= 0) {
    return std::nullopt;
  }
  return std::make_pair(width, height);
}

std::vector<std::uint8_t> ScaleScreenshotBytes(const std::vector<std::uint8_t>& bytes,
                                               ScreenshotResolution resolution,
                                               const ScreenshotViewportMetrics& viewport) {
  if (resolution != ScreenshotResolution::kViewport || bytes.empty() ||
      viewport.device_pixel_ratio <= 1.0) {
    return bytes;
  }
#if !KELPIE_LINUX_HAS_GTK
  return bytes;
#else
  GError* error = nullptr;
  GInputStream* stream = g_memory_input_stream_new_from_data(bytes.data(),
                                                             static_cast<gssize>(bytes.size()),
                                                             nullptr);
  if (stream == nullptr) {
    return bytes;
  }

  GdkPixbuf* source = gdk_pixbuf_new_from_stream(stream, nullptr, &error);
  g_object_unref(stream);
  if (source == nullptr) {
    if (error != nullptr) {
      g_error_free(error);
    }
    return bytes;
  }

  const int source_width = gdk_pixbuf_get_width(source);
  const int source_height = gdk_pixbuf_get_height(source);
  const int target_width = std::max(
      static_cast<int>(std::round(static_cast<double>(source_width) / viewport.device_pixel_ratio)),
      1);
  const int target_height = std::max(
      static_cast<int>(std::round(static_cast<double>(source_height) / viewport.device_pixel_ratio)),
      1);

  if (target_width == source_width && target_height == source_height) {
    g_object_unref(source);
    return bytes;
  }

  GdkPixbuf* scaled =
      gdk_pixbuf_scale_simple(source, target_width, target_height, GDK_INTERP_BILINEAR);
  g_object_unref(source);
  if (scaled == nullptr) {
    return bytes;
  }

  gchar* encoded = nullptr;
  gsize encoded_size = 0;
  if (!gdk_pixbuf_save_to_buffer(scaled, &encoded, &encoded_size, "png", &error, nullptr)) {
    g_object_unref(scaled);
    if (error != nullptr) {
      g_error_free(error);
    }
    return bytes;
  }
  g_object_unref(scaled);

  std::vector<std::uint8_t> output(encoded, encoded + encoded_size);
  g_free(encoded);
  if (error != nullptr) {
    g_error_free(error);
  }
  return output;
#endif
}

std::string AnnotationElementsScript() {
  return "(() => {" + ElementSelectorBuilderScript() +
         "return Array.from(document.querySelectorAll('a,button,input,select,textarea,[role=button]')).map((node) => {"
         "const rect = node.getBoundingClientRect();"
         "if (rect.width <= 0 || rect.height <= 0) return null;"
         "return {"
         "role: node.getAttribute('role') || (node.tagName || '').toLowerCase(),"
         "name: (node.innerText || node.textContent || node.value || node.placeholder || '').trim().substring(0, 50),"
         "selector: kelpieBuildSelector(node),"
         "rect: {x: rect.x, y: rect.y, width: rect.width, height: rect.height}"
         "};"
         "}).filter(Boolean).slice(0, 50).map((item, index) => { item.index = index; return item; }); })()";
}

std::string SelectorActivationScript(std::string_view selector) {
  return ActivationScript("document.querySelector(" + JsStringLiteral(std::string(selector)) + ")",
                          std::string(selector),
                          std::nullopt,
                          false);
}

std::string AnnotationActivationScript(int index) {
  return ActivationScript(
      "(() => (" + AnnotationElementsScript() +
          ").find(item => item.index === " + std::to_string(index) + "))()",
      std::nullopt,
      index,
      true);
}

std::string FillAnnotationScript(int index, std::string_view value) {
  return "(() => {" + ElementSelectorBuilderScript() + InteractionHelpersScript() + FormControlMutationScript() +
         "const annotationIndex = " + std::to_string(index) + ";"
         "const annotation = (" + AnnotationElementsScript() +
         ").find(item => item.index === annotationIndex);"
         "if (!annotation) return {error:'not_found', diagnostics: kelpieBaseDiagnostics(null, annotationIndex)};"
         "const matches = Array.from(document.querySelectorAll('a,button,input,select,textarea,[role=button]')).filter(node => {"
         "  const rect = node.getBoundingClientRect();"
         "  return rect.width > 0 && rect.height > 0;"
         "});"
         "const el = matches[annotation.index];"
         "if (!el) return {error:'not_found', diagnostics: kelpieNotFoundDiagnostics(annotation.selector || null, annotationIndex)};"
         "const tag = el.tagName ? el.tagName.toLowerCase() : '';"
         "const editable = ['input','textarea','select'].includes(tag) || !!el.isContentEditable;"
         "if (!editable || !!el.disabled || !!el.readOnly) {"
         "  return {error:'not_editable', diagnostics: kelpieEditableDiagnostics(el, annotation.selector || null, annotationIndex)};"
         "}"
         "el.focus();"
         "kelpieWriteFormControlValue(el," + JsStringLiteral(std::string(value)) + ");"
         "kelpieDispatchFormControlInput(el);"
         "kelpieDispatchFormControlChange(el);"
         "return {role:el.getAttribute('role')||(el.tagName||'').toLowerCase(),"
         "name:(el.placeholder||el.name||'').trim(),"
         "selector:kelpieBuildSelector(el)};"
         "})()";
}

}  // namespace kelpie::linuxapp
